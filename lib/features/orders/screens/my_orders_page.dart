import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/orders/providers/order_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/features/orders/widgets/client_order_card.dart';

class MyOrdersPage extends ConsumerWidget {
  const MyOrdersPage({super.key});

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
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Pedidos')),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tus pedidos.'),
        ),
      );
    }

    final ordersAsync = ref.watch(userOrdersProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/main');
            }
          },
        ),
        title: const Text('Mis Pedidos'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[50],
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (orders) {
            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No has realizado ningún pedido aún.',
                      style: TextStyle(fontSize: 18, color: Color(0xFF757575)),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final order = orders[index];
                return ClientOrderCard(
                  docId: order.id,
                  data: order.toMap(),
                  onPay: (link) => _launchPaymentLink(context, link),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
