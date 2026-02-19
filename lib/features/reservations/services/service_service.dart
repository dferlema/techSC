import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/cache_service.dart';
import 'package:techsc/features/reservations/models/service_model.dart';

class ServiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService? _cache;
  static const String _collection = 'services';

  ServiceService({CacheService? cache}) : _cache = cache;

  Stream<List<ServiceModel>> getServices(String? categoryId) async* {
    final cacheKey = 'services_${categoryId ?? "all"}';

    // 1. Emit cached data
    if (_cache != null) {
      final cached = _cache.getCachedCatalog(cacheKey);
      if (cached != null) {
        yield cached
            .map((s) => ServiceModel.fromFirestoreMap(s, s['id'] ?? ''))
            .toList();
      }
    }

    // 2. Query Firestore
    Query query = _db.collection(_collection);
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    yield* query.snapshots().map((snapshot) {
      final List<Map<String, dynamic>> servicesMap = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();

      // Update cache
      if (_cache != null) {
        final sanitized = servicesMap.map((s) {
          return s.map((key, value) {
            if (value is Timestamp) {
              return MapEntry(key, value.millisecondsSinceEpoch);
            }
            return MapEntry(key, value);
          });
        }).toList();
        _cache.cacheCatalog(cacheKey, sanitized);
      }

      return servicesMap
          .map((s) => ServiceModel.fromFirestoreMap(s, s['id']))
          .toList();
    });
  }

  Future<void> deleteService(String serviceId) async {
    await _db.collection(_collection).doc(serviceId).delete();
  }
}
