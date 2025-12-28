import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper class to share products and services via WhatsApp
class WhatsAppShareHelper {
  /// Share a product via WhatsApp
  ///
  /// [productData] should contain: name, price, description, and optionally image
  /// [context] is used to show error messages if needed
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

    await _launchWhatsApp(message, context);
  }

  /// Share a service via WhatsApp
  ///
  /// [serviceData] should contain: title, price, description, duration, and optionally imageUrl, id
  /// [context] is used to show error messages if needed
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

    await _launchWhatsApp(message, context);
  }

  /// Launch WhatsApp with the given message
  static Future<void> _launchWhatsApp(
    String message,
    BuildContext context,
  ) async {
    final String encodedMessage = Uri.encodeComponent(message);

    // Try WhatsApp Business first, then WhatsApp, then web fallback
    final List<Uri> urls = [
      Uri.parse('whatsapp-business://send?text=$encodedMessage'),
      Uri.parse('whatsapp://send?text=$encodedMessage'),
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
