import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:techsc/features/inventory/widgets/admin_inventory_tab.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';

class AdminPanelPage extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const AdminPanelPage({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _searchController = TextEditingController();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _clearSearch();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    final index = _tabController.index;
    if (index == 1) ref.read(adminProductsQueryProvider.notifier).state = '';
    if (index == 3) ref.read(adminServicesQueryProvider.notifier).state = '';
    if (index == 4) ref.read(adminOrdersQueryProvider.notifier).state = '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
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
          error: (err, stack) =>
              Scaffold(body: Center(child: Text('Error al cargar rol: $err'))),
          data: (userRole) {
            final bool canAccessPanel =
                userRole == RoleService.ADMIN || userRole == RoleService.SELLER;
            final bool isAdmin = userRole == RoleService.ADMIN;

            if (!canAccessPanel) {
              return _buildAccessDenied(l10n);
            }

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : Navigator.of(context).pushReplacementNamed('/main'),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminPanelTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.adminPanelSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.category, color: Colors.white),
                    tooltip: l10n.manageCategories,
                    onPressed: () =>
                        Navigator.pushNamed(context, '/category-management'),
                  ),
                  const CartBadge(),
                  const SizedBox(width: 8),
                ],
              ),
              body: _buildBody(isAdmin, canAccessPanel, l10n),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _tabController.index,
                onDestinationSelected: (int index) {
                  setState(() => _tabController.animateTo(index));
                },
                destinations: <NavigationDestination>[
                  NavigationDestination(
                    icon: const Icon(Icons.people_outline),
                    selectedIcon: const Icon(Icons.people),
                    label: l10n.clientsTab,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.inventory_2_outlined),
                    selectedIcon: const Icon(Icons.inventory_2),
                    label: l10n.productsTab,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.warehouse_outlined),
                    selectedIcon: const Icon(Icons.warehouse),
                    label: l10n.inventoryTab,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.build_outlined),
                    selectedIcon: const Icon(Icons.build),
                    label: l10n.servicesTab,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.receipt_long_outlined),
                    selectedIcon: const Icon(Icons.receipt_long),
                    label: l10n.ordersTab,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.business_outlined),
                    selectedIcon: const Icon(Icons.business),
                    label: l10n.suppliersTab,
                  ),
                ],
              ),
            );
          },
        );
      },
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

  Widget _buildBody(bool isAdmin, bool canAccessPanel, AppLocalizations l10n) {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        isAdmin
            ? const AdminClientsTab()
            : _buildPermissionRestriction(l10n.onlyAdminClients),
        _AdminTabContent(
          provider: adminProductsProvider,
          queryNotifier: adminProductsQueryProvider,
          builder: (doc) => AdminProductCard(doc: doc),
          addButtonLabel: l10n.addProduct,
          collection: 'products',
          searchController: _searchController,
        ),
        canAccessPanel
            ? const AdminInventoryTab()
            : _buildPermissionRestriction(
                'Solo personal autorizado puede ver el inventario',
              ),
        _AdminTabContent(
          provider: adminServicesProvider,
          queryNotifier: adminServicesQueryProvider,
          builder: (doc) => AdminServiceCard(doc: doc),
          addButtonLabel: l10n.addService,
          collection: 'services',
          searchController: _searchController,
        ),
        const AdminOrdersTab(),
        isAdmin
            ? const SupplierManagementPage()
            : _buildPermissionRestriction(l10n.onlyAdminSuppliers),
      ],
    );
  }

  Widget _buildPermissionRestriction(String message) {
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
}

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
          TextField(
            controller: widget.searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.searchHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) =>
                ref.read(widget.queryNotifier.notifier).state = value,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              Widget page = widget.collection == 'products'
                  ? const ProductFormPage()
                  : const ServiceFormPage();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
              if (result == true && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
              }
            },
            icon: const Icon(Icons.add),
            label: Text(widget.addButtonLabel),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
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
                return ListView.builder(
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
