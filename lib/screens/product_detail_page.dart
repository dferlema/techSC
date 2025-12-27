import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cart_service.dart';
import '../utils/whatsapp_share_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _currentRating = (widget.product['rating'] is int)
        ? (widget.product['rating'] as int).toDouble()
        : (widget.product['rating'] as double? ?? 4.5);
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
                  WhatsAppShareHelper.shareProduct(widget.product, context);
                },
              ),
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

                    if (images.length == 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                        child: Hero(
                          tag: 'product-image-${widget.productId}',
                          child: Image.network(
                            images[0],
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.image_not_supported, size: 80),
                          ),
                        ),
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
                  Text(
                    '\$${widget.product['price'] ?? 0}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      fontSize: 34,
                      letterSpacing: -0.5,
                    ),
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
                              fontFamily: 'Courier',
                              fontSize: 17,
                              color: Color(0xFF374151), // Dark grey for specs
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
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
