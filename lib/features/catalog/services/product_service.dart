import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/cache_service.dart';
import 'package:techsc/features/catalog/models/product_model.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService? _cache;
  static const String _collection = 'products';

  ProductService({CacheService? cache}) : _cache = cache;

  Stream<List<ProductModel>> getProducts(String categoryId) async* {
    final cacheKey = 'products_$categoryId';

    // 1. Emit cached data
    if (_cache != null) {
      final cached = _cache.getCachedCatalog(cacheKey);
      if (cached != null) {
        yield cached
            .map((p) => ProductModel.fromFirestoreMap(p, p['id'] ?? ''))
            .toList();
      }
    }

    // 2. Listen to Firestore
    yield* _db
        .collection(_collection)
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
          final List<Map<String, dynamic>> productsMap = snapshot.docs.map((
            doc,
          ) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();

          // Update cache
          if (_cache != null) {
            final sanitized = productsMap.map((p) {
              return p.map((key, value) {
                if (value is Timestamp) {
                  return MapEntry(key, value.millisecondsSinceEpoch);
                }
                return MapEntry(key, value);
              });
            }).toList();
            _cache.cacheCatalog(cacheKey, sanitized);
          }

          return productsMap
              .map((p) => ProductModel.fromFirestoreMap(p, p['id']))
              .toList();
        });
  }
}
