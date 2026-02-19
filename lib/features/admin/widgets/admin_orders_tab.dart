import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/orders/widgets/admin_order_card.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';

class AdminOrdersTab extends ConsumerStatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  ConsumerState<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends ConsumerState<AdminOrdersTab> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteOrder(String docId, AppLocalizations l10n) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deleteSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado':
      case 'completado':
      case 'completed':
        return Colors.green;
      case 'pendiente':
      case 'pending':
        return Colors.orange;
      case 'procesando':
      case 'confirmado':
      case 'processing':
      case 'confirmed':
        return Colors.blue;
      case 'cancelado':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) =>
                ref.read(adminOrdersQueryProvider.notifier).state = value,
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: ordersAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(child: Text(l10n.noMatchesFound));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return AdminOrderCard(
                      doc: doc,
                      onDelete: () => _deleteOrder(doc.id, l10n),
                      statusColorCallback: getStatusColor,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('${l10n.errorPrefix}: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
