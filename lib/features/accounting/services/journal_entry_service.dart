import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';

class JournalEntryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'accounting_entries';
  static const String _coaCollection = 'chart_of_accounts';

  /// Calcula el cambio de saldo para una línea del asiento según la naturaleza
  /// de la cuenta.
  ///
  /// Convención contable:
  ///   - Cuentas DEUDORA (activos, gastos, costos): débito AUMENTA, crédito DISMINUYE
  ///   - Cuentas ACREEDORA (pasivos, patrimonio, ingresos): crédito AUMENTA, débito DISMINUYE
  static double _balanceChange(AccountingEntryLine line) {
    // Si no tiene naturaleza guardada, intentar inferir del código
    final nature = line.accountNature ?? _inferNature(line.accountCode);
    final isDeudora = nature == 'deudora';
    if (isDeudora) {
      return line.debit - line.credit;
    } else {
      return line.credit - line.debit;
    }
  }

  /// Inferir naturaleza de la cuenta a partir del código.
  /// Activos (1.x) y gastos (5.x) y costos (6.x) = deudora
  /// Pasivos (2.x), patrimonio (3.x) e ingresos (4.x) = acreedora
  static String _inferNature(String accountCode) {
    if (accountCode.isEmpty) return 'deudora';
    final firstDigit = int.tryParse(accountCode.substring(0, 1)) ?? 0;
    if (firstDigit == 1 || firstDigit >= 5) return 'deudora';
    return 'acreedora';
  }

  Future<String> saveEntry(AccountingEntryModel entry) async {
    try {
      if (entry.id.isEmpty) {
        final number = await DocumentIdService().generateId(prefix: 'AS', useDate: true, digits: 4);
        final docRef = _firestore.collection(_collection).doc();
        final updated = AccountingEntryModel(
          id: docRef.id,
          number: number,
          date: entry.date,
          description: entry.description,
          lines: entry.lines,
          status: entry.status,
          createdBy: entry.createdBy,
          referenceType: entry.referenceType,
          referenceId: entry.referenceId,
          createdAt: DateTime.now(),
          postedAt: entry.status == EntryStatus.contabilizado ? DateTime.now() : null,
        );
        await docRef.set(updated.toMap());
        return docRef.id;
      } else {
        await _firestore.collection(_collection).doc(entry.id).set(entry.toMap(), SetOptions(merge: true));
        return entry.id;
      }
    } catch (e) {
      debugPrint('Error al guardar asiento: $e');
      rethrow;
    }
  }

  /// Actualiza los saldos del plan de cuentas para las líneas de un asiento.
  ///
  /// Usa WriteBatch para atomicidad: todas las actualizaciones se aplican
  /// o ninguna se aplica.
  Future<void> _applyBalanceChanges(
    List<AccountingEntryLine> lines, {
    bool reverse = false,
  }) async {
    final batch = _firestore.batch();

    for (final line in lines) {
      final change = _balanceChange(line);
      if (change == 0) continue;

      final effectiveChange = reverse ? -change : change;

      final accountRef = _firestore.collection(_coaCollection).doc(line.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(effectiveChange),
      });
    }

    await batch.commit();
  }

  Future<void> postEntry(String entryId) async {
    final doc = await _firestore.collection(_collection).doc(entryId).get();
    if (!doc.exists) throw Exception('Asiento no encontrado');
    final entry = AccountingEntryModel.fromMap(doc.data()!, doc.id);
    if (!entry.isBalanced) throw Exception('El asiento no está balanceado');

    // Si ya está contabilizado, no duplicar saldos
    if (entry.status == EntryStatus.contabilizado) return;

    // Actualizar saldos (batch atómico)
    await _applyBalanceChanges(entry.lines);

    await _firestore.collection(_collection).doc(entryId).update({
      'status': EntryStatus.contabilizado.name,
      'postedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteEntry(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> cancelEntry(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return;
    final entry = AccountingEntryModel.fromMap(doc.data()!, doc.id);
    if (entry.status != EntryStatus.contabilizado) {
      await _firestore.collection(_collection).doc(id).update({
        'status': EntryStatus.cancelado.name,
      });
      return;
    }

    // Revertir saldos (batch atómico, reverse = true)
    await _applyBalanceChanges(entry.lines, reverse: true);

    await _firestore.collection(_collection).doc(id).update({
      'status': EntryStatus.cancelado.name,
    });
  }

  Stream<List<AccountingEntryModel>> getEntriesStream({DateTime? start, DateTime? end}) {
    Query query = _firestore.collection(_collection).orderBy('date', descending: true);
    if (start != null && end != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(start.year, start.month, start.day)))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(end.year, end.month, end.day, 23, 59, 59)));
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.where((doc) => doc.exists).map((doc) => AccountingEntryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  Future<List<AccountingEntryModel>> getEntriesByAccount(String accountId) async {
    final snapshot = await _firestore.collection(_collection).get();
    final result = <AccountingEntryModel>[];
    for (final doc in snapshot.docs) {
      final entry = AccountingEntryModel.fromMap(doc.data(), doc.id);
      for (final line in entry.lines) {
        if (line.accountId == accountId) {
          result.add(entry);
          break;
        }
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Retorna el asiento creado por un evento (referenceType + referenceId),
  /// o null si no existe. Útil para verificar idempotencia.
  Future<AccountingEntryModel?> getEntryByReference(String referenceType, String referenceId) async {
    final entryId = 'auto_${referenceType}_$referenceId';
    final doc = await _firestore.collection(_collection).doc(entryId).get();
    if (!doc.exists) return null;
    return AccountingEntryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Elimina un asiento automático de evento, revirtiendo primero sus efectos
  /// sobre los saldos del plan de cuentas.
  Future<void> removeEntryFromEvent(String referenceType, String referenceId) async {
    final entryId = 'auto_${referenceType}_$referenceId';
    final doc = await _firestore.collection(_collection).doc(entryId).get();
    if (!doc.exists) return;
    final entry = AccountingEntryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    if (entry.status == EntryStatus.contabilizado) {
      await _applyBalanceChanges(entry.lines, reverse: true);
    }
    await _firestore.collection(_collection).doc(entryId).delete();
  }

  /// Crea asientos contables automáticos a partir de eventos del sistema.
  /// Busca cuentas por código en el plan de cuentas existente.
  /// Usa WriteBatch para atomicidad en la actualización de saldos.
  Future<String?> createEntryFromEvent({
    required String referenceType,
    required String referenceId,
    required DateTime date,
    required String description,
    required List<Map<String, dynamic>> lines,
    String? createdBy,
  }) async {
    try {
      final entryId = 'auto_${referenceType}_$referenceId';
      final existing = await _firestore.collection(_collection).doc(entryId).get();
      if (existing.exists) {
        debugPrint('⏭️ Asiento $entryId ya existe, omitiendo');
        return null;
      }

      final coa = await _firestore.collection(_coaCollection).get();
      final accountMap = <String, ChartOfAccountModel>{};
      for (final doc in coa.docs) {
        final acc = ChartOfAccountModel.fromMap(doc.data(), doc.id);
        accountMap[acc.code] = acc;
      }

      final entryLines = <AccountingEntryLine>[];
      for (final l in lines) {
        final accCode = l['accountCode'] as String;
        final acc = accountMap[accCode];
        if (acc == null) {
          debugPrint('⚠️ Cuenta $accCode no encontrada en plan de cuentas');
          continue;
        }
        entryLines.add(AccountingEntryLine(
          accountId: acc.id,
          accountCode: acc.code,
          accountName: acc.name,
          debit: (l['debit'] as num?)?.toDouble() ?? 0.0,
          credit: (l['credit'] as num?)?.toDouble() ?? 0.0,
          accountNature: acc.nature.name,
        ));
      }

      if (entryLines.isEmpty) return null;

      final number = await DocumentIdService().generateId(prefix: 'AS', useDate: true, digits: 4);
      final entry = AccountingEntryModel(
        id: entryId,
        number: number,
        date: date,
        description: description,
        lines: entryLines,
        status: EntryStatus.contabilizado,
        createdBy: createdBy,
        referenceType: referenceType,
        referenceId: referenceId,
        createdAt: DateTime.now(),
        postedAt: DateTime.now(),
      );

      if (!entry.isBalanced) {
        debugPrint('⚠️ Asiento $entryId no está balanceado: débito ${entry.totalDebit} vs crédito ${entry.totalCredit}');
        return null;
      }

      // Guardar asiento Y actualizar saldos en batch atómico
      final batch = _firestore.batch();
      final entryRef = _firestore.collection(_collection).doc(entryId);
      batch.set(entryRef, entry.toMap());

      for (final line in entryLines) {
        final change = _balanceChange(line);
        if (change == 0) continue;
        final accountRef = _firestore.collection(_coaCollection).doc(line.accountId);
        batch.update(accountRef, {
          'balance': FieldValue.increment(change),
        });
      }

      await batch.commit();

      debugPrint('✅ Asiento automático $entryId creado: $description');
      return entryId;
    } catch (e) {
      debugPrint('⚠️ Error al crear asiento automático: $e');
      return null;
    }
  }
}
