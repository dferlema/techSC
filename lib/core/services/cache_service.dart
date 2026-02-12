import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String profileBoxName = 'user_profile';
  static const String catalogBoxName = 'catalog_cache';

  // Singleton for internal use if needed, but we'll use Riverpod for access
  CacheService();

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(profileBoxName);
    await Hive.openBox(catalogBoxName);
  }

  // --- Profile Cache ---

  Future<void> cacheUserProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    final box = Hive.box(profileBoxName);
    await box.put(userId, {
      'data': profile,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Map<String, dynamic>? getCachedProfile(
    String userId, {
    Duration maxAge = const Duration(days: 7),
  }) {
    final box = Hive.box(profileBoxName);
    final cached = box.get(userId);

    if (cached == null) return null;

    final int timestamp = cached['timestamp'];
    final DateTime cachedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (DateTime.now().difference(cachedDate) > maxAge) {
      box.delete(userId);
      return null;
    }

    return Map<String, dynamic>.from(cached['data']);
  }

  // --- Catalog Cache (Products/Services) ---

  Future<void> cacheCatalog(
    String type,
    List<Map<String, dynamic>> items,
  ) async {
    final box = Hive.box(catalogBoxName);
    await box.put(type, {
      'data': items,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  List<Map<String, dynamic>>? getCachedCatalog(
    String type, {
    Duration maxAge = const Duration(hours: 24),
  }) {
    final box = Hive.box(catalogBoxName);
    final cached = box.get(type);

    if (cached == null) return null;

    final int timestamp = cached['timestamp'];
    final DateTime cachedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (DateTime.now().difference(cachedDate) > maxAge) {
      box.delete(type);
      return null;
    }

    final List<dynamic> data = cached['data'];
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // --- General Methods ---

  Future<void> clearAll() async {
    await Hive.box(profileBoxName).clear();
    await Hive.box(catalogBoxName).clear();
  }
}
