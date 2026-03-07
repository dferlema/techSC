import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que actúa como puente para la Facturación Electrónica del SRI.
///
/// Contiene la estructura necesaria para generar el XML (RIDE) requerido por Ecuador.
class ElectronicInvoiceModel {
  final String id;
  final String transactionId; // Vínculo con el movimiento contable
  final String accessKey; // Clave de acceso de 49 dígitos exigida por SRI
  final String invoiceNumber; // Formato 001-001-000000001
  final DateTime emissionDate;
  final String clientRuc;
  final String clientName;
  final String clientEmail;
  final double subtotal0; // Base imponible IVA 0%
  final double subtotalTax; // Base imponible IVA 15% (u otro)
  final double taxAmount; // Valor del IVA
  final double total;
  final String status; // PENDIENTE, AUTORIZADO, RECHAZADO

  ElectronicInvoiceModel({
    required this.id,
    required this.transactionId,
    this.accessKey = '',
    required this.invoiceNumber,
    required this.emissionDate,
    required this.clientRuc,
    required this.clientName,
    required this.clientEmail,
    required this.subtotal0,
    required this.subtotalTax,
    required this.taxAmount,
    required this.total,
    this.status = 'PENDIENTE',
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'accessKey': accessKey,
      'invoiceNumber': invoiceNumber,
      'emissionDate': Timestamp.fromDate(emissionDate),
      'clientRuc': clientRuc,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'subtotal0': subtotal0,
      'subtotalTax': subtotalTax,
      'taxAmount': taxAmount,
      'total': total,
      'status': status,
    };
  }

  factory ElectronicInvoiceModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    return ElectronicInvoiceModel(
      id: docId,
      transactionId: map['transactionId'] ?? '',
      accessKey: map['accessKey'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      emissionDate:
          (map['emissionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientRuc: map['clientRuc'] ?? '',
      clientName: map['clientName'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      subtotal0: (map['subtotal0'] as num?)?.toDouble() ?? 0.0,
      subtotalTax: (map['subtotalTax'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'PENDIENTE',
    );
  }

  /// Genera un borrador de clave de acceso (Formato simplificado para el puente).
  static String generateMockAccessKey(
    String ruc,
    String invoiceNum,
    DateTime date,
  ) {
    // La clave real se genera con fecha, tipo comprobante, RUC, ambiente, serie, seq, codigo, emision.
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString();
    String cleanInvoice = invoiceNum.replaceAll('-', '');

    return "$day$month$year"
        "01"
        "$ruc"
        "1"
        "$cleanInvoice"
        "12345678"
        "1";
  }
}
