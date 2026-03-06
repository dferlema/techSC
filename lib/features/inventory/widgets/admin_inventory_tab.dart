import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/inventory/providers/inventory_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:techsc/features/inventory/screens/inventory_product_detail_page.dart';
import 'package:techsc/features/inventory/screens/inventory_reports_page.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';

class AdminInventoryTab extends ConsumerWidget {
  const AdminInventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(adminInventoryProductsProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar en inventario...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                ref.read(adminInventoryQueryProvider.notifier).state = value,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InventoryReportsPage(),
              ),
            ),
            icon: const Icon(Icons.analytics),
            label: const Text('Inteligencia de Inventario'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: productsAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (err, _) => AppErrorWidget(error: err),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(child: Text(l10n.noMatchesFound));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>? ?? {};
                    final stock = (data['stock'] as num?)?.toInt() ?? 0;

                    Color stockColor = Colors.green;
                    if (stock == 0) {
                      stockColor = Colors.red;
                    } else if (stock < 5)
                      stockColor = Colors.orange;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            data['image'] ??
                                data['imageUrl'] ??
                                'https://via.placeholder.com/50x50?text=P',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.inventory_2,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          data['name'] ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Stock: $stock',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InventoryProductDetailPage(
                                productId: docs[index].id,
                                productName: data['name'] ?? '—',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
