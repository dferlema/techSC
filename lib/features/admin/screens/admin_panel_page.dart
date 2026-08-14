import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/features/catalog/screens/product_form_page.dart';
import 'package:tscomputer/features/reservations/screens/service_form_page.dart';
import 'package:tscomputer/features/catalog/screens/supplier_management_page.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/widgets/cart_badge.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/features/admin/widgets/admin_orders_tab.dart';
import 'package:tscomputer/features/admin/widgets/admin_clients_tab.dart';
import 'package:tscomputer/features/admin/widgets/admin_product_card.dart';
import 'package:tscomputer/features/admin/widgets/admin_service_card.dart';
import 'package:tscomputer/features/admin/widgets/admin_dashboard_view.dart';
import 'package:tscomputer/features/inventory/widgets/admin_inventory_tab.dart';
import 'package:tscomputer/features/admin/providers/admin_providers.dart';
import 'package:tscomputer/l10n/app_localizations.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'package:tscomputer/core/widgets/app_error_widget.dart';
import 'package:tscomputer/core/theme/app_colors.dart';

// Navigation index constants
class _NavIndex {
  static const int dashboard = 0;
  static const int clients = 1;
  static const int products = 2;
  static const int inventory = 3;
  static const int services = 4;
  static const int orders = 5;
  static const int suppliers = 6;
}

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
    _DrawerItem(index: _NavIndex.dashboard, label: 'Panel', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, color: Color(0xFF09325E)),
    _DrawerItem(index: _NavIndex.clients, label: 'Clientes', icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, color: Color(0xFF1565C0)),
    _DrawerItem(index: _NavIndex.products, label: 'Productos', icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, color: Color(0xFF6A1B9A)),
    _DrawerItem(index: _NavIndex.inventory, label: 'Inventario', icon: Icons.warehouse_outlined, selectedIcon: Icons.warehouse_rounded, color: Color(0xFF00695C)),
    _DrawerItem(index: _NavIndex.services, label: 'Servicios', icon: Icons.build_outlined, selectedIcon: Icons.build_rounded, color: Color(0xFF37474F)),
    _DrawerItem(index: _NavIndex.orders, label: 'Ordenes', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, color: Color(0xFFE65100)),
    _DrawerItem(index: _NavIndex.suppliers, label: 'Proveedores', icon: Icons.business_outlined, selectedIcon: Icons.business_rounded, color: Color(0xFF880E4F)),
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
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  String _currentTitle() {
    switch (_selectedIndex) {
      case _NavIndex.dashboard: return 'Panel de Control';
      case _NavIndex.clients: return 'Clientes';
      case _NavIndex.products: return 'Productos';
      case _NavIndex.inventory: return 'Inventario';
      case _NavIndex.services: return 'Servicios';
      case _NavIndex.orders: return 'Ordenes';
      case _NavIndex.suppliers: return 'Proveedores';
      default: return 'Admin Panel';
    }
  }

  String _subtitleForIndex() {
    switch (_selectedIndex) {
      case _NavIndex.dashboard: return 'Resumen general del sistema';
      case _NavIndex.clients: return 'Gestion de clientes registrados';
      case _NavIndex.products: return 'Catalogo de productos';
      case _NavIndex.inventory: return 'Control de inventario';
      case _NavIndex.services: return 'Servicios tecnicos';
      case _NavIndex.orders: return 'Ordenes de trabajo';
      case _NavIndex.suppliers: return 'Proveedores y contactos';
      default: return '';
    }
  }

  String _roleLabel(String userRole) {
    switch (userRole) {
      case RoleService.ADMIN: return 'Administrador';
      case RoleService.ACCOUNTING: return 'Contabilidad';
      case RoleService.TECHNICIAN: return 'Tecnico';
      case RoleService.SELLER: return 'Vendedor';
      default: return 'Cliente';
    }
  }

  bool _canAccessPanel(String userRole) {
    return userRole == RoleService.ADMIN ||
        userRole == RoleService.SELLER ||
        userRole == RoleService.TECHNICIAN ||
        userRole == RoleService.ACCOUNTING;
  }

  Widget? _buildFAB(AppLocalizations l10n) {
    if (_selectedIndex == _NavIndex.products) {
      return FloatingActionButton(
        key: const ValueKey('fab_products'),
        backgroundColor: const Color(0xFFFF8C00),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormPage()),
          );
          if (result == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.saveSuccess)),
            );
          }
        },
        child: const Icon(Icons.add, size: 28),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.saveSuccess)),
            );
          }
        },
        label: Text(l10n.addService),
        icon: const Icon(Icons.add),
      );
    }
    return null;
  }

  Widget _buildRestriction(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAccessDenied(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(title: Text(l10n.accessDenied)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade100),
              ),
              child: const Icon(Icons.lock, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(l10n.authorizedPersonnelOnly, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.backButton),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Por favor, inicie sesion.')));
        }
        final roleAsync = ref.watch(userRoleProvider(user.uid));
        return roleAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => Scaffold(body: Center(child: Text('Error al cargar rol: $err'))),
          data: (userRole) {
            final bool canAccessPanel = _canAccessPanel(userRole);
            final bool isAdmin = userRole == RoleService.ADMIN;

            if (!canAccessPanel) return _buildAccessDenied(l10n);

            final bool isDesktop = MediaQuery.of(context).size.width >= 1024 || kIsWeb;

            if (isDesktop) {
              return _buildDesktopLayout(context, l10n, userRole, isAdmin);
            }
            return _buildMobileLayout(context, l10n, userRole, isAdmin);
          },
        );
      },
    );
  }

  // Desktop Layout - sidebar persistente + AppBar moderno
  Widget _buildDesktopLayout(BuildContext context, AppLocalizations l10n, String userRole, bool isAdmin) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth > 1600 ? 260.0 : 240.0;
    final contentMaxWidth = screenWidth - sidebarWidth;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar persistente
          Container(
            width: sidebarWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(2, 0))],
            ),
            child: Column(
              children: [
                // Header del sidebar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.accentBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text('TechService Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(_roleLabel(userRole), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                    ],
                  ),
                ),
                // Navigation
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _drawerItems.map((item) {
                      final bool selected = _selectedIndex == item.index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? item.color.withValues(alpha: 0.10) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: selected ? item.color : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(item.label, style: TextStyle(
                            color: selected ? item.color : Colors.grey[700],
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          )),
                          selected: selected,
                          onTap: () => _navigate(item.index),
                          hoverColor: item.color.withValues(alpha: 0.08),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Container(height: 3, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.power_settings_new, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Cerrar Sesion', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Modern AppBar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                   child: Row(
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(_currentTitle(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                             const SizedBox(height: 2),
                             Text(_subtitleForIndex(), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                           ],
                         ),
                       ),
                       // Cart badge
                       Container(
                         decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                         child: const CartBadge(),
                       ),
                     ],
                   ),
                ),
                // Page content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(kIsWeb ? 32 : 16, 16, kIsWeb ? 32 : 16, kIsWeb ? 32 : 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth - 32),
                      child: _buildPageContent(context, l10n, userRole, isAdmin),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(l10n),
    );
  }

  // Mobile Layout - drawer navigation
  Widget _buildMobileLayout(BuildContext context, AppLocalizations l10n, String userRole, bool isAdmin) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(_subtitleForIndex(), style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [const CartBadge(), const SizedBox(width: 8)],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _navigate,
        children: [
          _DrawerHeader(isAdmin: isAdmin, userRole: userRole),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Divider()),
          ..._drawerItems.map((item) => NavigationDrawerDestination(
            icon: Icon(item.icon, color: item.color),
            selectedIcon: Icon(item.selectedIcon, color: item.color),
            label: Text(item.label),
          )),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: AdminDashboardView(onNavigateTo: _navigate)),
          isAdmin || userRole == RoleService.SELLER || userRole == RoleService.TECHNICIAN
              ? AdminClientsTab(isAdmin: isAdmin)
              : _buildRestriction(l10n.onlyAdminClients),
          _AdminTabContent(provider: adminProductsProvider, queryNotifier: adminProductsQueryProvider, builder: (doc) => AdminProductCard(doc: doc), addButtonLabel: l10n.addProduct, collection: 'products', searchController: _searchController),
          _canAccessPanel(userRole) ? const AdminInventoryTab() : _buildRestriction('Solo personal autorizado puede ver el inventario'),
          _AdminTabContent(provider: adminServicesProvider, queryNotifier: adminServicesQueryProvider, builder: (doc) => AdminServiceCard(doc: doc), addButtonLabel: l10n.addService, collection: 'services', searchController: _searchController),
          const AdminOrdersTab(),
          isAdmin || userRole == RoleService.ACCOUNTING || userRole == RoleService.SELLER
              ? const SupplierManagementPage()
              : _buildRestriction(l10n.onlyAdminSuppliers),
        ],
      ),
      floatingActionButton: _buildFAB(l10n),
    );
  }

  Widget _buildPageContent(BuildContext context, AppLocalizations l10n, String userRole, bool isAdmin) {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        AdminDashboardView(onNavigateTo: _navigate),
        isAdmin || userRole == RoleService.SELLER || userRole == RoleService.TECHNICIAN
            ? AdminClientsTab(isAdmin: isAdmin)
            : _buildRestriction(l10n.onlyAdminClients),
        _AdminTabContent(provider: adminProductsProvider, queryNotifier: adminProductsQueryProvider, builder: (doc) => AdminProductCard(doc: doc), addButtonLabel: l10n.addProduct, collection: 'products', searchController: _searchController),
        _canAccessPanel(userRole) ? const AdminInventoryTab() : _buildRestriction('Solo personal autorizado puede ver el inventario'),
        _AdminTabContent(provider: adminServicesProvider, queryNotifier: adminServicesQueryProvider, builder: (doc) => AdminServiceCard(doc: doc), addButtonLabel: l10n.addService, collection: 'services', searchController: _searchController),
        const AdminOrdersTab(),
        isAdmin || userRole == RoleService.ACCOUNTING || userRole == RoleService.SELLER
            ? const SupplierManagementPage()
            : _buildRestriction(l10n.onlyAdminSuppliers),
      ],
    );
  }
}

