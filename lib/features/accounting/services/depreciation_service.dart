import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Modelo simple para representar un activo fijo con su depreciación.
class FixedAsset {
  final String id;
  final String name;
  final String assetAccountCode; // ej: 1.2.01.01
  final String depreciationAccountCode; // ej: 1.2.02.01
  final String expenseAccountCode; // ej: 5.7.01
  final double originalCost;
  final double accumulatedDepreciation;
  final int usefulLifeMonths;
  final DateTime purchaseDate;

  FixedAsset({
    required this.id,
    required this.name,
    required this.assetAccountCode,
    required this.depreciationAccountCode,
    required this.expenseAccountCode,
    required this.originalCost,
    this.accumulatedDepreciation = 0,
    required this.usefulLifeMonths,
    required this.purchaseDate,
  });

  double get monthlyDepreciation => originalCost / usefulLifeMonths;
  double get netBookValue => originalCost - accumulatedDepreciation;
  bool get isFullyDepreciated => accumulatedDepreciation >= originalCost;

  int get monthsElapsed {
    final now = DateTime.now();
    int months = (now.year - purchaseDate.year) * 12 + (now.month - purchaseDate.month);
    return months.clamp(0, usefulLifeMonths);
  }

  factory FixedAsset.fromMap(Map<String, dynamic> map, String docId) {
    return FixedAsset(
      id: docId,
      name: map['name'] ?? '',
      assetAccountCode: map['assetAccountCode'] ?? '1.2.01.01',
      depreciationAccountCode: map['depreciationAccountCode'] ?? '1.2.02.01',
      expenseAccountCode: map['expenseAccountCode'] ?? '5.7.01',
      originalCost: (map['originalCost'] as num?)?.toDouble() ?? 0,
      accumulatedDepreciation: (map['accumulatedDepreciation'] as num?)?.toDouble() ?? 0,
      usefulLifeMonths: map['usefulLifeMonths'] ?? 60,
      purchaseDate: (map['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'assetAccountCode': assetAccountCode,
      'depreciationAccountCode': depreciationAccountCode,
      'expenseAccountCode': expenseAccountCode,
      'originalCost': originalCost,
      'accumulatedDepreciation': accumulatedDepreciation,
      'usefulLifeMonths': usefulLifeMonths,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
    };
  }
}

/// Servicio para gestionar la depreciación de activos fijos.
///
/// Permite registrar activos, calcular depreciación mensual automática
/// y generar asientos contables de depreciación.
class DepreciationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'fixed_assets';

  Future<String> saveAsset(FixedAsset asset) async {
    try {
      if (asset.id.isEmpty) {
        final docRef = _firestore.collection(_collection).doc();
        final newAsset = FixedAsset(
          id: docRef.id,
          name: asset.name,
          assetAccountCode: asset.assetAccountCode,
          depreciationAccountCode: asset.depreciationAccountCode,
          expenseAccountCode: asset.expenseAccountCode,
          originalCost: asset.originalCost,
          accumulatedDepreciation: asset.accumulatedDepreciation,
          usefulLifeMonths: asset.usefulLifeMonths,
          purchaseDate: asset.purchaseDate,
        );
        await docRef.set(newAsset.toMap());
        return docRef.id;
      } else {
        await _firestore.collection(_collection).doc(asset.id).set(asset.toMap());
        return asset.id;
      }
    } catch (e) {
      debugPrint('Error al guardar activo fijo: $e');
      rethrow;
    }
  }

  Stream<List<FixedAsset>> getAssetsStream() {
    return _firestore.collection(_collection).orderBy('name').snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => FixedAsset.fromMap(doc.data(), doc.id))
            .toList();
      },
    );
  }

  Future<List<FixedAsset>> getAssetsNeedingDepreciation() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map((doc) => FixedAsset.fromMap(doc.data(), doc.id))
        .where((a) => !a.isFullyDepreciated)
        .toList();
  }

  /// Calcula y registra la depreciación mensual para todos los activos que lo necesiten.
  /// Retorna el número de activos procesados.
  Future<int> postMonthlyDepreciation({DateTime? date}) async {
    final assets = await getAssetsNeedingDepreciation();
    int processed = 0;
    final depreciationDate = date ?? DateTime.now();

    for (final asset in assets) {
      final monthlyAmount = asset.monthlyDepreciation;
      if (monthlyAmount <= 0) continue;

      final remainingDepreciable = asset.originalCost - asset.accumulatedDepreciation;
      final depreciationThisMonth = monthlyAmount > remainingDepreciable
          ? remainingDepreciable
          : monthlyAmount;

      if (depreciationThisMonth <= 0) continue;

      try {
        // Asiento: DR Gasto Depreciación (5.7.xx) / CR Dep. Acumulada (1.2.02.xx)
        final lines = <Map<String, dynamic>>[
          {
            'accountCode': asset.expenseAccountCode,
            'debit': depreciationThisMonth,
            'credit': 0.0,
          },
          {
            'accountCode': asset.depreciationAccountCode,
            'debit': 0.0,
            'credit': depreciationThisMonth,
          },
        ];

        await JournalEntryService().createEntryFromEvent(
          referenceType: 'depreciacion',
          referenceId: '${asset.id}_${depreciationDate.year}_${depreciationDate.month}',
          date: depreciationDate,
          description: 'Depreciación mensual - ${asset.name}',
          lines: lines,
        );

        // Actualizar depreciación acumulada en el activo
        await _firestore.collection(_collection).doc(asset.id).update({
          'accumulatedDepreciation':
              FieldValue.increment(depreciationThisMonth),
        });

        processed++;
      } catch (e) {
        debugPrint('⚠️ Error al depreciar activo ${asset.name}: $e');
      }
    }

    debugPrint('✅ Depreciación mensual procesada: $processed activos');
    return processed;
  }

  Future<void> deleteAsset(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
