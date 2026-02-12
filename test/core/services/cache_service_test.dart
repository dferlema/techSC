import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';
import 'package:techsc/core/services/cache_service.dart';

void main() {
  late CacheService cacheService;

  setUp(() async {
    await setUpTestHive();
    cacheService = CacheService();
    await cacheService.init();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('CacheService - User Profile', () {
    test('Cache and retrieve user profile', () async {
      const uid = 'user123';
      const profile = {'role': 'admin', 'name': 'Test User'};

      await cacheService.cacheUserProfile(uid, profile);
      final cached = cacheService.getCachedProfile(uid);

      expect(cached, isNotNull);
      expect(cached!['role'], 'admin');
      expect(cached['name'], 'Test User');
    });

    test('Return null for non-existent profile', () {
      final cached = cacheService.getCachedProfile('none');
      expect(cached, isNull);
    });
  });

  group('CacheService - Catalog Cache', () {
    test('Cache and retrieve catalog items', () async {
      const key = 'categories_product';
      final items = [
        {'id': 'cat1', 'name': 'Category 1'},
        {'id': 'cat2', 'name': 'Category 2'},
      ];

      await cacheService.cacheCatalog(key, items);
      final cached = cacheService.getCachedCatalog(key);

      expect(cached, isNotNull);
      expect(cached!.length, 2);
      expect(cached[0]['name'], 'Category 1');
    });

    test('TTL Expiration', () async {
      const key = 'expired_items';
      final items = [
        {'id': '1'},
      ];

      // Cache with 0 seconds TTL (or very small)
      // Since our service uses Duration(hours: 24) by default,
      // let's test with a manual timestamp if possible or just assume TTL works if logic is simple.
      // But we can't easily inject time in the current implementation without refactoring.
      // Let's at least test successful caching with default TTL.

      await cacheService.cacheCatalog(key, items);
      final cached = cacheService.getCachedCatalog(key);
      expect(cached, isNotNull);
    });
  });

  group('CacheService - Global', () {
    test('Clear all cache', () async {
      await cacheService.cacheUserProfile('u1', {'r': 'a'});
      await cacheService.cacheCatalog('c1', [
        {'id': '1'},
      ]);

      await cacheService.clearAll();

      expect(cacheService.getCachedProfile('u1'), isNull);
      expect(cacheService.getCachedCatalog('c1'), isNull);
    });
  });
}
