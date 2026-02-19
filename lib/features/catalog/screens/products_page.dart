import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/catalog/models/product_model.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/cart/screens/cart_page.dart';
import 'package:techsc/features/catalog/screens/product_detail_page.dart';
import 'package:techsc/features/catalog/providers/product_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:techsc/l10n/app_localizations.dart';

class ProductsPage extends ConsumerStatefulWidget {
  final String routeName;
  const ProductsPage({super.key, this.routeName = '/products'});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Initialize controller after first frame to ensure PageView is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = ref.read(productCategoriesProvider).value ?? [];
      final selectedId = ref.read(productSelectedCategoryIdProvider);
      if (selectedId != null && categories.isNotEmpty) {
        final index = categories.indexWhere((c) => c.id == selectedId);
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

  void _addToCart(ProductModel product) {
    ref
        .read(cartServiceProvider)
        .addToCart(product.toFirestore()..['id'] = product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${product.name} agregado al carrito'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VER',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(productCategoriesProvider);
    final selectedCategoryId = ref.watch(productSelectedCategoryIdProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (selectedCategoryId == null && categories.isNotEmpty) {
          // Use microtask to avoid updating during build
          Future.microtask(
            () => ref.read(productSelectedCategoryIdProvider.notifier).state =
                categories.first.id,
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
                  ref.read(productSearchQueryProvider.notifier).state = '';
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
                      border: InputBorder.none,
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) =>
                        ref.read(productSearchQueryProvider.notifier).state =
                            value,
                  )
                : Text(AppLocalizations.of(context)!.productsTitle),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() => _isSearching = !_isSearching);
                  if (!_isSearching) {
                    ref.read(productSearchQueryProvider.notifier).state = '';
                    _searchController.clear();
                  }
                },
              ),
              const CartBadge(),
              const SizedBox(width: 8),
            ],
            bottom: categories.isEmpty
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
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
                                            productSelectedCategoryIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      cat.id;
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
                              pressElevation: 2,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          body: categories.isEmpty
              ? _buildEmptyState(false)
              : PageView.builder(
                  controller: _pageController,
                  itemCount: categories.length,
                  onPageChanged: (index) {
                    ref.read(productSelectedCategoryIdProvider.notifier).state =
                        categories[index].id;
                  },
                  itemBuilder: (context, index) {
                    return _buildProductList(categories[index].id);
                  },
                ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.productsTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.productsTitle),
        ),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noCategoriesConfigured,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(String categoryId) {
    final productsAsync = ref.watch(filteredProductsProvider(categoryId));
    final searchQuery = ref.watch(productSearchQueryProvider);

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? AppLocalizations.of(context)!.noMoreProducts
                      : AppLocalizations.of(context)!.noSearchResults,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final theme = Theme.of(context);
    final price = product.price;
    final String label = product.label ?? '';

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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProductDetailPage(product: product, productId: product.id),
          ),
        ),
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
                          product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
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
                  if (label.isNotEmpty && label != 'Ninguna')
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: label == 'Oferta'
                              ? Colors.orange[800]
                              : theme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
                        product.name,
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
                        product.description,
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
                              if (label == 'Oferta')
                                Text(
                                  '\$${(price * 1.2).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
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
                                onTap: () => _addToCart(product),
                                borderRadius: BorderRadius.circular(15),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Comprar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
          Icons.image_not_supported_outlined,
          size: size,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
