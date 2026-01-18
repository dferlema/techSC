import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoryType { product, service }

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.createdAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] == 'product'
          ? CategoryType.product
          : CategoryType.service,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type == CategoryType.product ? 'product' : 'service',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
