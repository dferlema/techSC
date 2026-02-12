import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/core/services/cache_service.dart';
import 'dart:async';

/// Service to manage product and service categories in Firestore.
class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService? _cache;
  static const String _collection = 'categories';

  CategoryService({CacheService? cache}) : _cache = cache;

  /// Returns a stream of categories filtered by [type].
  /// Emits cached data first if available.
  Stream<List<CategoryModel>> getCategories(CategoryType type) async* {
    final typeString = type == CategoryType.product ? 'product' : 'service';
    final cacheKey = 'categories_$typeString';

    // 1. Emit cached data if available
    if (_cache != null) {
      final cached = _cache.getCachedCatalog(cacheKey);
      if (cached != null) {
        yield cached
            .map((e) => CategoryModel.fromFirestoreMap(e, e['id'] ?? ''))
            .toList();
      }
    }

    // 2. Listen to Firestore
    yield* _db
        .collection(_collection)
        .where('type', isEqualTo: typeString)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs;
          final categories = items
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList();

          // Update cache
          if (_cache != null) {
            _cache.cacheCatalog(
              cacheKey,
              categories.map((e) => e.toFirestore()..['id'] = e.id).toList(),
            );
          }

          return categories;
        });
  }

  // Create new category
  Future<void> addCategory(String name, CategoryType type) async {
    final category = CategoryModel(id: '', name: name, type: type);
    await _db.collection(_collection).add(category.toFirestore());
  }

  // Update category
  Future<void> updateCategory(String id, String name) async {
    await _db.collection(_collection).doc(id).update({'name': name});
  }

  // Delete category
  Future<void> deleteCategory(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}
