import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/models/config_model.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';

/// StreamProvider for application configuration
final configStreamProvider = StreamProvider<ConfigModel>((ref) {
  final configService = ref.watch(configServiceProvider);
  return configService.getConfigStream().handleError(
    (error) => debugPrint('Stream error [config]: $error'),
  );
});

/// StreamProvider for banners
final bannersProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  return FirebaseFirestore.instance
      .collection('banners')
      .snapshots()
      .handleError(
        (error) => debugPrint('Stream error [banners]: $error'),
      )
      .map((s) => s.docs);
});

/// StreamProvider for featured products
final featuredProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('isFeatured', isEqualTo: true)
      .limit(5)
      .snapshots()
      .handleError(
        (error) => debugPrint('Stream error [featuredProducts]: $error'),
      )
      .map(
        (s) => s.docs
            .map((d) => ProductModel.fromFirestoreMap(d.data(), d.id))
            .toList(),
      );
});
