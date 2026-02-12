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
    return CategoryModel.fromFirestoreMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  factory CategoryModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] == 'product'
          ? CategoryType.product
          : CategoryType.service,
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
      'type': type == CategoryType.product ? 'product' : 'service',
      'createdAt':
          createdAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
  }
}
