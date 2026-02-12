import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/cache_service.dart';

class ServiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService? _cache;
  static const String _collection = 'services';

  ServiceService({CacheService? cache}) : _cache = cache;

  Stream<List<Map<String, dynamic>>> getServices(String? categoryId) async* {
    final cacheKey = 'services_${categoryId ?? "all"}';

    // 1. Emit cached data
    if (_cache != null) {
      final cached = _cache.getCachedCatalog(cacheKey);
      if (cached != null) {
        yield cached;
      }
    }

    // 2. Query Firestore
    Query query = _db.collection(_collection);
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    yield* query.snapshots().map((snapshot) {
      final services = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();

      // Update cache
      if (_cache != null) {
        _cache.cacheCatalog(cacheKey, services);
      }

      return services;
    });
  }
}
