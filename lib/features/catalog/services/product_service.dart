import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/cache_service.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService? _cache;
  static const String _collection = 'products';

  ProductService({CacheService? cache}) : _cache = cache;

  Stream<List<Map<String, dynamic>>> getProducts(String categoryId) async* {
    final cacheKey = 'products_$categoryId';

    // 1. Emit cached data
    if (_cache != null) {
      final cached = _cache.getCachedCatalog(cacheKey);
      if (cached != null) {
        yield cached;
      }
    }

    // 2. Listen to Firestore
    yield* _db
        .collection(_collection)
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();

          // Update cache
          if (_cache != null) {
            _cache.cacheCatalog(cacheKey, products);
          }

          return products;
        });
  }
}
