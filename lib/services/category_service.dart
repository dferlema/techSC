import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

/// Service to manage product and service categories in Firestore.
class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'categories';

  /// Returns a stream of categories filtered by [type].
  Stream<List<CategoryModel>> getCategories(CategoryType type) {
    final typeString = type == CategoryType.product ? 'product' : 'service';
    return _db
        .collection(_collection)
        .where('type', isEqualTo: typeString)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList(),
        );
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
