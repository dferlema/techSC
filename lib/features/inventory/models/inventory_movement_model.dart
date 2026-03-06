import 'package:cloud_firestore/cloud_firestore.dart';

enum MovementType { inward, outward, adjust }

extension MovementTypeExtension on MovementType {
  String get value {
    switch (this) {
      case MovementType.inward:
        return 'IN';
      case MovementType.outward:
        return 'OUT';
      case MovementType.adjust:
        return 'ADJUST';
    }
  }

  static MovementType fromString(String value) {
    switch (value) {
      case 'IN':
        return MovementType.inward;
      case 'OUT':
        return MovementType.outward;
      case 'ADJUST':
      default:
        return MovementType.adjust;
    }
  }
}

class InventoryMovementModel {
  final String id;
  final String productId;
  final MovementType type;
  final int quantity;
  final DateTime date;
  final String reason;
  final String userId;
  final int previousStock;
  final int newStock;

  InventoryMovementModel({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
    required this.reason,
    required this.userId,
    required this.previousStock,
    required this.newStock,
  });

  factory InventoryMovementModel.fromFirestore(DocumentSnapshot doc) {
    return InventoryMovementModel.fromFirestoreMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  factory InventoryMovementModel.fromFirestoreMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return InventoryMovementModel(
      id: id,
      productId: data['productId'] ?? '',
      type: MovementTypeExtension.fromString(data['type'] ?? 'ADJUST'),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : (data['date'] is String
                ? DateTime.tryParse(data['date'] as String) ?? DateTime.now()
                : DateTime.now()),
      reason: data['reason'] ?? '',
      userId: data['userId'] ?? '',
      previousStock: (data['previousStock'] as num?)?.toInt() ?? 0,
      newStock: (data['newStock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'type': type.value,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
      'reason': reason,
      'userId': userId,
      'previousStock': previousStock,
      'newStock': newStock,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'type': type.value,
      'quantity': quantity,
      'date': date.toIso8601String(),
      'reason': reason,
      'userId': userId,
      'previousStock': previousStock,
      'newStock': newStock,
    };
  }
}