// Drawer header widget
class _DrawerHeader extends StatelessWidget {
  final bool isAdmin;
  final String userRole;

  const _DrawerHeader({required this.isAdmin, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final roleLabel = isAdmin
        ? 'Administrador'
        : (userRole == RoleService.ACCOUNTING ? 'Contabilidad' : (userRole == RoleService.TECHNICIAN ? 'Tecnico' : 'Vendedor'));
    final roleIcon = isAdmin
        ? Icons.admin_panel_settings
        : (userRole == RoleService.ACCOUNTING ? Icons.account_balance : (userRole == RoleService.TECHNICIAN ? Icons.build : Icons.store));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryBlue, AppColors.accentBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(roleIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TechService Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
              child: Text(roleLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }
}

// Generic tab content - Productos / Servicios
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: widget.searchController,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: AppColors.primaryBlue),
              hintText: l10n.searchHint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (value) => ref.read(widget.queryNotifier.notifier).state = value,
          ),
        ),
        const SizedBox(height: 20),
        // Grid or List based on screen size
        Expanded(
          child: ref.watch(widget.provider).when(
                loading: () => const AppLoadingIndicator(),
                error: (err, _) => AppErrorWidget(error: err, onRetry: () => ref.invalidate(widget.provider)),
                data: (docs) {
                  if (docs.isEmpty) {
                    return _buildEmptyState(l10n.noMatchesFound);
                  }

                  if (isDesktop) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final crossAxisCount = screenWidth > 1400 ? 4 : screenWidth > 1100 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) => widget.builder(docs[index]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: widget.builder(docs[index]),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
            child: Icon(Icons.search, size: 32, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
