import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/features/orders/models/quote_model.dart';

/// Representa una orden de servicio generada al aprobar una cotización.
///
/// La orden guarda una "fotografía" de la cotización original (`originalQuote`)
/// de modo que los datos quedan congelados en el momento de la aprobación,
/// aunque luego la cotización se modifique.
class OrderModel {
  /// ID del documento de la orden en Firestore (p. ej. `ord-20260813-001`).
  final String id;

  /// ID de la cotización que dio origen a esta orden.
  final String quoteId;

  /// Copia de la cotización aprobada (con sus items, totales e historial).
  final QuoteModel originalQuote;

  /// Estado del flujo de servicio: 'pending', 'in_progress', 'completed', 'cancelled'.
  final String status;

  /// Estado del pago: 'unpaid', 'partial', 'paid', 'refunded'.
  final String paymentStatus;

  /// Fecha en que se creó la orden (al aprobar la cotización).
  final DateTime createdAt;

  /// Fecha de finalización del servicio, si ya se completó.
  final DateTime? completedAt;

  /// UID del técnico asignado a la orden (vacío si aún no se asigna).
  final String technicianId;

  OrderModel({
    required this.id,
    required this.quoteId,
    required this.originalQuote,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.completedAt,
    this.technicianId = '',
  });

  /// Convierte la orden a un mapa plano para guardarlo en Firestore.
  ///
  /// Además de los campos propios, desnormaliza `total`, `items` y
  /// `discountPercentage` de la cotización para facilitar consultas
  /// y reportes sin tener que leer el objeto anidado.
  Map<String, dynamic> toMap() {
    return {
      'quoteId': quoteId,
      'originalQuote': originalQuote.toMap(),
      'status': status,
      'paymentStatus': paymentStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'technicianId': technicianId,
      'total': originalQuote.total,
      'items': originalQuote.items.map((x) => x.toMap()).toList(),
      'discountPercentage': originalQuote.discountPercentage,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  /// Construye una orden a partir de un mapa (los datos ya están en disco).
  factory OrderModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
    return OrderModel(
      id: id,
      quoteId: data['quoteId'] ?? '',
      originalQuote: QuoteModel.fromMap(
        data['originalQuote'] as Map<String, dynamic>,
        data['quoteId'] ?? '',
      ),
      status: data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is String
                ? DateTime.parse(data['createdAt'])
                : DateTime.now()),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] is Timestamp
                ? (data['completedAt'] as Timestamp).toDate()
                : (data['completedAt'] is String
                      ? DateTime.tryParse(data['completedAt'])
                      : null))
          : null,
      technicianId: data['technicianId'] ?? '',
    );
  }

  /// Construye una orden a partir de un documento Firestore.
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    return OrderModel.fromFirestoreMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }
}