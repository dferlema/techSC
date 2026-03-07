import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa el cierre de caja diario.
///
/// Permite consolidar los ingresos y egresos de un día específico,
/// registrando el efectivo físico vs el sistema para encontrar diferencias.
class DailyClosureModel {
  final String id;
  final DateTime date; // Fecha del cierre
  final double totalIngresos; // Suma total de ingresos en el sistema
  final double totalEgresos; // Suma total de egresos en el sistema
  final double balanceSistema; // totalIngresos - totalEgresos
  final double efectivoFisico; // Cantidad de dinero contado físicamente
  final double diferencia; // efectivoFisico - balanceSistema
  final String notes; // Observaciones del cierre
  final String closedBy; // ID del usuario que realizó el cierre

  DailyClosureModel({
    required this.id,
    required this.date,
    required this.totalIngresos,
    required this.totalEgresos,
    required this.balanceSistema,
    required this.efectivoFisico,
    required this.diferencia,
    required this.notes,
    required this.closedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'totalIngresos': totalIngresos,
      'totalEgresos': totalEgresos,
      'balanceSistema': balanceSistema,
      'efectivoFisico': efectivoFisico,
      'diferencia': diferencia,
      'notes': notes,
      'closedBy': closedBy,
    };
  }

  factory DailyClosureModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyClosureModel(
      id: docId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalIngresos: (map['totalIngresos'] as num?)?.toDouble() ?? 0.0,
      totalEgresos: (map['totalEgresos'] as num?)?.toDouble() ?? 0.0,
      balanceSistema: (map['balanceSistema'] as num?)?.toDouble() ?? 0.0,
      efectivoFisico: (map['efectivoFisico'] as num?)?.toDouble() ?? 0.0,
      diferencia: (map['diferencia'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      closedBy: map['closedBy'] ?? '',
    );
  }
}
