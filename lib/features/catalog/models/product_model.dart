import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String? label;
  final String categoryId;
  final DateTime? createdAt;
  final String? supplierId;
  final String? supplierLink;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.label,
    required this.categoryId,
    this.createdAt,
    this.supplierId,
    this.supplierLink,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    return ProductModel.fromFirestoreMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  factory ProductModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
    return ProductModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? data['image'],
      label: data['label'],
      categoryId: data['categoryId'] ?? '',
      supplierId: data['supplierId'],
      supplierLink: data['supplierLink'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is String
                ? DateTime.tryParse(data['createdAt'])
                : (data['createdAt'] is int
                      ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
                      : null)),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'label': label,
      'categoryId': categoryId,
      'supplierId': supplierId,
      'supplierLink': supplierLink,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? label,
    String? categoryId,
    DateTime? createdAt,
    String? supplierId,
    String? supplierLink,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      label: label ?? this.label,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      supplierId: supplierId ?? this.supplierId,
      supplierLink: supplierLink ?? this.supplierLink,
    );
  }
}
