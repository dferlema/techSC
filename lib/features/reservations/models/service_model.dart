import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String categoryId;
  final DateTime? createdAt;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.categoryId,
    this.createdAt,
  });

  factory ServiceModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
    final fetchedName = data['name'] ?? data['title'] ?? '';
    return ServiceModel(
      id: id,
      name: fetchedName.toString().isNotEmpty
          ? fetchedName.toString()
          : (data['description'] != null && data['description'].toString().isNotEmpty
              ? data['description'].toString()
              : 'Servicio'),
      description: data['description'] ?? '',
      price: (data['price'] is num)
          ? (data['price'] as num).toDouble()
          : (double.tryParse(data['price']?.toString() ?? '') ?? 0.0),
      imageUrl: data['imageUrl'] ?? data['image'],
      categoryId: data['categoryId'] ?? '',
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
      'title': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  ServiceModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? categoryId,
    DateTime? createdAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
