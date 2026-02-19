import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/core/utils/whatsapp_share_helper.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/features/reservations/models/service_model.dart';
import 'package:techsc/l10n/app_localizations.dart';

class ServiceDetailPage extends ConsumerStatefulWidget {
  final ServiceModel service;
  final String serviceId;

  const ServiceDetailPage({
    super.key,
    required this.service,
    required this.serviceId,
  });

  @override
  ConsumerState<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends ConsumerState<ServiceDetailPage> {
  double _currentRating = 0;
  bool _isRating = false;
  bool _isAdded = false; // Add state for animation

  @override
  void initState() {
    super.initState();
    _currentRating = 4.5; // Default rating
  }

  Future<void> _submitRating(double rating) async {
    setState(() {
      _currentRating = rating;
      _isRating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
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

  void _addToCart() async {
    if (_isAdded) return;

    final serviceToAdd = widget.service.toFirestore()
      ..['id'] = widget.serviceId;
    ref.read(cartServiceProvider).addToCart(serviceToAdd, type: 'service');

    setState(() {
      _isAdded = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isAdded = false;
      });
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
          Text(
            AppLocalizations.of(context)!.rateService,
            style: const TextStyle(
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
      backgroundColor: const Color(0xFFF8F9FA),
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
                tooltip: AppLocalizations.of(context)!.shareWhatsApp,
                onPressed: () {
                  WhatsAppShareHelper.shareService(
                    widget.service.toFirestore()..['id'] = widget.serviceId,
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
                        (widget.service.imageUrl != null)
                        ? [widget.service.imageUrl!]
                        : [];

                    if (images.isEmpty) {
                      return const Center(
                        child: Icon(
                          Icons.build_circle,
                          size: 80,
                          color: Colors.grey,
                        ),
                      );
                    }

                    if (images.length == 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                        child: Hero(
                          tag: 'service-image-${widget.serviceId}',
                          child: CachedNetworkImage(
                            imageUrl: images[0],
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.build_circle,
                              size: 80,
                              color: Colors.grey,
                            ),
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
                                      Icons.build_circle,
                                      size: 80,
                                      color: Colors.grey,
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
                    widget.service.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                      height: 1.3,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${widget.service.price}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                              fontSize: 34,
                              letterSpacing: -0.5,
                            ),
                          ),
                          // taxStatus not in model yet
                        ],
                      ),
                      // duration not in model yet
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRatingStars(),
                  const SizedBox(height: 36),
                  Text(
                    AppLocalizations.of(context)!.descriptionTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.service.description,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Color(0xFF444444),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // components not in model yet
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
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
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
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isAdded
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              key: const ValueKey('added'),
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.addedHighlight,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              key: const ValueKey('normal'),
                              children: [
                                Icon(Icons.shopping_bag_outlined),
                                SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.addToCart,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/main',
                      arguments: '/reserve-service',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.reserveButton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
}
