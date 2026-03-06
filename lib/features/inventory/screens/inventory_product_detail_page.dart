import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/inventory/providers/inventory_providers.dart';
import 'package:techsc/features/inventory/models/inventory_movement_model.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';

class InventoryProductDetailPage extends ConsumerStatefulWidget {
  final String productId;
  final String productName;

  const InventoryProductDetailPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<InventoryProductDetailPage> createState() =>
      _InventoryProductDetailPageState();
}

class _InventoryProductDetailPageState
    extends ConsumerState<InventoryProductDetailPage> {
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _showMovementDialog(MovementType type) {
    _quantityController.clear();
    _reasonController.clear();

    String title = type == MovementType.inward
        ? 'Registrar Entrada'
        : (type == MovementType.outward
              ? 'Registrar Salida/Merma'
              : 'Ajustar Inventario');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo u Observación',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qtyStr = _quantityController.text;
                final reason = _reasonController.text;
                if (qtyStr.isEmpty || reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor llena todos los campos'),
                    ),
                  );
                  return;
                }

                final qty = int.tryParse(qtyStr);
                if (qty == null || (qty <= 0 && type != MovementType.adjust)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cantidad inválida')),
                  );
                  return;
                }

                final user = ref.read(authStateProvider).value;
                if (user == null) return;

                Navigator.pop(context); // close dialog

                try {
                  await ref
                      .read(inventoryServiceProvider)
                      .registerMovement(
                        productId: widget.productId,
                        type: type,
                        quantity: type == MovementType.adjust ? qty : qty.abs(),
                        reason: reason,
                        userId: user.uid,
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Movimiento registrado correctamente'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(
      productMovementsProvider(widget.productId),
    );
    // Provide a stream for the product itself to ensure currentStock is live
    final productDocStream = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.productName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: productDocStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final data =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final currentStock = (data['stock'] as num?)?.toInt() ?? 0;

                return Card(
                  elevation: 4,
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text(
                          'Stock Actual',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.blueGrey,
                          ),
                        ),
                        Text(
                          '$currentStock',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showMovementDialog(MovementType.inward),
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                  label: const Text('Entrada'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showMovementDialog(MovementType.outward),
                  icon: const Icon(Icons.remove_circle, color: Colors.white),
                  label: const Text('Salida'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Historial de Movimientos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: movementsAsync.when(
                loading: () => const AppLoadingIndicator(),
                error: (err, _) => AppErrorWidget(error: err),
                data: (movements) {
                  if (movements.isEmpty) {
                    return const Center(
                      child: Text('No hay movimientos registrados.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: movements.length,
                    itemBuilder: (context, index) {
                      final m = movements[index];
                      final isInput = m.type == MovementType.inward;
                      final isAdjust = m.type == MovementType.adjust;

                      Color iconColor = isInput
                          ? Colors.green
                          : (isAdjust ? Colors.orange : Colors.red);
                      IconData iconData = isInput
                          ? Icons.arrow_downward
                          : (isAdjust ? Icons.swap_horiz : Icons.arrow_upward);
                      String symbol = isInput
                          ? '+'
                          : (isAdjust ? (m.quantity >= 0 ? '+' : '') : '-');

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withAlpha(51),
                          child: Icon(iconData, color: iconColor),
                        ),
                        title: Text(
                          '${m.reason} ($symbol${m.quantity})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(m.date)}\nStock result: ${m.newStock}',
                        ),
                        isThreeLine: true,
                        trailing: IgnorePointer(
                          child: IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
