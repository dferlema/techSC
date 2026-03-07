import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:techsc/features/admin/widgets/admin_dashboard_view.dart';
import 'package:techsc/features/inventory/widgets/admin_inventory_tab.dart';
import 'package:techsc/features/accounting/screens/accounting_tab.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/features/accounting/widgets/transaction_form_dialog.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Constantes de navegación
// ---------------------------------------------------------------------------

/// Índices del [IndexedStack] del panel de administración.
/// 0 = Dashboard, 1..7 = secciones específicas.
class _NavIndex {
  static const int dashboard = 0;
  static const int clients = 1;
  static const int products = 2;
  static const int inventory = 3;
  static const int services = 4;
  static const int orders = 5;
  static const int suppliers = 6;
  static const int accounting = 7;
}

// ---------------------------------------------------------------------------
// Widget principal
// ---------------------------------------------------------------------------

class AdminPanelPage extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const AdminPanelPage({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage> {
  late int _selectedIndex;
  late TextEditingController _searchController;

  static const List<_DrawerItem> _drawerItems = [
    _DrawerItem(
      index: _NavIndex.dashboard,
      label: 'Panel',
      icon: Icons.dashboard_rounded,
      selectedIcon: Icons.dashboard,
      color: Color(0xFF09325E),
    ),
    _DrawerItem(
      index: _NavIndex.clients,
      label: 'Clientes',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      color: Color(0xFF1565C0),
    ),
    _DrawerItem(
      index: _NavIndex.products,
      label: 'Productos',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      color: Color(0xFF6A1B9A),
    ),
    _DrawerItem(
      index: _NavIndex.inventory,
      label: 'Inventario',
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse_rounded,
      color: Color(0xFF00695C),
    ),
    _DrawerItem(
      index: _NavIndex.services,
      label: 'Servicios',
      icon: Icons.build_outlined,
      selectedIcon: Icons.build_rounded,
      color: Color(0xFF37474F),
    ),
    _DrawerItem(
      index: _NavIndex.orders,
      label: 'Órdenes',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      color: Color(0xFFE65100),
    ),
    _DrawerItem(
      index: _NavIndex.suppliers,
      label: 'Proveedores',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business_rounded,
      color: Color(0xFF880E4F),
    ),
    _DrawerItem(
      index: _NavIndex.accounting,
      label: 'Contabilidad',
      icon: Icons.calculate_outlined,
      selectedIcon: Icons.calculate_rounded,
      color: Color(0xFF1B5E20),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigate(int index) {
    setState(() => _selectedIndex = index);

    // Cerrar el drawer solo si está abierto
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  // -------------------------------------------------------------------------
  // FAB contextual: sólo en Productos, Servicios y Contabilidad
  // -------------------------------------------------------------------------
  Widget? _buildFAB(AppLocalizations l10n) {
    if (_selectedIndex == _NavIndex.products) {
      return FloatingActionButton.extended(
        key: const ValueKey('fab_products'),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormPage()),
          );
          if (result == true && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
          }
        },
        label: Text(l10n.addProduct),
        icon: const Icon(Icons.add),
      );
    }
    if (_selectedIndex == _NavIndex.services) {
      return FloatingActionButton.extended(
        key: const ValueKey('fab_services'),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServiceFormPage()),
          );
          if (result == true && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
          }
        },
        label: Text(l10n.addService),
        icon: const Icon(Icons.add),
      );
    }
    if (_selectedIndex == _NavIndex.accounting) {
      return FloatingActionButton.extended(
        key: const ValueKey('fab_accounting'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const TransactionFormDialog(),
        ),
        label: const Text('Agregar Movimiento'),
        icon: const Icon(Icons.add),
      );
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Título dinámico del AppBar según sección activa
  // -------------------------------------------------------------------------
  String _currentTitle() {
    switch (_selectedIndex) {
      case _NavIndex.dashboard:
        return 'Admin Panel';
      case _NavIndex.clients:
        return 'Clientes';
      case _NavIndex.products:
        return 'Productos';
      case _NavIndex.inventory:
        return 'Inventario';
      case _NavIndex.services:
        return 'Servicios';
      case _NavIndex.orders:
        return 'Órdenes';
      case _NavIndex.suppliers:
        return 'Proveedores';
      case _NavIndex.accounting:
        return 'Contabilidad';
      default:
        return 'Admin Panel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Por favor, inicie sesión.')),
          );
        }
        final roleAsync = ref.watch(userRoleProvider(user.uid));
        return roleAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) =>
              Scaffold(body: Center(child: Text('Error al cargar rol: $err'))),
          data: (userRole) {
            final bool canAccessPanel =
                userRole == RoleService.ADMIN || userRole == RoleService.SELLER;
            final bool isAdmin = userRole == RoleService.ADMIN;

            if (!canAccessPanel) return _buildAccessDenied(l10n);

            return Scaffold(
              key: _scaffoldKey,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    // Si no estamos en el Dashboard, regresar al Dashboard primero
                    if (_selectedIndex != _NavIndex.dashboard) {
                      setState(() => _selectedIndex = _NavIndex.dashboard);
                    } else {
                      // Si ya estamos en el Dashboard, salir del Panel de Control
                      Navigator.of(context).canPop()
                          ? Navigator.of(context).pop()
                          : Navigator.of(context).pushReplacementNamed('/main');
                    }
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentTitle(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.adminPanelSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                actions: [const CartBadge(), const SizedBox(width: 8)],
              ),
              // ---------------------------------------------------------------
              // Drawer de navegación (Material 3 NavigationDrawer)
              // ---------------------------------------------------------------
              drawer: NavigationDrawer(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _navigate,
                children: [
                  // Header del drawer
                  _DrawerHeader(isAdmin: isAdmin, userRole: userRole),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),
                  // Destinos
                  ..._drawerItems.map(
                    (item) => NavigationDrawerDestination(
                      icon: Icon(item.icon, color: item.color),
                      selectedIcon: Icon(item.selectedIcon, color: item.color),
                      label: Text(item.label),
                    ),
                  ),
                ],
              ),
              // ---------------------------------------------------------------
              // Cuerpo principal con IndexedStack
              // ---------------------------------------------------------------
              body: IndexedStack(
                index: _selectedIndex,
                children: [
                  // 0 — Dashboard
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AdminDashboardView(onNavigateTo: _navigate),
                  ),
                  // 1 — Clientes
                  isAdmin
                      ? const AdminClientsTab()
                      : _buildRestriction(l10n.onlyAdminClients),
                  // 2 — Productos
                  _AdminTabContent(
                    provider: adminProductsProvider,
                    queryNotifier: adminProductsQueryProvider,
                    builder: (doc) => AdminProductCard(doc: doc),
                    addButtonLabel: l10n.addProduct,
                    collection: 'products',
                    searchController: _searchController,
                  ),
                  // 3 — Inventario
                  canAccessPanel
                      ? const AdminInventoryTab()
                      : _buildRestriction(
                          'Solo personal autorizado puede ver el inventario',
                        ),
                  // 4 — Servicios
                  _AdminTabContent(
                    provider: adminServicesProvider,
                    queryNotifier: adminServicesQueryProvider,
                    builder: (doc) => AdminServiceCard(doc: doc),
                    addButtonLabel: l10n.addService,
                    collection: 'services',
                    searchController: _searchController,
                  ),
                  // 5 — Órdenes
                  const AdminOrdersTab(),
                  // 6 — Proveedores
                  isAdmin
                      ? const SupplierManagementPage()
                      : _buildRestriction(l10n.onlyAdminSuppliers),
                  // 7 — Contabilidad
                  const AccountingTab(),
                ],
              ),
              floatingActionButton: _buildFAB(l10n),
            );
          },
        );
      },
    );
  }

  Widget _buildRestriction(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildAccessDenied(AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accessDenied)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              l10n.authorizedPersonnelOnly,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.backButton),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawer header widget
