import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/orders/models/quote_model.dart';

class OrderModel {
  final String id;
  final String quoteId;
  final QuoteModel originalQuote;

  final String status; // 'pending', 'in_progress', 'completed', 'cancelled'
  final String paymentStatus; // 'unpaid', 'partial', 'paid', 'refunded'

  final DateTime createdAt;
  final DateTime? completedAt;

  final String technicianId; // Assigned technician

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

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    return OrderModel.fromFirestoreMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }
}
