import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/features/auth/models/user_model.dart';
import 'package:tscomputer/core/services/config_service.dart';
import 'package:tscomputer/core/models/config_model.dart';
import 'package:tscomputer/features/admin/models/profit_range_model.dart';
import 'package:tscomputer/features/admin/models/bank_account_model.dart';

// Categorías
final adminCategoriesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .handleError(
        (error) => debugPrint('Stream error [adminCategories]: $error'),
      )
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
});

// Productos con búsqueda
final adminProductsQueryProvider = StateProvider<String>((ref) => '');

const _adminPageSize = 30;

final adminProductsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final query = ref.watch(adminProductsQueryProvider);

  var queryRef = FirebaseFirestore.instance
      .collection('products')
      .orderBy('name');

  if (query.isNotEmpty) {
    queryRef = queryRef
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\u{f8ff}');
  }

  return queryRef
      .snapshots()
      .handleError(
        (error) => debugPrint('Stream error [adminProducts]: $error'),
      )
      .map((s) => s.docs);
});

// Servicios con búsqueda y paginación
final adminServicesQueryProvider = StateProvider<String>((ref) => '');

final adminServicesProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final query = ref.watch(adminServicesQueryProvider);

  var queryRef = FirebaseFirestore.instance
      .collection('services')
      .orderBy('title')
      .limit(_adminPageSize);

  if (query.isNotEmpty) {
    queryRef = queryRef
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\u{f8ff}');
  }

  return queryRef
      .snapshots()
      .handleError(
        (error) => debugPrint('Stream error [adminServices]: $error'),
      )
      .map((s) => s.docs);
});

// Clientes (users con rol client) con paginación
final adminClientsQueryProvider = StateProvider<String>((ref) => '');
final adminClientsDateRangeProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);

final adminClientsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final query = ref.watch(adminClientsQueryProvider);
  final dateRange = ref.watch(adminClientsDateRangeProvider);

  var queryRef = FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'cliente')
      .orderBy('name')
      .limit(_adminPageSize);

  if (query.isNotEmpty) {
    queryRef = queryRef
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\u{f8ff}');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> source;
  if (dateRange != null) {
    source = queryRef
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(
            dateRange.end.add(const Duration(days: 1)),
          ),
        )
        .snapshots();
  } else {
    source = queryRef.snapshots();
  }

  return source
      .handleError((error) => debugPrint('Stream error [adminClients]: $error'))
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => {'docId': doc.id, ...doc.data()})
            .toList(),
      );
});

// Pedidos con paginación
final adminOrdersQueryProvider = StateProvider<String>((ref) => '');

final adminOrdersProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  ref.watch(adminOrdersQueryProvider);

  var queryRef = FirebaseFirestore.instance
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(_adminPageSize);

  return queryRef
      .snapshots()
      .handleError((error) => debugPrint('Stream error [adminOrders]: $error'))
      .map((s) => s.docs);
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
      .handleError(
        (error) => debugPrint('Stream error [marketingClients]: $error'),
      )
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
      );
});

final availableProductsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .handleError(
        (error) => debugPrint('Stream error [availableProducts]: $error'),
      )
      .map((s) => s.docs);
});

// Proveedores de Configuración y Banners
final appConfigProvider = StreamProvider<ConfigModel>((ref) {
  return ConfigService().getConfigStream().handleError(
    (error) => debugPrint('Stream error [appConfig]: $error'),
  );
});

final bannersProvider = StreamProvider<QuerySnapshot>((ref) {
  return ConfigService().getBannersStream().handleError(
    (error) => debugPrint('Stream error [banners]: $error'),
  );
});

final profitRangesProvider = StreamProvider<List<ProfitRange>>((ref) {
  return ConfigService().getProfitRangesStream().handleError(
    (error) => debugPrint('Stream error [profitRanges]: $error'),
  );
});

final bankAccountsProvider = StreamProvider<List<BankAccount>>((ref) {
  return ConfigService().getBankAccountsStream().handleError(
    (error) => debugPrint('Stream error [bankAccounts]: $error'),
  );
});
