import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de un rol de pago.
enum PayrollStatus { generado, pagado, anulado }

/// Modelo de Rol de Pago mensual por empleado (régimen Ecuador).
///
/// Calcula aportes IESS (9.45% personal / 11.15% patronal), provisiones de
/// décimo tercero (1/12 sueldo) y décimo cuarto (SBU/12), y fondos de reserva.
class PayrollModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeIdentification;
  final String period; // 'YYYY-MM'
  final double baseSalary;
  final double overtime;
  final double bonuses;
  final double anticipo;
  final double aportePersonal; // 9.45% sobre ingreso gravable
  final double aportePatronal; // 11.15% sobre ingreso gravable
  final double decimoTercero; // 1/12 de sueldo
  final double decimoCuarto; // SBU/12
  final double fondosReserva; // 1/12 de sueldo (si aplica)
  final double totalIngresos;
  final double totalDescuentos;
  final double netoPagar;
  final PayrollStatus status;
  final DateTime date;
  final DateTime? paidAt;

  PayrollModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeIdentification,
    required this.period,
    required this.baseSalary,
    this.overtime = 0.0,
    this.bonuses = 0.0,
    this.anticipo = 0.0,
    this.aportePersonal = 0.0,
    this.aportePatronal = 0.0,
    this.decimoTercero = 0.0,
    this.decimoCuarto = 0.0,
    this.fondosReserva = 0.0,
    this.totalIngresos = 0.0,
    this.totalDescuentos = 0.0,
    this.netoPagar = 0.0,
    this.status = PayrollStatus.generado,
    required this.date,
    this.paidAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeIdentification': employeeIdentification,
      'period': period,
      'baseSalary': baseSalary,
      'overtime': overtime,
      'bonuses': bonuses,
      'anticipo': anticipo,
      'aportePersonal': aportePersonal,
      'aportePatronal': aportePatronal,
      'decimoTercero': decimoTercero,
      'decimoCuarto': decimoCuarto,
      'fondosReserva': fondosReserva,
      'totalIngresos': totalIngresos,
      'totalDescuentos': totalDescuentos,
      'netoPagar': netoPagar,
      'status': status.name,
      'date': Timestamp.fromDate(date),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    };
  }

  factory PayrollModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayrollModel(
      id: docId,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      employeeIdentification: map['employeeIdentification'] ?? '',
      period: map['period'] ?? '',
      baseSalary: (map['baseSalary'] as num?)?.toDouble() ?? 0.0,
      overtime: (map['overtime'] as num?)?.toDouble() ?? 0.0,
      bonuses: (map['bonuses'] as num?)?.toDouble() ?? 0.0,
      anticipo: (map['anticipo'] as num?)?.toDouble() ?? 0.0,
      aportePersonal: (map['aportePersonal'] as num?)?.toDouble() ?? 0.0,
      aportePatronal: (map['aportePatronal'] as num?)?.toDouble() ?? 0.0,
      decimoTercero: (map['decimoTercero'] as num?)?.toDouble() ?? 0.0,
      decimoCuarto: (map['decimoCuarto'] as num?)?.toDouble() ?? 0.0,
      fondosReserva: (map['fondosReserva'] as num?)?.toDouble() ?? 0.0,
      totalIngresos: (map['totalIngresos'] as num?)?.toDouble() ?? 0.0,
      totalDescuentos: (map['totalDescuentos'] as num?)?.toDouble() ?? 0.0,
      netoPagar: (map['netoPagar'] as num?)?.toDouble() ?? 0.0,
      status: PayrollStatus.values.byName(map['status'] ?? 'generado'),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Construye el rol aplicando el cálculo completo del Ecuador.
  /// - SBU (Salario Básico Unificado): valor mensual para décimo cuarto.
  factory PayrollModel.build({
    required String id,
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
    DateTime? date,
  }) {
    const double iessPersonalRate = 0.0945;
    const double iessPatronalRate = 0.1115;

    final ingresoGravable = baseSalary + overtime + bonuses;
    final aportePersonal = ingresoGravable * iessPersonalRate;
    final aportePatronal = ingresoGravable * iessPatronalRate;
    final decimoTercero = ingresoGravable / 12;
    final decimoCuarto = sbu / 12;
    final fondosReserva = applyFondosReserva ? ingresoGravable / 12 : 0.0;

    final totalIngresos = ingresoGravable + decimoTercero + decimoCuarto + fondosReserva;
    final totalDescuentos = aportePersonal + anticipo;
    final netoPagar = ingresoGravable - aportePersonal - anticipo;

    return PayrollModel(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      employeeIdentification: employeeIdentification,
      period: period,
      baseSalary: baseSalary,
      overtime: overtime,
      bonuses: bonuses,
      anticipo: anticipo,
      aportePersonal: aportePersonal,
      aportePatronal: aportePatronal,
      decimoTercero: decimoTercero,
      decimoCuarto: decimoCuarto,
      fondosReserva: fondosReserva,
      totalIngresos: totalIngresos,
      totalDescuentos: totalDescuentos,
      netoPagar: netoPagar,
      date: date ?? DateTime.now(),
    );
  }
}
