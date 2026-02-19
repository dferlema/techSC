import 'package:cloud_firestore/cloud_firestore.dart';

class QuoteItem {
  final String id;
  final String name;
  final String type; // 'product' or 'service'
  final double price;
  final int quantity;
  final String description;
  final String? imageUrl;

  QuoteItem({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.quantity,
    this.description = '',
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'price': price,
      'quantity': quantity,
      'description': description,
      'imageUrl': imageUrl,
      'subtotal': total,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'product',
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? map['image'],
    );
  }

  double get total => price * quantity;
}

class QuoteHistoryEvent {
  final DateTime date;
  final String userId;
  final String action; // 'created', 'updated', 'approved', 'rejected'
  final String description;

  QuoteHistoryEvent({
    required this.date,
    required this.userId,
    required this.action,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'userId': userId,
      'action': action,
      'description': description,
    };
  }

  factory QuoteHistoryEvent.fromMap(Map<String, dynamic> map) {
    return QuoteHistoryEvent(
      date: (map['date'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
      action: map['action'] ?? '',
      description: map['description'] ?? '',
    );
  }
}

class QuoteModel {
  final String id;
  final String clientId; // RUC/Cédula
  final String? customerUid; // Firebase UID
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String creatorId; // User ID of who created it (Seller/Tech/Admin)

  final List<QuoteItem> items;
  final List<QuoteHistoryEvent> history;

  final DateTime createdAt;
  final DateTime? expirationDate;

  final String status; // 'draft', 'sent', 'approved', 'rejected', 'converted'
  final bool applyTax;
  final double taxRate; // 0.15 for 15%
  final double discountPercentage; // e.g. 5.0 for 5%

  QuoteModel({
    required this.id,
    required this.clientId,
    this.customerUid,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.creatorId,
    required this.items,
    required this.history,
    required this.createdAt,
    this.expirationDate,
    this.status = 'draft',
    this.applyTax = true,
    this.taxRate = 0.15,
    this.discountPercentage = 0.0,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discountAmount => subtotal * (discountPercentage / 100);
  double get taxableAmount => subtotal - discountAmount;
  double get taxAmount => applyTax ? taxableAmount * taxRate : 0;
  double get total => taxableAmount + taxAmount;

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'customerUid': customerUid,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'creatorId': creatorId,
      'items': items.map((x) => x.toMap()).toList(),
      'history': history.map((x) => x.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expirationDate': expirationDate != null
          ? Timestamp.fromDate(expirationDate!)
          : null,
      'status': status,
      'applyTax': applyTax,
      'taxRate': taxRate,
      'discountPercentage': discountPercentage,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'total': total,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  factory QuoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuoteModel.fromMap(data, doc.id);
  }

  factory QuoteModel.fromMap(Map<String, dynamic> data, String id) {
    return QuoteModel(
      id: id,
      clientId: data['clientId'] ?? '',
      customerUid: data['customerUid'],
      clientName: data['clientName'] ?? '',
      clientEmail: data['clientEmail'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      creatorId: data['creatorId'] ?? '',
      items: List<QuoteItem>.from(
        (data['items'] ?? []).map((x) => QuoteItem.fromMap(x)),
      ),
      history: List<QuoteHistoryEvent>.from(
        (data['history'] ?? []).map((x) => QuoteHistoryEvent.fromMap(x)),
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expirationDate: data['expirationDate'] != null
          ? (data['expirationDate'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'draft',
      applyTax: data['applyTax'] ?? true,
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0.15,
      discountPercentage:
          (data['discountPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  QuoteModel copyWith({
    String? id, // Added id
    String? clientId,
    String? customerUid,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? creatorId,
    List<QuoteItem>? items,
    List<QuoteHistoryEvent>? history,
    DateTime? createdAt,
    DateTime? expirationDate,
    String? status,
    bool? applyTax,
    double? taxRate,
    double? discountPercentage,
  }) {
    return QuoteModel(
      id: id ?? this.id, // Use new id or existing
      clientId: clientId ?? this.clientId,
      customerUid: customerUid ?? this.customerUid,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      creatorId: creatorId ?? this.creatorId,
      items: items ?? this.items,
      history: history ?? this.history,
      createdAt: createdAt ?? this.createdAt,
      expirationDate: expirationDate ?? this.expirationDate,
      status: status ?? this.status,
      applyTax: applyTax ?? this.applyTax,
      taxRate: taxRate ?? this.taxRate,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }
}
