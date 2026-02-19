import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/cart/services/cart_service.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/services/cache_service.dart';
import 'package:techsc/features/catalog/services/category_service.dart';
import 'package:techsc/features/catalog/services/product_service.dart';
import 'package:techsc/features/reservations/services/service_service.dart';
import 'package:techsc/features/auth/services/user_service.dart';
import 'package:techsc/features/auth/models/user_model.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider for RoleService singleton
final roleServiceProvider = Provider<RoleService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return RoleService(cache: cache);
});

/// Provider for CartService singleton (ChangeNotifier)
final cartServiceProvider = ChangeNotifierProvider<CartService>(
  (ref) => CartService(),
);

/// Provider for ConfigService
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());

/// Provider for CacheService
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

/// Provider for CategoryService
final categoryServiceProvider = Provider<CategoryService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return CategoryService(cache: cache);
});

/// Provider for ProductService
final productServiceProvider = Provider<ProductService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return ProductService(cache: cache);
});

/// Provider for ServiceService
final serviceServiceProvider = Provider<ServiceService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return ServiceService(cache: cache);
});

/// Provider for UserService
final userServiceProvider = Provider<UserService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return UserService(cache: cache);
});

/// FutureProvider to get the current user's role
final userRoleProvider = FutureProvider.family<String, String>((
  ref,
  uid,
) async {
  final roleService = ref.watch(roleServiceProvider);
  return await roleService.getUserRole(uid);
});

/// Provider to watch current user data
final userDataProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userServiceProvider).watchUser(uid);
});

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provider for current Firebase User
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provider to watch all users
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(userServiceProvider).watchAllUsers();
});
