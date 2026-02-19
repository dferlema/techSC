import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/orders/providers/order_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/features/orders/widgets/client_order_card.dart';

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  Future<void> _launchPaymentLink(
    BuildContext context,
    String urlString,
  ) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el link de pago')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Pedido')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ClientOrderCard(
              docId: order.id,
              data: order.toMap(),
              onPay: (link) => _launchPaymentLink(context, link),
            ),
          );
        },
      ),
    );
  }
}
