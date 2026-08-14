import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tscomputer/core/providers/ai_providers.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/utils/whatsapp_share_helper.dart';
import 'package:tscomputer/core/widgets/cart_badge.dart';
import 'package:tscomputer/features/catalog/services/supplier_service.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';
import 'package:tscomputer/features/catalog/models/supplier_model.dart';
import 'package:tscomputer/features/catalog/widgets/supplier_link_dialog.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'package:tscomputer/core/utils/snackbar_helper.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final ProductModel product;
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.productId,
  });

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  double _currentRating = 0;
  bool _isRating = false;
  bool _isAdded = false; // State for the add-to-cart animation
  SupplierModel? _supplier; // Store supplier details
  int _currentPage = 0; // State for current image in gallery

  @override
  void initState() {
    super.initState();
    _currentRating = 4.5; // Default rating if not available in model yet
  }

  Future<void> _loadSupplierDetails() async {
    final supplierId = widget.product.supplierId;
    if (supplierId != null && supplierId.isNotEmpty) {
      final supplier = await SupplierService().getSupplierById(supplierId);
      if (mounted) {
        setState(() {
          _supplier = supplier;
        });
      }
    }
  }

  void _addToCart(int liveStock) async {
    if (_isAdded || liveStock <= 0) {
      return; // Prevent double clicks during animation
    }

    try {
      final productToAdd = widget.product.toFirestore()
        ..['id'] = widget.productId
        ..['stock'] = liveStock;
      ref.read(cartServiceProvider).addToCart(productToAdd);

      // Trigger animation state
      setState(() {
        _isAdded = true;
      });

      // Revert state after 1.5 seconds
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _isAdded = false;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e);
      }
    }
  }

  Future<void> _submitRating(double rating) async {
    setState(() {
      _currentRating = rating;
      _isRating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({'rating': rating});
    } catch (e) {
      debugPrint('Error submit rating: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRating = false;
        });
      }
    }
  }

  Widget _buildRatingStars() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Calificar este producto",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: _isRating ? null : () => _submitRating(index + 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        index < _currentRating ? Icons.star : Icons.star_border,
                        color: _isRating ? Colors.grey : Colors.amber,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              if (_isRating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _currentRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSupplierLinkDialog() {
    final supplierLink = widget.product.supplierLink;
    final supplierName = widget.product.name;

    if (supplierLink == null || supplierLink.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => SupplierLinkWebViewDialog(
        url: supplierLink,
        supplierName: supplierName,
      ),
    );
  }

  Widget? _buildSupplierLinkSection(String userRole) {
    final hasPermission =
        userRole == RoleService.ADMIN ||
        userRole == RoleService.SELLER ||
        userRole == RoleService.TECHNICIAN;

    if (!hasPermission) return null;

    if (_supplier == null && widget.product.supplierId != null) {
      _loadSupplierDetails();
    }

    final supplierLink = widget.product.supplierLink;
    final supplierName = widget.product.name;

    if (supplierLink == null || supplierLink.isEmpty) return null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Información del Proveedor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.nearBlack,
                ),
              ),
            ],
          ),
          if (supplierName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              supplierName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showSupplierLinkDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.link),
              label: const Text(
                'Ver Link del Producto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_supplier != null && _supplier!.contactPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  WhatsAppShareHelper.sendSupplierOrder(
                    productData: widget.product.toFirestore()
                      ..['id'] = widget.productId,
                    supplierPhone: _supplier!.contactPhone,
                    supplierContactName: _supplier!.contactName,
                    context: context,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text(
                  'Realizar Pedido (WhatsApp)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = user != null
        ? ref.watch(userRoleProvider(user.uid))
        : const AsyncValue.data(RoleService.CLIENT);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: size.height * 0.40,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Compartir por WhatsApp',
                onPressed: () {
                  WhatsAppShareHelper.shareProduct(
                    widget.product.toFirestore()..['id'] = widget.productId,
                    context,
                  );
                },
              ),
              const CartBadge(color: Colors.black),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final List<String> images =
                        widget.product.images ??
                        ((widget.product.imageUrl != null)
                            ? [widget.product.imageUrl!]
                            : []);

                    if (images.isEmpty) {
                      return const Center(
                        child: Icon(Icons.image_not_supported, size: 80),
                      );
                    }

                    Widget buildLabelBadge() {
                      if (widget.product.label == null ||
                          widget.product.label == 'Ninguna') {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.product.label == 'Oferta'
                                ? Colors.orange
                                : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.product.label!.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }

                    if (images.length == 1) {
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                            child: Hero(
                              tag: 'product-image-${widget.productId}',
                              child: Center(
                                child: CachedNetworkImage(
                                  imageUrl: images[0],
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.image_not_supported,
                                        size: 80,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          buildLabelBadge(),
                        ],
                      );
                    }

                    return Stack(
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                60,
                                20,
                                40,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: images[index],
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.image_not_supported,
                                      size: 80,
                                    ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primary.withAlpha(64),
                                ),
                              );
                            }),
                          ),
                        ),
                        buildLabelBadge(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.nearBlack,
                      height: 1.3,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${widget.product.price}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                          fontSize: 34,
                          letterSpacing: -0.5,
                        ),
                      ),
                      // ... (ignoring taxStatus for now as it's not in the model)
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRatingStars(),
                  const SizedBox(height: 36),
                  Text(
                    "Descripción",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.description,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Note: specs is not in ProductModel yet, adding it to model or handling safely
                  /* if (widget.product.specs != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Especificaciones",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.product.specs.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF4B5563),
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ], */
                  // Supplier link section (role-based)
                  roleAsync.when(
                    data: (role) {
                      final supplierSection = _buildSupplierLinkSection(role);
                      return supplierSection ?? const SizedBox.shrink();
                    },
                    loading: () => const AppLoadingIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  _buildSimilarProductsSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final liveStock = snapshot.hasData && snapshot.data!.exists
              ? (snapshot.data!.data() as Map<String, dynamic>)['stock']
                        as int? ??
                    widget.product.stock
              : widget.product.stock;

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: liveStock > 0 ? () => _addToCart(liveStock) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: liveStock <= 0
                        ? Colors.grey
                        : (_isAdded
                              ? Colors.green[600]
                              : theme.colorScheme.primary),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    animationDuration: const Duration(milliseconds: 300),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(scale: anim, child: child);
                    },
                    child: liveStock <= 0
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            key: ValueKey('out_of_stock'),
                            children: [
                              Icon(
                                Icons.remove_shopping_cart,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Agotado",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : (_isAdded
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  key: ValueKey('added'),
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "¡Agregado!",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  key: ValueKey('normal'),
                                  children: [
                                    Icon(Icons.shopping_bag_outlined),
                                    SizedBox(width: 8),
                                    Text(
                                      "Agregar al Carrito",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimilarProductsSection() {
    final similarAsync = ref.watch(similarProductsProvider(widget.productId));
    return similarAsync.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const Text(
              'Productos Similares',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final p = products[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          product: p,
                          productId: p.id,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: p.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: p.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Container(color: Colors.grey[200]),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${p.price}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
