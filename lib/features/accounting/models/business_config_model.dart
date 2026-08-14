/// Configuración inicial del negocio registrada en el wizard (BLOQUE 10).
class BusinessConfigModel {
  final String razonSocial;
  final String ruc;
  final DateTime fechaInicioOperaciones;
  final bool configured;

  const BusinessConfigModel({
    required this.razonSocial,
    required this.ruc,
    required this.fechaInicioOperaciones,
    this.configured = true,
  });

  factory BusinessConfigModel.empty() {
    return BusinessConfigModel(
      razonSocial: '',
      ruc: '',
      fechaInicioOperaciones: DateTime(2024, 1, 1),
      configured: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'razonSocial': razonSocial,
      'ruc': ruc,
      'fechaInicioOperaciones': fechaInicioOperaciones.toIso8601String(),
      'configured': configured,
    };
  }

  factory BusinessConfigModel.fromMap(Map<String, dynamic> map) {
    return BusinessConfigModel(
      razonSocial: map['razonSocial'] ?? '',
      ruc: map['ruc'] ?? '',
      fechaInicioOperaciones: DateTime.tryParse(map['fechaInicioOperaciones'] ?? '') ?? DateTime(2024, 1, 1),
      configured: map['configured'] ?? false,
    );
  }
}
