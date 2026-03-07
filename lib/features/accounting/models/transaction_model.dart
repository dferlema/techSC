import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum para definir el tipo de transacción contable en el sistema.
enum TransactionType { ingreso, egreso }

/// Modelo que representa una transacción contable dentro del sistema.
///
/// Este modelo está diseñado para cumplir con los requerimientos básicos de control
/// financiero en Ecuador, permitiendo el registro de IVA y categorías.
class TransactionModel {
  final String id;
  final TransactionType
  type; // Tipo: ingreso (ventas) o egreso (gastos/compras)
  final String
  category; // Categoría: Ejemplo: 'Venta', 'Servicio', 'Sueldos', 'Arriendo'
  final double amount; // Monto subtotal sin impuestos
  final double vatAmount; // Monto del IVA calculado
  final double vatRate; // Tasa de IVA aplicada (Ejemplo: 0.15 para el 15%)
  final double total; // Monto total (Subtotal + IVA)
  final DateTime date; // Fecha de la transacción
  final String description; // Detalle o concepto de la transacción
  final String? clientIdentification; // Cédula o RUC del cliente/proveedor
  final String?
  referenceId; // ID de referencia (ejemplo: ID de orden o ID de factura)

  TransactionModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.vatAmount,
    this.vatRate = 0.15,
    required this.total,
    required this.date,
    required this.description,
    this.clientIdentification,
    this.referenceId,
  });

  /// Convierte el objeto a un mapa para ser almacenado en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'category': category,
      'amount': amount,
      'vatAmount': vatAmount,
      'vatRate': vatRate,
      'total': total,
      'date': Timestamp.fromDate(date),
      'description': description,
      'clientIdentification': clientIdentification,
      'referenceId': referenceId,
    };
  }

  /// Crea una instancia de TransactionModel a partir de un mapa de Firestore.
  factory TransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionModel(
      id: docId,
      type: TransactionType.values.byName(map['type'] ?? 'ingreso'),
      category: map['category'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (map['vatAmount'] as num?)?.toDouble() ?? 0.0,
      vatRate: (map['vatRate'] as num?)?.toDouble() ?? 0.15,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
      clientIdentification: map['clientIdentification'],
      referenceId: map['referenceId'],
    );
  }

  /// Calcula automáticamente el total incluyendo IVA basado en un subtotal y tasa.
  factory TransactionModel.createWithTax({
    required String id,
    required TransactionType type,
    required String category,
    required double subtotal,
    required double vatRate,
    required DateTime date,
    required String description,
    String? clientIdentification,
    String? referenceId,
  }) {
    final vat = subtotal * vatRate;
    return TransactionModel(
      id: id,
      type: type,
      category: category,
      amount: subtotal,
      vatAmount: vat,
      vatRate: vatRate,
      total: subtotal + vat,
      date: date,
      description: description,
      clientIdentification: clientIdentification,
      referenceId: referenceId,
    );
  }
}
