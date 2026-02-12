import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/features/catalog/screens/product_form_page.dart';
import 'package:techsc/features/reservations/screens/service_form_page.dart';
import 'package:techsc/features/catalog/screens/supplier_management_page.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/admin/widgets/admin_orders_tab.dart';
import 'package:techsc/features/admin/widgets/admin_clients_tab.dart';
import 'package:techsc/features/admin/widgets/admin_product_card.dart';
import 'package:techsc/features/admin/widgets/admin_service_card.dart';

/// Página principal del panel de administración.
/// Reestructurada para usar widgets modulares y Riverpod.
class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController = TextEditingController();

    // Limpiar búsqueda al cambiar de pestaña
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Por favor, inicie sesión.')),
      );
    }

    final roleAsync = ref.watch(userRoleProvider(user.uid));

    return roleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Error al cargar rol: $err'))),
      data: (userRole) {
        final bool canAccessPanel =
            userRole == RoleService.ADMIN || userRole == RoleService.SELLER;
        final bool isAdmin = userRole == RoleService.ADMIN;

        if (!canAccessPanel) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Acceso Denegado'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).canPop()
                    ? Navigator.of(context).pop()
                    : Navigator.of(context).pushReplacementNamed('/main'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Solo personal autorizado puede acceder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/main');
                }
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Panel de Administración',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestiona clientes, productos, servicios y banners',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.category, color: Colors.white),
                tooltip: 'Gestionar Categorías',
                onPressed: () =>
                    Navigator.pushNamed(context, '/category-management'),
              ),
              const CartBadge(),
              const SizedBox(width: 8),
            ],
          ),
          body: _buildBody(isAdmin),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabController.index,
            onDestinationSelected: (int index) {
              setState(() {
                _tabController.animateTo(index);
              });
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Clientes',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Productos',
              ),
              NavigationDestination(
                icon: Icon(Icons.build_outlined),
                selectedIcon: Icon(Icons.build),
                label: 'Servicios',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Pedidos',
              ),
              NavigationDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business),
                label: 'Proveedores',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(bool isAdmin) {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. Clientes
        isAdmin
            ? const AdminClientsTab()
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Solo administradores pueden gestionar clientes'),
                  ],
                ),
              ),
        // 2. Productos
        _buildTabContent(
          collection: 'products',
          builder: (doc) => AdminProductCard(doc: doc),
          addButtonLabel: 'Agregar Producto',
        ),
        // 3. Servicios
        _buildTabContent(
          collection: 'services',
          builder: (doc) => AdminServiceCard(doc: doc),
          addButtonLabel: 'Agregar Servicio',
        ),
        // 4. Pedidos
        const AdminOrdersTab(),
        // 5. Proveedores
        isAdmin
            ? const SupplierManagementPage()
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Solo administradores pueden gestionar proveedores'),
                  ],
                ),
              ),
      ],
    );
  }

  // 🧩 Widget reutilizable para Productos y Servicios
  Widget _buildTabContent({
    required String collection,
    required Widget Function(DocumentSnapshot) builder,
    required String addButtonLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              Widget page;
              String successMessage;

              if (collection == 'products') {
                page = const ProductFormPage();
                successMessage = '✅ Producto guardado';
              } else if (collection == 'services') {
                page = const ServiceFormPage();
                successMessage = '✅ Servicio guardado';
              } else {
                return;
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
              if (result == true && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(successMessage)));
              }
            },
            icon: const Icon(Icons.add),
            label: Text(addButtonLabel),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collection)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay elementos'));
                }

                // Filtrado del lado del cliente
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final query = _searchQuery.toLowerCase();

                  if (query.isEmpty) return true;

                  // Búsqueda genérica en valores del mapa
                  return data.values.any(
                    (value) => value.toString().toLowerCase().contains(query),
                  );
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay coincidencias'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) => builder(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
