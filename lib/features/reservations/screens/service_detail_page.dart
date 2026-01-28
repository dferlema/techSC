import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/utils/whatsapp_share_helper.dart';
import 'package:techsc/core/widgets/cart_badge.dart';

class ServiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final String serviceId;

  const ServiceDetailPage({
    super.key,
    required this.service,
    required this.serviceId,
  });

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  double _currentRating = 0;
  bool _isRating = false;

  @override
  void initState() {
    super.initState();
    _currentRating = (widget.service['rating'] is int)
        ? (widget.service['rating'] as int).toDouble()
        : (widget.service['rating'] as double? ?? 4.5);
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
            "Calificar este servicio",
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
                tooltip: 'Compartir por WhatsApp',
                onPressed: () {
                  WhatsAppShareHelper.shareService({
                    ...widget.service,
                    'id': widget.serviceId,
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
                        (widget.service['imageUrls'] != null)
                        ? List<String>.from(widget.service['imageUrls'])
                        : (widget.service['imageUrl'] != null
                              ? [widget.service['imageUrl']]
                              : []);

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
                          child: Image.network(
                            images[0],
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(
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
                              child: Image.network(
                                images[index],
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(
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
                    widget.service['title'] ?? 'Servicio',
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
                            '\$${widget.service['price'] ?? 0}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                              fontSize: 34,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (widget.service['taxStatus'] != null &&
                              widget.service['taxStatus'] != 'Ninguno')
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                bottom: 6,
                              ),
                              child: Text(
                                widget.service['taxStatus'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (widget.service['duration'] != null &&
                          widget.service['duration'].toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.service['duration'],
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                    widget.service['description'] ?? 'Sin descripción.',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Color(0xFF444444),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (widget.service['components'] != null &&
                      (widget.service['components'] as List).isNotEmpty) ...[
                    const Text(
                      "Lo que incluye",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(widget.service['components'] as List).map(
                      (component) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 20,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                component.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
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
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/main',
                  arguments: '/reserve-service',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined),
                  SizedBox(width: 8),
                  Text(
                    "Reservar este Servicio",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
