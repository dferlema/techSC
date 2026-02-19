import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/cache_service.dart';
import 'package:techsc/features/auth/models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService? _cache;
  static const String _collection = 'users';

  UserService({CacheService? cache}) : _cache = cache;

  Future<UserModel?> getUser(String uid) async {
    // 1. Try cache
    if (_cache != null) {
      final cached = _cache.getCachedProfile(uid);
      if (cached != null) {
        return UserModel.fromMap(cached, uid);
      }
    }

    // 2. Try Firestore
    final doc = await _db.collection(_collection).doc(uid).get();
    if (doc.exists) {
      final user = UserModel.fromFirestore(doc);
      if (_cache != null) {
        await _cache.cacheUserProfile(uid, user.toFirestore());
      }
      return user;
    }
    return null;
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection(_collection).doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        if (_cache != null) {
          _cache.cacheUserProfile(uid, user.toFirestore());
        }
        return user;
      }
      return null;
    });
  }

  Future<void> updateUser(UserModel user) async {
    await _db.collection(_collection).doc(user.uid).update(user.toFirestore());
    if (_cache != null) {
      await _cache.cacheUserProfile(user.uid, user.toFirestore());
    }
  }

  Stream<List<UserModel>> watchAllUsers() {
    return _db.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }
}
