import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/features/cart/services/cart_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/utils/whatsapp_share_helper.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/features/catalog/widgets/supplier_link_dialog.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.productId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  double _currentRating = 0;
  bool _isRating = false;
  bool _isAdded = false; // State for the add-to-cart animation
  String _userRole = RoleService.CLIENT; // Track user role

  @override
  void initState() {
    super.initState();
    _currentRating = (widget.product['rating'] is int)
        ? (widget.product['rating'] as int).toDouble()
        : (widget.product['rating'] as double? ?? 4.5);
    _loadUserRole();
  }

  /// Load the current user's role
  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await RoleService().getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    }
  }

  void _addToCart() async {
    if (_isAdded) return; // Prevent double clicks during animation

    final productToAdd = {...widget.product, 'id': widget.productId};
    CartService.instance.addToCart(productToAdd);

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

      // Optional: Small tactile feedback or toast could go here, but avoiding SnackBar for now
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
            color: Colors.black.withOpacity(0.05),
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

  /// Show popup dialog with supplier product link and web preview
  void _showSupplierLinkDialog() {
    final supplierLink = widget.product['supplierProductLink'] as String?;
    final supplierName = widget.product['supplierName'] as String?;

    if (supplierLink == null || supplierLink.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => SupplierLinkWebViewDialog(
        url: supplierLink,
        supplierName: supplierName,
      ),
    );
  }

  /// Build supplier link section (visible only to admin, seller, technician)
  Widget? _buildSupplierLinkSection() {
    // Check if user has permission
    final hasPermission =
        _userRole == RoleService.ADMIN ||
        _userRole == RoleService.SELLER ||
        _userRole == RoleService.TECHNICIAN;

    if (!hasPermission) return null;

    final supplierLink = widget.product['supplierProductLink'] as String?;
    final supplierName = widget.product['supplierName'] as String?;

    // Don't show if no link
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
              const Text(
                'Información del Proveedor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          if (supplierName != null && supplierName.isNotEmpty) ...[
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean off-white
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
                  WhatsAppShareHelper.shareProduct({
                    ...widget.product,
                    'id': widget.productId,
                  }, context);
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
                        (widget.product['images'] != null)
                        ? List<String>.from(widget.product['images'])
                        : (widget.product['image'] != null
                              ? [widget.product['image']]
                              : []);

                    if (images.isEmpty) {
                      return const Center(
                        child: Icon(Icons.image_not_supported, size: 80),
                      );
                    }

                    Widget buildLabelBadge() {
                      if (widget.product['label'] == null ||
                          widget.product['label'] == 'Ninguna') {
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
                            color: widget.product['label'] == 'Oferta'
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
                            widget.product['label'].toString().toUpperCase(),
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
                                child: Image.network(
                                  images[0],
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(
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
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                60,
                                20,
                                40,
                              ),
                              child: Image.network(
                                images[index],
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(
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
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.5,
                                  ),
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
                    widget.product['name'] ?? 'Producto',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(
                        0xFF111111,
                      ), // Almost black for better contrast
                      height: 1.3,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${widget.product['price'] ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                          fontSize: 34,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (widget.product['taxStatus'] != null &&
                          widget.product['taxStatus'] != 'Ninguno')
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 6),
                          child: Text(
                            widget.product['taxStatus'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRatingStars(),
                  const SizedBox(height: 36),
                  const Text(
                    "Descripción",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product['description'] ?? 'Sin descripción.',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Color(0xFF444444), // Darker grey for body text
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (widget.product['specs'] != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFF3F4F6,
                        ), // Slightly darker background
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
                            widget.product['specs'].toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(
                                0xFF4B5563,
                              ), // Darker grey for better contrast
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  // Supplier link section (role-based)
                  if (_buildSupplierLinkSection() != null) ...[
                    _buildSupplierLinkSection()!,
                    const SizedBox(height: 100), // Bottom padding
                  ] else ...[
                    const SizedBox(height: 100), // Bottom padding
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56, // Fixed height for button
            child: ElevatedButton(
              onPressed: _addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdded
                    ? Colors.green[600]
                    : theme.colorScheme.primary,
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
                child: _isAdded
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        key: ValueKey('added'),
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
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
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
