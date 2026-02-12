import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:techsc/core/services/cache_service.dart';

/// Servicio centralizado para gestión de roles y permisos de usuarios
class RoleService {
  // Constantes de roles
  static const String ADMIN = 'administrador';
  static const String SELLER = 'vendedor';
  static const String TECHNICIAN = 'tecnico';
  static const String CLIENT = 'cliente';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CacheService? _cache;

  static final RoleService _instance = RoleService._internal();
  factory RoleService({CacheService? cache}) {
    if (cache != null && _instance._cache == null) {
      return RoleService._withCache(cache);
    }
    return _instance;
  }

  RoleService._internal() : _cache = null;
  RoleService._withCache(CacheService cache) : _cache = cache;

  Future<String> getUserRole(String uid) async {
    // 1. Try cache first
    if (_cache != null) {
      final cached = _cache.getCachedProfile(uid);
      if (cached != null && cached['role'] != null) {
        return cached['role'] as String;
      }
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['role'] != null) {
        String role = (doc.data()!['role'] as String).toLowerCase().trim();

        // Normalización para compatibilidad
        if (role == 'admin') {
          role = ADMIN;
        } else if (role == 'administrador')
          role = ADMIN;
        else if (role == 'seller')
          role = SELLER;
        else if (role == 'vendedor')
          role = SELLER;
        else if (role == 'technician')
          role = TECHNICIAN;
        else if (role == 'tecnico')
          role = TECHNICIAN;
        else if (role == 'client')
          role = CLIENT;
        else if (role == 'cliente')
          role = CLIENT;

        // 2. Save to cache
        if (_cache != null) {
          await _cache.cacheUserProfile(uid, {'role': role});
        }

        return role;
      }
      return CLIENT; // Default
    } on FirebaseException catch (e) {
      debugPrint('Error obteniendo rol (Firebase): [${e.code}] ${e.message}');
      return CLIENT;
    } catch (e) {
      debugPrint('Error obteniendo rol: $e');
      return CLIENT;
    }
  }

  /// Verifica si el usuario es administrador
  Future<bool> isAdmin(String uid) async {
    final role = await getUserRole(uid);
    return role == ADMIN;
  }

  /// Verifica si el usuario es técnico
  Future<bool> isTechnician(String uid) async {
    final role = await getUserRole(uid);
    return role == TECHNICIAN ||
        role ==
            ADMIN; // Admins also have technician access usually, or strictly TECHNICIAN
  }

  /// Verifica si el usuario puede gestionar productos (vendedor o admin)
  Future<bool> canManageProducts(String uid) async {
    final role = await getUserRole(uid);
    return role == SELLER || role == ADMIN;
  }

  /// Verifica si el usuario puede gestionar usuarios (solo admin)
  Future<bool> canManageUsers(String uid) async {
    return await isAdmin(uid);
  }

  /// Asigna un rol a un usuario (solo puede hacerlo un admin)
  /// Retorna true si la operación fue exitosa
  Future<bool> assignRole({
    required String targetUserId,
    required String newRole,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que el usuario actual sea admin
      final isCurrentUserAdmin = await isAdmin(currentUser.uid);
      if (!isCurrentUserAdmin) {
        throw Exception('Solo administradores pueden asignar roles');
      }

      // Validar el nuevo rol
      if (newRole != ADMIN &&
          newRole != SELLER &&
          newRole != TECHNICIAN &&
          newRole != CLIENT) {
        throw Exception('Rol inválido: $newRole');
      }

      // No permitir que un usuario se quite a sí mismo el rol de admin
      if (targetUserId == currentUser.uid && newRole != ADMIN) {
        // Verificar que haya al menos otro admin
        final adminCount = await _countAdmins();
        if (adminCount <= 1) {
          throw Exception(
            'No puedes quitarte el rol de administrador si eres el único admin',
          );
        }
      }

      // Actualizar el rol en Firestore
      await _firestore.collection('users').doc(targetUserId).update({
        'role': newRole,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': currentUser.uid,
      });

      return true;
    } catch (e) {
      debugPrint('Error asignando rol: $e');
      rethrow;
    }
  }

  /// Cuenta cuántos administradores hay en el sistema
  Future<int> _countAdmins() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: ADMIN)
          .get();
      return snapshot.docs.length;
    } on FirebaseException catch (e) {
      debugPrint('Error contando admins (Firebase): [${e.code}] ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('Error contando admins: $e');
      return 0;
    }
  }

  /// Obtiene el nombre legible del rol
  static String getRoleName(String role) {
    switch (role) {
      case ADMIN:
        return 'Administrador';
      case SELLER:
        return 'Vendedor';
      case TECHNICIAN:
        return 'Técnico';
      case CLIENT:
        return 'Cliente';
      default:
        return 'Cliente';
    }
  }

  /// Obtiene el icono para el rol
  static String getRoleIcon(String role) {
    switch (role) {
      case ADMIN:
        return '👑';
      case SELLER:
        return '💼';
      case TECHNICIAN:
        return '🔧';
      case CLIENT:
        return '👤';
      default:
        return '👤';
    }
  }

  /// Obtiene la descripción de permisos del rol
  static String getRoleDescription(String role) {
    switch (role) {
      case ADMIN:
        return 'Acceso completo: gestionar usuarios, productos, servicios y pedidos';
      case SELLER:
        return 'Gestionar productos, servicios y ver todos los pedidos';
      case TECHNICIAN:
        return 'Gestionar reservas, contactar clientes y registrar reparaciones';
      case CLIENT:
        return 'Comprar productos, reservar servicios y ver pedidos propios';
      default:
        return '';
    }
  }

  /// Obtiene estadísticas de usuarios por rol
  Future<Map<String, int>> getRoleStatistics() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final stats = {ADMIN: 0, SELLER: 0, CLIENT: 0};

      for (var doc in snapshot.docs) {
        final role = doc.data()['role'] ?? CLIENT;
        stats[role] = (stats[role] ?? 0) + 1;
      }

      return stats;
    } on FirebaseException catch (e) {
      debugPrint(
        'Error obteniendo estadísticas (Firebase): [${e.code}] ${e.message}',
      );
      return {ADMIN: 0, SELLER: 0, CLIENT: 0};
    } catch (e) {
      debugPrint('Error obteniendo estadísticas: $e');
      return {ADMIN: 0, SELLER: 0, CLIENT: 0};
    }
  }
}
