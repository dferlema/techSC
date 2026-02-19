import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/auth/models/user_model.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/models/config_model.dart';

// Categorías
final adminCategoriesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
});

// Productos con búsqueda
final adminProductsQueryProvider = StateProvider<String>((ref) => '');

final adminProductsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final query = ref.watch(adminProductsQueryProvider).toLowerCase();
  return FirebaseFirestore.instance.collection('products').snapshots().map((
    snapshot,
  ) {
    if (query.isEmpty) return snapshot.docs;
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return data.values.any(
        (val) => val.toString().toLowerCase().contains(query),
      );
    }).toList();
  });
});

// Servicios con búsqueda
final adminServicesQueryProvider = StateProvider<String>((ref) => '');

final adminServicesProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final query = ref.watch(adminServicesQueryProvider).toLowerCase();
  return FirebaseFirestore.instance.collection('services').snapshots().map((
    snapshot,
  ) {
    if (query.isEmpty) return snapshot.docs;
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return data.values.any(
        (val) => val.toString().toLowerCase().contains(query),
      );
    }).toList();
  });
});

// Clientes (users con rol client)
final adminClientsQueryProvider = StateProvider<String>((ref) => '');
final adminClientsDateRangeProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);

final adminClientsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final query = ref.watch(adminClientsQueryProvider).toLowerCase();
  final dateRange = ref.watch(adminClientsDateRangeProvider);

  return FirebaseFirestore.instance.collection('users').snapshots().map((
    snapshot,
  ) {
    var clients = snapshot.docs
        .map((doc) => {'docId': doc.id, ...doc.data()})
        .toList();

    // Filtrar por búsqueda
    if (query.isNotEmpty) {
      clients = clients.where((client) {
        return (client['id'] as String?)?.toLowerCase().contains(query) ==
                true ||
            (client['name'] as String?)?.toLowerCase().contains(query) ==
                true ||
            (client['email'] as String?)?.toLowerCase().contains(query) ==
                true ||
            (client['phone'] as String?)?.toLowerCase().contains(query) == true;
      }).toList();
    }

    // Filtrar por fecha
    if (dateRange != null) {
      clients = clients.where((client) {
        final createdAt = (client['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) return true;
        return createdAt.isAfter(dateRange.start) &&
            createdAt.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    return clients;
  });
});

// Pedidos
final adminOrdersQueryProvider = StateProvider<String>((ref) => '');

final adminOrdersProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final query = ref.watch(adminOrdersQueryProvider).toLowerCase();
  return FirebaseFirestore.instance
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        if (query.isEmpty) return snapshot.docs;
        return snapshot.docs.toList();
      });
});

// Proveedor de rol del usuario actual simplificado
final currentUserRoleProvider = FutureProvider<String>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return 'cliente';

  return await ref.watch(userRoleProvider(user.uid).future);
});

// Proveedores específicos para Marketing
final marketingClientsProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: RoleService.CLIENT)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
      );
});

final availableProductsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((s) => s.docs);
});

// Proveedores de Configuración y Banners
final appConfigProvider = StreamProvider<ConfigModel>((ref) {
  return ConfigService().getConfigStream();
});

final bannersProvider = StreamProvider<QuerySnapshot>((ref) {
  return ConfigService().getBannersStream();
});
