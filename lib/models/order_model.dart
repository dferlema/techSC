import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/models/quote_model.dart';

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
      // Add total and items at top level for easier access and consistency
      'total': originalQuote.total,
      'items': originalQuote.items.map((x) => x.toMap()).toList(),
      'discountPercentage': originalQuote.discountPercentage,
    };
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      quoteId: data['quoteId'] ?? '',
      originalQuote: QuoteModel.fromMap(
        data['originalQuote'] as Map<String, dynamic>,
        data['quoteId'] ?? '',
      ),
      status: data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      technicianId: data['technicianId'] ?? '',
    );
  }
}
