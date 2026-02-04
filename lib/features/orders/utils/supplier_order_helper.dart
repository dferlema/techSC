import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/core/utils/branding_helper.dart';

class SupplierOrderHelper {
  /// Sends a consolidated order message to a supplier for multiple items.
  static Future<void> sendSupplierOrder({
    required List<Map<String, dynamic>> items,
    required String supplierPhone,
    required String supplierName,
    required BuildContext context,
  }) async {
    // 1. Clean phone number
    String cleanPhone = supplierPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      cleanPhone = '593${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 9) {
      cleanPhone = '593$cleanPhone';
    }

    final String firstName = supplierName.split(' ').first;

    // 2. Build Message
    String message =
        '👋 Buen día $firstName, le escribo de *${BrandingHelper.appName}*.\n';
    message += 'Quisiera realizar el siguiente pedido:\n\n';

    for (var item in items) {
      final name = item['name'] ?? 'Producto';
      final qty = item['quantity'] ?? 1;
      message += '📦 *$name* (x$qty)\n';
    }

    message += '\nPor favor, ¿me confirma disponibilidad y precios actuales?\n';
    message += '¡Muchas gracias!';

    // 3. Launch WhatsApp
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/$cleanPhone?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      debugPrint('Error launching supplier order: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al contactar proveedor: $e')),
        );
      }
    }
  }
}
