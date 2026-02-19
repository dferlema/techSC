import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/reservations/screens/service_detail_page.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/features/cart/screens/cart_page.dart';
import 'package:techsc/features/reservations/models/service_model.dart';
import 'package:techsc/features/reservations/providers/service_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:techsc/l10n/app_localizations.dart';

class ServicesPage extends ConsumerStatefulWidget {
  final String routeName;
  const ServicesPage({super.key, this.routeName = '/services'});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Sync PageController with initial selected category
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = ref.read(serviceCategoriesProvider).value ?? [];
      final fullCategories = [
        CategoryModel(
          id: '',
          name: AppLocalizations.of(context)!.allCategories,
          type: CategoryType.service,
        ),
        ...categories,
      ];
      final selectedId = ref.read(serviceSelectedCategoryIdProvider);
      if (selectedId != null) {
        final index = fullCategories.indexWhere((c) => c.id == selectedId);
        if (index != -1 && _pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deleteService(String? categoryId, String serviceId) async {
    await ref
        .read(filteredServicesProvider(categoryId).notifier)
        .deleteService(serviceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.serviceDeleted)),
    );
  }

  void _addToCart(ServiceModel service) {
    ref
        .read(cartServiceProvider)
        .addToCart(service.toFirestore()..['id'] = service.id, type: 'service');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.addedToCart(service.name)),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.viewCart,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceList(String? categoryId, bool canManage) {
    final servicesAsync = ref.watch(filteredServicesProvider(categoryId));

    return servicesAsync.when(
      data: (filtered) {
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 60,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.emptyServices,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final service = filtered[index];
            return _buildServiceCard(
              service: service,
              serviceId: service.id,
              canManage: canManage,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = user != null
        ? ref.watch(userRoleProvider(user.uid))
        : const AsyncValue.data(RoleService.CLIENT);

    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final selectedCategoryId = ref.watch(serviceSelectedCategoryIdProvider);

    return categoriesAsync.when(
      data: (categories) {
        final fullCategories = [
          CategoryModel(
            id: '',
            name: AppLocalizations.of(context)!.allCategories,
            type: CategoryType.service,
          ),
          ...categories,
        ];

        if (selectedCategoryId == null) {
          Future.microtask(
            () =>
                ref.read(serviceSelectedCategoryIdProvider.notifier).state = '',
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isSearching) {
                  setState(() => _isSearching = false);
                  ref.read(serviceSearchQueryProvider.notifier).state = '';
                  _searchController.clear();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/main');
                }
              },
            ),
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchHint,
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    onChanged: (value) =>
                        ref.read(serviceSearchQueryProvider.notifier).state =
                            value,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.servicesTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.expertSupport,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() => _isSearching = !_isSearching);
                  if (!_isSearching) {
                    ref.read(serviceSearchQueryProvider.notifier).state = '';
                    _searchController.clear();
                  }
                },
              ),
              const CartBadge(color: Colors.white),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: fullCategories.length,
                  itemBuilder: (context, index) {
                    final cat = fullCategories[index];
                    final isSelected = selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.indigo[900]?.withOpacity(0.7),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref
                                .read(
                                  serviceSelectedCategoryIdProvider.notifier,
                                )
                                .state = cat
                                .id;
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        selectedColor: Colors.indigo[600],
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.indigo[100]!,
                          ),
                        ),
                        elevation: isSelected ? 4 : 0,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          body: roleAsync.when(
            data: (role) {
              final canManage =
                  (role == RoleService.ADMIN || role == RoleService.TECHNICIAN);
              return PageView.builder(
                controller: _pageController,
                itemCount: fullCategories.length,
                onPageChanged: (index) {
                  ref.read(serviceSelectedCategoryIdProvider.notifier).state =
                      fullCategories[index].id;
                },
                itemBuilder: (context, index) {
                  return _buildServiceList(fullCategories[index].id, canManage);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, __) => Center(child: Text('Error: $err')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.servicesTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, __) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.servicesTitle),
        ),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildServiceCard({
    required ServiceModel service,
    String? serviceId,
    required bool canManage,
  }) {
    final theme = Theme.of(context);
    final price = service.price;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (serviceId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ServiceDetailPage(service: service, serviceId: serviceId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Stack(
                children: [
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      child:
                          service.imageUrl != null &&
                              service.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: service.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(size: 40),
                            )
                          : _buildPlaceholder(size: 40),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          const Text(
                            '4.8', // Rating not yet in model
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.black87,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        service.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          if (!canManage)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange[700]!,
                                    Colors.orange[400]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _addToCart(service),
                                  borderRadius: BorderRadius.circular(15),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context)!.buyButton,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (serviceId != null)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.editUsingAdminPanel,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteService(
                                    service.categoryId,
                                    serviceId,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({double size = 50}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.build_circle_outlined,
          size: size,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
