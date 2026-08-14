import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/features/accounting/models/business_config_model.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Servicio de configuración inicial del negocio y asientos de apertura.
class BusinessConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'business_config';
  static const String _docId = 'config';

  Future<void> saveConfig(BusinessConfigModel config) async {
    await _firestore.collection(_collection).doc(_docId).set(config.toMap());
  }

  Future<BusinessConfigModel> getConfig() async {
    final doc = await _firestore.collection(_collection).doc(_docId).get();
    if (!doc.exists) return BusinessConfigModel.empty();
    return BusinessConfigModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  /// ¿La configuración inicial ya fue completada?
  Future<bool> isConfigured() async {
    final config = await getConfig();
    return config.configured;
  }

  /// Asiento de apertura (BLOQUE 10.4):
  ///   DR Caja (1.1.01.01) + Bancos (1.1.01.03) + Inventario (1.1.03.xx)
  ///   CR Capital Social (3.1.01)
  /// Se divide el capital entre caja y bancos; el excedente de capital respecto
  /// a caja+bancos+inventario se registra como aportes pendientes (3.1.02).
  Future<String?> generateOpeningEntry({
    required double capitalInicial,
    required double saldoCaja,
    required double saldoBancos,
    double inventarioInicial = 0.0,
    String inventoryAccountCode = '1.1.03.02',
    DateTime? date,
  }) async {
    final refId = 'opening_$capitalInicial';
    final existing = await JournalEntryService().getEntryByReference('opening_entry', refId);
    if (existing != null) return null;

    final lines = <Map<String, dynamic>>[];
    if (saldoCaja > 0) lines.add({'accountCode': '1.1.01.01', 'debit': saldoCaja, 'credit': 0.0});
    if (saldoBancos > 0) lines.add({'accountCode': '1.1.01.03', 'debit': saldoBancos, 'credit': 0.0});
    if (inventarioInicial > 0) lines.add({'accountCode': inventoryAccountCode, 'debit': inventarioInicial, 'credit': 0.0});

    final totalActivos = saldoCaja + saldoBancos + inventarioInicial;
    final excedenteCapital = capitalInicial - totalActivos;
    if (excedenteCapital < 0) {
      // No se puede acreditar menos capital que los activos iniciales.
      throw Exception('El capital inicial ($capitalInicial) debe ser mayor o igual a los activos iniciales ($totalActivos)');
    }

    lines.add({'accountCode': '3.1.01', 'debit': 0.0, 'credit': totalActivos});
    if (excedenteCapital > 0) {
      lines.add({'accountCode': '3.1.02', 'debit': 0.0, 'credit': excedenteCapital});
    }

    return JournalEntryService().createEntryFromEvent(
      referenceType: 'opening_entry',
      referenceId: refId,
      date: date ?? DateTime.now(),
      description: 'Asiento de apertura - saldos iniciales',
      lines: lines,
    );
  }

  /// Registra el empleado inicial (BLOQUE 10.3) en la colección de empleados.
  Future<void> saveInitialEmployee({
    required String cedula,
    required String nombre,
    required double sueldo,
    required DateTime fechaIngreso,
  }) async {
    final docRef = _firestore.collection('business_employees').doc();
    await docRef.set({
      'cedula': cedula,
      'nombre': nombre,
      'sueldo': sueldo,
      'fechaIngreso': Timestamp.fromDate(fechaIngreso),
      'active': true,
    });
    debugPrint('✅ Empleado inicial guardado: $nombre');
  }
}
