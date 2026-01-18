import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper class to share products and services via WhatsApp
class WhatsAppShareHelper {
  /// Share a product via WhatsApp/Share Sheet
  ///
  /// [productData] should contain: name, price, description, and optionally image or images
  /// [context] is used for feedback
  static Future<void> shareProduct(
    Map<String, dynamic> productData,
    BuildContext context,
  ) async {
    final String productName = productData['name'] ?? 'Producto';
    final String price = productData['price']?.toString() ?? '0';
    final String description = productData['description'] ?? '';
    final double? rating = productData['rating'] is int
        ? (productData['rating'] as int).toDouble()
        : productData['rating'] as double?;

    // Image handling: check 'image' (string) or 'images' (list)
    String? imageUrl;
    if (productData['image'] != null && productData['image'] is String) {
      imageUrl = productData['image'];
    } else if (productData['images'] != null &&
        productData['images'] is List &&
        (productData['images'] as List).isNotEmpty) {
      imageUrl = (productData['images'] as List).first;
    }

    // Format the message
    String message = '🛍️ *$productName*\n\n';
    message += '💰 Precio: \$$price\n\n';

    if (rating != null && rating > 0) {
      message += '⭐ Calificación: ${rating.toStringAsFixed(1)}/5.0\n\n';
    }

    if (description.isNotEmpty) {
      message += '📝 Descripción:\n$description\n\n';
    }

    // Add deep link for "Ver más"
    if (productData['id'] != null) {
      message += '🔗 *Ver más en la app:* \n';
      message += 'techsc://product?id=${productData['id']}\n\n';
    }

    message += '---\n';
    message += '📱 Compartido desde TechServiceComputer';

    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _shareWithImage(message, imageUrl, context, subject: productName);
    } else {
      await _launchWhatsApp(message, context);
    }
  }

  /// Share a service via WhatsApp/Share Sheet
  ///
  /// [serviceData] should contain: title, price, description, duration, and optionally imageUrl or imageUrls
  /// [context] is used for feedback
  static Future<void> shareService(
    Map<String, dynamic> serviceData,
    BuildContext context,
  ) async {
    final String serviceTitle = serviceData['title'] ?? 'Servicio';
    final String price = serviceData['price']?.toString() ?? '0';
    final String description = serviceData['description'] ?? '';
    final String? duration = serviceData['duration'];
    final double? rating = serviceData['rating'] is int
        ? (serviceData['rating'] as int).toDouble()
        : serviceData['rating'] as double?;

    // Image handling: check 'imageUrl' (string) or 'imageUrls' (list)
    String? imageUrl;
    if (serviceData['imageUrl'] != null && serviceData['imageUrl'] is String) {
      imageUrl = serviceData['imageUrl'];
    } else if (serviceData['imageUrls'] != null &&
        serviceData['imageUrls'] is List &&
        (serviceData['imageUrls'] as List).isNotEmpty) {
      imageUrl = (serviceData['imageUrls'] as List).first;
    }

    // Format the message
    String message = '🔧 *$serviceTitle*\n\n';
    message += '💰 Precio: \$$price\n\n';

    if (duration != null && duration.isNotEmpty) {
      message += '⏱️ Duración: $duration\n\n';
    }

    if (rating != null && rating > 0) {
      message += '⭐ Calificación: ${rating.toStringAsFixed(1)}/5.0\n\n';
    }

    if (description.isNotEmpty) {
      message += '📝 Descripción:\n$description\n\n';
    }

    // Add deep link for "Ver más"
    if (serviceData['id'] != null) {
      message += '🔗 *Ver más en la app:* \n';
      message += 'techsc://service?id=${serviceData['id']}\n\n';
    }

    message += '---\n';
    message += '📱 Compartido desde TechServiceComputer';

    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _shareWithImage(message, imageUrl, context, subject: serviceTitle);
    } else {
      await _launchWhatsApp(message, context);
    }
  }

  /// Share text and an image using the system share sheet
  static Future<void> _shareWithImage(
    String message,
    String imageUrl,
    BuildContext context, {
    String? subject,
  }) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(path)], text: message, subject: subject);
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      debugPrint('Error sharing with image: $e');
      // Fallback to text-only WhatsApp launch
      if (context.mounted) {
        await _launchWhatsApp(message, context);
      }
    }
  }

  /// Launch WhatsApp with the given message (Text-only fallback)
  static Future<void> _launchWhatsApp(
    String message,
    BuildContext context,
  ) async {
    final String encodedMessage = Uri.encodeComponent(message);

    final List<Uri> urls = [
      Uri.parse('whatsapp://send?text=$encodedMessage'),
      Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage'),
      Uri.parse('https://wa.me/?text=$encodedMessage'),
    ];

    bool launched = false;
    for (var url in urls) {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        }
      } catch (e) {
        debugPrint('Failed to launch $url: $e');
      }
    }

    if (!launched && context.mounted) {
      _showErrorSnackBar(
        context,
        'No se pudo abrir WhatsApp. Asegúrate de tenerlo instalado.',
      );
    }
  }

  /// Show error message to user
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
