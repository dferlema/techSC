import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/core/utils/branding_helper.dart';

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
    message += '📱 Compartido desde ${BrandingHelper.appName}';

    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _shareWithImage(message, imageUrl, context, subject: productName);
    } else {
      await _launchWhatsApp(message, context);
    }
  }

  /// Sends a direct marketing message to a specific phone number via WhatsApp
  ///
  /// [productData] contains the product details
  /// [phone] is the client's phone number
  static Future<void> sendMarketingMessage({
    required Map<String, dynamic> productData,
    required String phone,
    required BuildContext context,
    String? clientName,
  }) async {
    // Limpiar el número de teléfono (solo números)
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      // Asumiendo Ecuador si empieza con 0 y tiene 10 dígitos
      cleanPhone = '593${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 9) {
      // Asumiendo Ecuador si tiene 9 dígitos
      cleanPhone = '593$cleanPhone';
    }

    final String message = generateMarketingMessage(
      productData,
      clientName: clientName,
    );

    final String encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/$cleanPhone?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp para $cleanPhone';
      }
    } catch (e) {
      debugPrint('Error launching marketing message: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error al enviar a $phone: $e');
      }
    }
  }

  /// Generates the marketing message text formatted for WhatsApp
  static String generateMarketingMessage(
    Map<String, dynamic> productData, {
    String? clientName,
  }) {
    final String productName = productData['name'] ?? 'Producto';
    final double price =
        double.tryParse(productData['price']?.toString() ?? '0') ?? 0;
    final String description = productData['description'] ?? '';
    final String name = clientName ?? 'amigo/a';

    // Calculate a "strikethrough" original price (25% more)
    final String originalPrice = (price * 1.25).toStringAsFixed(2);
    final String promoPrice = price.toStringAsFixed(2);

    // Determine dynamic product type for the message
    String productType = 'producto';
    final String lowerName = productName.toLowerCase();
    final String category = (productData['category'] ?? '')
        .toString()
        .toLowerCase();

    if (lowerName.contains('laptop') ||
        lowerName.contains('portátil') ||
        lowerName.contains('notebook') ||
        category.contains('laptop')) {
      productType = 'laptop';
    } else if (lowerName.contains('impresora') ||
        lowerName.contains('printer') ||
        category.contains('impresora')) {
      productType = 'impresora';
    } else if (category.contains('servicio') ||
        lowerName.contains('mantenimiento') ||
        lowerName.contains('reparación')) {
      productType = 'servicio';
    }

    // Format a high-impact marketing message based on user request
    String message = '👋 Hola *$name*, tenemos algo especial para ti\n';
    message +=
        'Entre todos nuestros clientes, seleccionamos a algunos para ofertas únicas. Hoy es tu turno.\n\n';

    message += '✨ *$productName*\n';
    message += 'Precio exclusivo para ti: *$promoPrice* ~$originalPrice~\n\n';

    // Try to extract specs into bullet points
    if (productData['specs'] != null) {
      String specs = productData['specs'].toString();
      // Simple split if it looks like a list or just use it
      if (specs.contains(',')) {
        specs.split(',').take(4).forEach((spec) {
          message += '💎 ${spec.trim()}\n';
        });
      } else {
        message += '💎 $specs\n';
      }
    } else if (description.isNotEmpty) {
      message +=
          '💎 _${description.length > 80 ? '${description.substring(0, 77)}...' : description}_\n';
    }

    message += '\n';
    message += '⏰ *Esta oferta expira en 6 horas*\n\n';

    message +=
        '*$name*, guardamos esta oportunidad especialmente para ti. Pero el cupo es limitado y el tiempo corre.\n\n';

    message += '👉 *Sí, quiero aprovechar mi oferta*\n';

    message +=
        'P.D. Solo 3 personas recibirán este precio hoy. Tú eres una de ellas.\n\n';

    message += '🏢 *${BrandingHelper.appName}*';

    return message;
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
    message += '📱 Compartido desde ${BrandingHelper.appName}';

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

  /// Sends an order message to a supplier via WhatsApp
  static Future<void> sendSupplierOrder({
    required Map<String, dynamic> productData,
    required String supplierPhone,
    required String supplierContactName,
    required BuildContext context,
  }) async {
    // Limpiar el número de teléfono
    String cleanPhone = supplierPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      cleanPhone = '593${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 9) {
      cleanPhone = '593$cleanPhone';
    }

    // Extraer solo el primer nombre del contacto
    final String firstName = supplierContactName.split(' ').first;

    // Obtener nombre del producto
    final String productName = productData['name'] ?? 'Producto';

    // Generar mensaje con el formato solicitado
    // "Buen día [Nombre], le escribo de [Nombre de la empresa]. Quisiera realizar un pedido de: [Producto]. Por favor, ¿me confirma disponibilidad y precio?"
    final String message =
        'Buen día $firstName, le escribo de ${BrandingHelper.appName}. '
        'Quisiera realizar un pedido de: *$productName*. '
        'Por favor, ¿me confirma disponibilidad y precio?';

    final String encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/$cleanPhone?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp para $cleanPhone';
      }
    } catch (e) {
      debugPrint('Error launching supplier order: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error al contactar proveedor: $e');
      }
    }
  }
}
