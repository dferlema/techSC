import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/models/config_model.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/catalog/models/product_model.dart';

/// StreamProvider for application configuration
final configStreamProvider = StreamProvider<ConfigModel>((ref) {
  final configService = ref.watch(configServiceProvider);
  return configService.getConfigStream();
});

/// StreamProvider for banners
final bannersProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  return FirebaseFirestore.instance
      .collection('banners')
      .snapshots()
      .map((s) => s.docs);
});

/// StreamProvider for featured products
final featuredProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('isFeatured', isEqualTo: true)
      .limit(5)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => ProductModel.fromFirestoreMap(d.data(), d.id))
            .toList(),
      );
});
