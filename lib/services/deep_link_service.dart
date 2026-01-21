import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/product_detail_page.dart';
import '../screens/service_detail_page.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void init() {
    _appLinks = AppLinks();

    // Handle links when app is in background or terminated
    _handleInitialLink();

    // Listen to incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleUri(uri);
      }
    } catch (e) {
      debugPrint('Error handling initial deep link: $e');
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('Deep Link received: $uri');

    if (uri.scheme == 'techsc') {
      final id = uri.queryParameters['id'];
      if (id == null) return;

      if (uri.host == 'product') {
        navigateToProduct(id);
      } else if (uri.host == 'service') {
        navigateToService(id);
      }
    }
  }

  Future<void> navigateToProduct(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(id)
          .get();
      if (doc.exists && doc.data() != null) {
        final productData = doc.data()!;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                ProductDetailPage(product: productData, productId: id),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to product from deep link: $e');
    }
  }

  Future<void> navigateToService(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(id)
          .get();
      if (doc.exists && doc.data() != null) {
        final serviceData = doc.data()!;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                ServiceDetailPage(service: serviceData, serviceId: id),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to service from deep link: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
