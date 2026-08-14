import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/accounting/models/payroll_model.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Servicio de nómina (rol de pagos) con integración contable automática.
///
/// Al generar un rol crea un asiento:
///   DR Sueldos (5.1.01) + Aporte Patronal (5.1.07) + Décimos (5.1.04/5.1.05) + Fondos (5.1.06)
///   CR Sueldos por Pagar (2.1.04.01) + Aporte Personal IESS (2.1.04.05) +
///      Aporte Patronal IESS (2.1.04.06) + Décimos por Pagar (2.1.04.02/03) + Fondos por Pagar (2.1.04.04)
class PayrollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'payroll_entries';

  Future<String> savePayroll(PayrollModel payroll) async {
    try {
      if (payroll.id.isEmpty) {
        final docRef = _firestore.collection(_collection).doc();
        await docRef.set(payroll.toMap());
        return docRef.id;
      } else {
        await _firestore.collection(_collection).doc(payroll.id).set(payroll.toMap(), SetOptions(merge: true));
        return payroll.id;
      }
    } catch (e) {
      debugPrint('Error al guardar rol de pago: $e');
      rethrow;
    }
  }

  Future<String> generatePayroll({
    required String employeeId,
    required String employeeName,
    required String employeeIdentification,
    required String period,
    required double baseSalary,
    double overtime = 0.0,
    double bonuses = 0.0,
    double anticipo = 0.0,
    bool applyFondosReserva = false,
    double sbu = 470.0,
  }) async {
    final id = await DocumentIdService().generateId(prefix: 'rol', useDate: true);
    final payroll = PayrollModel.build(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      employeeIdentification: employeeIdentification,
      period: period,
      baseSalary: baseSalary,
      overtime: overtime,
      bonuses: bonuses,
      anticipo: anticipo,
      applyFondosReserva: applyFondosReserva,
      sbu: sbu,
    );

    // Verificar que no exista ya un rol para el mismo empleado y período
    final existing = await _firestore.collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .where('period', isEqualTo: period)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Ya existe un rol de pago para $employeeName en $period');
    }

    await savePayroll(payroll);

    // Asiento contable de provisión del rol
    await JournalEntryService().createEntryFromEvent(
      referenceType: 'payroll',
      referenceId: id,
      date: payroll.date,
      description: 'Rol de pagos $period - $employeeName',
      lines: [
        {'accountCode': '5.1.01', 'debit': payroll.baseSalary + payroll.overtime + payroll.bonuses, 'credit': 0.0},
        {'accountCode': '5.1.07', 'debit': payroll.aportePatronal, 'credit': 0.0},
        {'accountCode': '5.1.04', 'debit': payroll.decimoTercero, 'credit': 0.0},
        {'accountCode': '5.1.05', 'debit': payroll.decimoCuarto, 'credit': 0.0},
        if (payroll.fondosReserva > 0)
          {'accountCode': '5.1.06', 'debit': payroll.fondosReserva, 'credit': 0.0},
        // Provisión de vacaciones 1/24 (BLOQUE 7.6)
        {'accountCode': '5.1.08', 'debit': payroll.baseSalary / 24, 'credit': 0.0},
        {'accountCode': '2.1.04.01', 'debit': 0.0, 'credit': payroll.netoPagar},
        {'accountCode': '2.1.04.05', 'debit': 0.0, 'credit': payroll.aportePersonal},
        {'accountCode': '2.1.04.06', 'debit': 0.0, 'credit': payroll.aportePatronal},
        {'accountCode': '2.1.04.02', 'debit': 0.0, 'credit': payroll.decimoTercero},
        {'accountCode': '2.1.04.03', 'debit': 0.0, 'credit': payroll.decimoCuarto},
        if (payroll.fondosReserva > 0)
          {'accountCode': '2.1.04.04', 'debit': 0.0, 'credit': payroll.fondosReserva},
        {'accountCode': '2.1.04.07', 'debit': 0.0, 'credit': payroll.baseSalary / 24},
      ],
    );

    return id;
  }

  /// Marca un rol como pagado y crea el asiento de pago:
  ///   DR Sueldos por Pagar (2.1.04.01) / CR Caja o Bancos (1.1.01.01)
  Future<void> markPaid(String payrollId, {String method = 'transferencia'}) async {
    final docRef = _firestore.collection(_collection).doc(payrollId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Rol de pago no encontrado');

    final payroll = PayrollModel.fromMap(doc.data() as Map<String, dynamic>, payrollId);
    if (payroll.status == PayrollStatus.pagado) return;

    await docRef.update({
      'status': PayrollStatus.pagado.name,
      'paidAt': Timestamp.fromDate(DateTime.now()),
    });

    String cashAccount;
    switch (method) {
      case 'efectivo':
        cashAccount = '1.1.01.01';
        break;
      default:
        cashAccount = '1.1.01.03';
    }

    await JournalEntryService().createEntryFromEvent(
      referenceType: 'payroll_payment',
      referenceId: '${payrollId}_paid',
      date: DateTime.now(),
      description: 'Pago rol $payrollId - ${payroll.employeeName}',
      lines: [
        {'accountCode': '2.1.04.01', 'debit': payroll.netoPagar, 'credit': 0.0},
        {'accountCode': cashAccount, 'debit': 0.0, 'credit': payroll.netoPagar},
      ],
    );
  }

  /// Pago mensual de aportes IESS (BLOQUE 7.3):
  ///   DR Aporte Personal IESS por Pagar (2.1.04.05)
  ///   DR Aporte Patronal IESS por Pagar (2.1.04.06)
  ///   CR Caja o Bancos
  /// Suma los aportes acumulados en los roles del período y crea un único asiento.
  Future<void> payIess(String period, {String method = 'transferencia'}) async {
    final referenceId = 'iess_${period}_payment';
    final existing = await JournalEntryService().getEntryByReference('iess_payment', referenceId);
    if (existing != null) return;

    final payrolls = await getPayrolls(period: period);
    double personal = 0, patronal = 0;
    for (final p in payrolls) {
      personal += p.aportePersonal;
      patronal += p.aportePatronal;
    }
    final total = personal + patronal;
    if (total <= 0) throw Exception('No hay aportes IESS pendientes en el período $period');

    String cashAccount;
    switch (method) {
      case 'efectivo':
        cashAccount = '1.1.01.01';
        break;
      default:
        cashAccount = '1.1.01.03';
    }

    await JournalEntryService().createEntryFromEvent(
      referenceType: 'iess_payment',
      referenceId: referenceId,
      date: DateTime.now(),
      description: 'Pago IESS mensual - período $period',
      lines: [
        {'accountCode': '2.1.04.05', 'debit': personal, 'credit': 0.0},
        {'accountCode': '2.1.04.06', 'debit': patronal, 'credit': 0.0},
        {'accountCode': cashAccount, 'debit': 0.0, 'credit': total},
      ],
    );
  }

  Stream<List<PayrollModel>> getPayrollsStream({String? period}) {
    Query query = _firestore.collection(_collection).orderBy('date', descending: true);
    if (period != null && period.isNotEmpty) {
      query = query.where('period', isEqualTo: period);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => PayrollModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<List<PayrollModel>> getPayrolls({String? period}) async {
    Query query = _firestore.collection(_collection).orderBy('date', descending: true);
    if (period != null && period.isNotEmpty) {
      query = query.where('period', isEqualTo: period);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => PayrollModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<void> deletePayroll(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Totales de un período: sueldos, aportes, provisiones y neto a pagar.
  Future<Map<String, double>> getPeriodTotals(String period) async {
    final payrolls = await getPayrolls(period: period);
    double sueldos = 0, aportePatronal = 0, provisiones = 0, neto = 0;
    for (final p in payrolls) {
      sueldos += p.baseSalary + p.overtime + p.bonuses;
      aportePatronal += p.aportePatronal;
      provisiones += p.decimoTercero + p.decimoCuarto + p.fondosReserva;
      neto += p.netoPagar;
    }
    return {
      'sueldos': sueldos,
      'aportePatronal': aportePatronal,
      'provisiones': provisiones,
      'neto': neto,
    };
  }
}
