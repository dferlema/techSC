import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/features/inventory/providers/inventory_providers.dart';
import 'package:tscomputer/features/inventory/models/inventory_movement_model.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'package:tscomputer/core/widgets/app_error_widget.dart';
import 'package:tscomputer/features/catalog/services/supplier_service.dart';
import 'package:tscomputer/features/catalog/models/supplier_model.dart';

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
  final _unitCostController = TextEditingController();
  final _reasonController = TextEditingController();
  final _documentNumberController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _reasonController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  void _showMovementDialog(MovementType type) {
    _quantityController.clear();
    _unitCostController.clear();
    _reasonController.clear();
    _documentNumberController.clear();

    String title = type == MovementType.inward
        ? 'Registrar Entrada'
        : (type == MovementType.outward
              ? 'Registrar Salida/Merma'
              : 'Ajustar Inventario');

    if (type != MovementType.inward) {
      // Diálogo simple para salida/ajuste
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
                  if (qty == null ||
                      (qty <= 0 && type != MovementType.adjust)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cantidad inválida')),
                    );
                    return;
                  }
                  final user = ref.read(authStateProvider).value;
                  if (user == null) return;
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(inventoryServiceProvider)
                        .registerMovement(
                          productId: widget.productId,
                          type: type,
                          quantity: type == MovementType.adjust
                              ? qty
                              : qty.abs(),
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
      return;
    }

    // Diálogo completo para entrada con datos de compra
    String docType = 'Factura';
    double vatRate = 0.15;
    String supplierSearch = '';
    SupplierModel? selectedSupplier;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cantidad
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Costo Unitario
                      TextField(
                        controller: _unitCostController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Costo Unitario de Compra (\$)',
                          border: OutlineInputBorder(),
                          hintText: '0.00',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tipo de Documento
                      DropdownButtonFormField<String>(
                        initialValue: docType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Documento',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Factura',
                            child: Text('Factura'),
                          ),
                          DropdownMenuItem(
                            value: 'Nota de Venta',
                            child: Text('Nota de Venta'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => docType = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // N° Documento
                      TextField(
                        controller: _documentNumberController,
                        decoration: const InputDecoration(
                          labelText: 'N° Documento',
                          border: OutlineInputBorder(),
                          hintText: '001-001-000000001',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // IVA
                      DropdownButtonFormField<double>(
                        initialValue: vatRate,
                        decoration: const InputDecoration(
                          labelText: 'IVA',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0.15, child: Text('IVA 15%')),
                          DropdownMenuItem(value: 0.0, child: Text('IVA 0%')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => vatRate = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Buscar Proveedor
                      TextField(
                        decoration: InputDecoration(
                          labelText: selectedSupplier != null
                              ? 'Proveedor seleccionado'
                              : 'Buscar Proveedor',
                          border: const OutlineInputBorder(),
                          suffixIcon: selectedSupplier != null
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setDialogState(() {
                                    selectedSupplier = null;
                                    supplierSearch = '';
                                  }),
                                )
                              : const Icon(Icons.search),
                        ),
                        onChanged: (v) => setDialogState(
                          () => supplierSearch = v.toLowerCase(),
                        ),
                      ),
                      if (selectedSupplier != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            selectedSupplier!.name,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (selectedSupplier == null) ...[
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 100,
                          child: StreamBuilder<List<SupplierModel>>(
                            stream: SupplierService().getSuppliers(),
                            builder: (context, snap) {
                              if (!snap.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              final suppliers = snap.data!;
                              final filtered = supplierSearch.isEmpty
                                  ? suppliers
                                  : suppliers
                                        .where(
                                          (s) => s.name.toLowerCase().contains(
                                            supplierSearch,
                                          ),
                                        )
                                        .toList();
                              if (filtered.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }
                              return ListView(
                                children: filtered
                                    .map(
                                      (s) => ListTile(
                                        dense: true,
                                        title: Text(
                                          s.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        subtitle: s.contactName.isNotEmpty
                                            ? Text(
                                                s.contactName,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              )
                                            : null,
                                        trailing: const Icon(
                                          Icons.add_circle,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        onTap: () => setDialogState(
                                          () => selectedSupplier = s,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Motivo
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo u Observación',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final qtyStr = _quantityController.text;
                                final reason = _reasonController.text;
                                final costStr = _unitCostController.text;
                                final docNum = _documentNumberController.text
                                    .trim();

                                if (qtyStr.isEmpty || reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cantidad y motivo son requeridos',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final qty = int.tryParse(qtyStr);
                                if (qty == null || qty <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cantidad inválida'),
                                    ),
                                  );
                                  return;
                                }
                                final double? unitCost = double.tryParse(
                                  costStr,
                                );
                                if (unitCost == null || unitCost <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Debe ingresar un costo unitario válido',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (docNum.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Debe ingresar el número de documento',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final user = ref.read(authStateProvider).value;
                                if (user == null) return;

                                Navigator.pop(context);

                                try {
                                  await ref
                                      .read(inventoryServiceProvider)
                                      .registerMovement(
                                        productId: widget.productId,
                                        type: MovementType.inward,
                                        quantity: qty,
                                        reason: reason,
                                        userId: user.uid,
                                        unitCost: unitCost,
                                        supplierId: selectedSupplier?.id,
                                        supplierName: selectedSupplier?.name,
                                        documentType: docType,
                                        documentNumber: docNum,
                                        vatRate: vatRate,
                                      );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Entrada registrada correctamente',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: const Text('Guardar Entrada'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
