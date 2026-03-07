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
  final int stock;
  final List<String>? images;
  final double? purchaseCost;
  final double? purchaseCostWithTax;
  final double? profitMargin;
  final double? fixedProfit;
  final bool useFixedProfit;
  final double? cardPrice;

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
    this.stock = 0,
    this.images,
    this.purchaseCost,
    this.purchaseCostWithTax,
    this.profitMargin,
    this.fixedProfit,
    this.useFixedProfit = false,
    this.cardPrice,
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
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      images: data['images'] != null ? List<String>.from(data['images']) : null,
      purchaseCost: (data['purchaseCost'] as num?)?.toDouble(),
      purchaseCostWithTax: (data['purchaseCostWithTax'] as num?)?.toDouble(),
      profitMargin: (data['profitMargin'] as num?)?.toDouble(),
      fixedProfit: (data['fixedProfit'] as num?)?.toDouble(),
      useFixedProfit: data['useFixedProfit'] ?? false,
      cardPrice: (data['cardPrice'] as num?)?.toDouble(),
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
      'stock': stock,
      'images': images,
      'purchaseCost': purchaseCost,
      'purchaseCostWithTax': purchaseCostWithTax,
      'profitMargin': profitMargin,
      'fixedProfit': fixedProfit,
      'useFixedProfit': useFixedProfit,
      'cardPrice': cardPrice,
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
    int? stock,
    List<String>? images,
    double? purchaseCost,
    double? purchaseCostWithTax,
    double? profitMargin,
    double? fixedProfit,
    bool? useFixedProfit,
    double? cardPrice,
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
      stock: stock ?? this.stock,
      images: images ?? this.images,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      purchaseCostWithTax: purchaseCostWithTax ?? this.purchaseCostWithTax,
      profitMargin: profitMargin ?? this.profitMargin,
      fixedProfit: fixedProfit ?? this.fixedProfit,
      useFixedProfit: useFixedProfit ?? this.useFixedProfit,
      cardPrice: cardPrice ?? this.cardPrice,
    );
  }
}