// ---------------------------------------------------------------------------

class _DrawerHeader extends StatelessWidget {
  final bool isAdmin;
  final String userRole;

  const _DrawerHeader({required this.isAdmin, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final roleLabel = isAdmin ? 'Administrador' : 'Vendedor';
    final roleIcon = isAdmin ? Icons.admin_panel_settings : Icons.store;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(roleIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TechService Pro',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modelo de ítem del drawer
// ---------------------------------------------------------------------------

class _DrawerItem {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;

  const _DrawerItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// Tab genérico para Productos / Servicios (sin cambios en lógica)
// ---------------------------------------------------------------------------

class _AdminTabContent extends ConsumerStatefulWidget {
  final StreamProvider<List<DocumentSnapshot>> provider;
  final StateProvider<String> queryNotifier;
  final Widget Function(DocumentSnapshot) builder;
  final String addButtonLabel;
  final String collection;
  final TextEditingController searchController;

  const _AdminTabContent({
    required this.provider,
    required this.queryNotifier,
    required this.builder,
    required this.addButtonLabel,
    required this.collection,
    required this.searchController,
  });

  @override
  ConsumerState<_AdminTabContent> createState() => _AdminTabContentState();
}

class _AdminTabContentState extends ConsumerState<_AdminTabContent> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(widget.provider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: widget.searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: AppColors.primaryBlue),
                hintText: l10n.searchHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: (value) =>
                  ref.read(widget.queryNotifier.notifier).state = value,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: itemsAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (err, _) => AppErrorWidget(
                error: err,
                onRetry: () => ref.invalidate(widget.provider),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(child: Text(l10n.noMatchesFound));
                }
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => widget.builder(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
