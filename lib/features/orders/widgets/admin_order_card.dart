import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:techsc/core/services/notification_service.dart';
import 'package:techsc/features/orders/utils/supplier_order_helper.dart';

/// Tarjeta expandible que muestra los detalles de un pedido en el panel de administración.
///
/// Incluye: info del cliente, link de pago, control de pagos y descuentos,
/// estado del pedido, lista de productos con costos, y gestión de proveedores.
class AdminOrderCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final VoidCallback onDelete;
  final Color Function(String) statusColorCallback;

  const AdminOrderCard({
    super.key,
    required this.doc,
    required this.onDelete,
    required this.statusColorCallback,
  });

  @override
  State<AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<AdminOrderCard> {
  late TextEditingController _paymentLinkController;
  late TextEditingController _institutionController;
  late TextEditingController _voucherController;
  late TextEditingController _discountController;
  bool _isSavingLink = false;

  // Payment Control State
  String _paymentMethod = 'efectivo';
  bool _isPaid = false;

  // Product cache for supplier info
  final Map<String, Map<String, dynamic>?> _productCache = {};
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🆕 OrderCard initState for order: ${widget.doc.id}');
    final data = widget.doc.data() as Map<String, dynamic>;
    _paymentLinkController = TextEditingController(
      text: data['paymentLink'] ?? '',
    );
    _institutionController = TextEditingController(
      text: data['financialInstitution'] ?? '',
    );
    _voucherController = TextEditingController(
      text: data['paymentVoucher'] ?? '',
    );
    _discountController = TextEditingController(
      text: (data['discountPercentage'] ?? 0.0).toString(),
    );
    _paymentMethod = data['paymentMethod'] ?? 'efectivo';
    _isPaid = data['isPaid'] ?? false;
    _fetchProductDetails();
  }

  @override
  void dispose() {
    _paymentLinkController.dispose();
    _institutionController.dispose();
    _voucherController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(String name, String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 9 && cleanPhone.startsWith('9')) {
      cleanPhone = '593$cleanPhone';
    } else if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      cleanPhone = '593${cleanPhone.substring(1)}';
    }

    final message = Uri.encodeComponent(
      'Hola $name, le escribo respecto a su pedido #${widget.doc.id.substring(0, 5).toUpperCase()}...',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error WhatsApp: $e')));
      }
    }
  }

  Future<void> _savePaymentLink() async {
    setState(() => _isSavingLink = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({'paymentLink': _paymentLinkController.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Link de pago guardado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingLink = false);
    }
  }

  Future<void> _savePaymentDetails() async {
    try {
      final discount = double.tryParse(_discountController.text) ?? 0.0;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({
            'paymentMethod': _paymentMethod,
            'financialInstitution': _institutionController.text.trim(),
            'paymentVoucher': _voucherController.text.trim(),
            'isPaid': _isPaid,
            'discountPercentage': discount,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Detalles de pago actualizados')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar pago: $e')));
      }
    }
  }

  Future<void> _fetchProductDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingProducts = true);

    final data = widget.doc.data() as Map<String, dynamic>;
    final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
    final items =
        (data['items'] as List<dynamic>?) ??
        (originalQuote?['items'] as List<dynamic>?) ??
        [];

    debugPrint('🔍 Fetching product details for ${items.length} items');

    for (var item in items) {
      final productId = item['id'];
      debugPrint('  - Item: ${item['name']}, ID: $productId');

      if (productId != null && !_productCache.containsKey(productId)) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .get();
          if (doc.exists) {
            final productData = doc.data();
            _productCache[productId] = productData;
            debugPrint(
              '    ✅ Product loaded: supplierId=${productData?['supplierId']}, supplierName=${productData?['supplierName']}',
            );
          } else {
            _productCache[productId] = null;
            debugPrint('    ❌ Product not found in Firestore');
          }
        } catch (e) {
          debugPrint('    ⚠️ Error fetching product $productId: $e');
        }
      } else if (productId == null) {
        debugPrint('    ⚠️ Item has no product ID');
      } else {
        debugPrint('    ℹ️ Product already in cache');
      }
    }

    if (mounted) {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _updateItemCost(int index, double newCost) async {
    try {
      final data = widget.doc.data() as Map<String, dynamic>;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      final items = List<Map<String, dynamic>>.from(
        ((data['items'] as List<dynamic>?) ??
                (originalQuote?['items'] as List<dynamic>?) ??
                [])
            .map((x) => Map<String, dynamic>.from(x as Map)),
      );

      items[index]['purchaseCost'] = newCost;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({'items': items});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Costo actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCostDialog(int index, double currentCost) {
    final controller = TextEditingController(
      text: currentCost > 0 ? currentCost.toString() : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Costo de Compra'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor (\$)',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                _updateItemCost(index, val);
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSupplierOrder(
    String supplierId,
    String supplierName,
    List<Map<String, dynamic>> products,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierId)
          .get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proveedor no encontrado')),
          );
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final phone = data['contactPhone'] as String?;

      if (phone == null || phone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proveedor sin teléfono registrado')),
          );
        }
        return;
      }

      if (mounted) {
        SupplierOrderHelper.sendSupplierOrder(
          items: products,
          supplierPhone: phone,
          supplierName: supplierName,
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildSupplierActions(List<dynamic> items) {
    final Map<String, List<Map<String, dynamic>>> supplierItems = {};
    final Map<String, String> supplierNames = {};

    // Get order status to determine if locked
    final data = widget.doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pendiente';
    final bool isLocked = status.toLowerCase() == 'entregado';

    debugPrint(
      '🏪 [${widget.doc.id}] Building supplier actions for ${items.length} items',
    );
    debugPrint(
      '   [${widget.doc.id}] Product cache has ${_productCache.length} entries: ${_productCache.keys.toList()}',
    );

    for (var item in items) {
      final pid = item['id'];
      debugPrint('  - Checking item: ${item['name']}, productId: $pid');

      final product = _productCache[pid];
      if (product == null) {
        debugPrint('    ⚠️ Product not in cache');
        continue;
      }

      debugPrint('    Product data keys: ${product.keys.toList()}');
      debugPrint(
        '    supplierId: ${product['supplierId']}, supplierName: ${product['supplierName']}',
      );

      if (product.containsKey('supplierId')) {
        final sid = product['supplierId'] as String?;
        if (sid != null && sid.isNotEmpty) {
          if (!supplierItems.containsKey(sid)) {
            supplierItems[sid] = [];
            supplierNames[sid] =
                (product['supplierName'] as String?) ?? 'Proveedor';
            debugPrint('    ✅ Added supplier: $sid - ${supplierNames[sid]}');
          }
          supplierItems[sid]!.add({
            'name': item['name'],
            'quantity': item['quantity'],
          });
        } else {
          debugPrint('    ⚠️ supplierId is null or empty');
        }
      } else {
        debugPrint('    ⚠️ Product does not have supplierId field');
      }
    }

    debugPrint('📊 Final supplier groups: ${supplierItems.length}');

    if (supplierItems.isEmpty) {
      // Count items without IDs
      final itemsWithoutId = items
          .where((item) => item['id'] == null || item['id'] == '')
          .length;

      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No hay proveedores vinculados a estos productos.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (itemsWithoutId > 0) ...[
              const SizedBox(height: 4),
              Text(
                '⚠️ $itemsWithoutId producto(s) sin ID. Estos pedidos antiguos no tienen la información necesaria.',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: supplierItems.entries.map((entry) {
        final supplierId = entry.key;
        final name = supplierNames[supplierId]!;
        final products = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLocked
                  ? null
                  : () => _handleSupplierOrder(supplierId, name, products),
              icon: const Icon(Icons.chat, size: 18),
              label: Text('Pedir a $name (${products.length} productos)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isLocked ? Colors.grey : Colors.green[700],
                side: BorderSide(
                  color: isLocked ? Colors.grey[300]! : Colors.green[200]!,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Get data from originalQuote
    final originalQuote = data['originalQuote'] as Map<String, dynamic>?;

    // Robustly get items
    final items =
        (data['items'] as List<dynamic>?) ??
        (originalQuote?['items'] as List<dynamic>?) ??
        [];

    // Robustly get total
    double total = 0.0;
    double subtotal = 0.0;
    final discountPercentage =
        (data['discountPercentage'] as num?)?.toDouble() ??
        (originalQuote?['discountPercentage'] as num?)?.toDouble() ??
        0.0;

    for (var item in items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      subtotal += price * qty;
    }

    final discountAmount = subtotal * (discountPercentage / 100);
    final taxableAmount = subtotal - discountAmount;

    if (data['total'] != null && discountPercentage == 0) {
      total = (data['total'] as num).toDouble();
    } else {
      total = taxableAmount;
      // Apply tax if applicable in originalQuote
      if (originalQuote?['applyTax'] == true) {
        final taxRate = (originalQuote?['taxRate'] as num?)?.toDouble() ?? 0.15;
        total += taxableAmount * taxRate;
      }
    }

    final clientName = originalQuote?['clientName'] ?? 'Cliente Desconocido';

    final status = data['status'] ?? 'pendiente';
    final userId = data['userId'];

    // 🔒 Define si el pedido está bloqueado para edición (solo si está 'entregado')
    final bool isLocked = status.toLowerCase() == 'entregado';
    debugPrint(
      '📦 [${widget.doc.id}] Order status: $status, isLocked: $isLocked',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Si está bloqueado, aplicamos un color de fondo sutilmente diferente o borde
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLocked
            ? BorderSide(color: Colors.green.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: widget.statusColorCallback(status),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text(
          'Pedido #${widget.doc.id.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${date.day}/${date.month}/${date.year} - \$${total.toStringAsFixed(2)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Name from Quote
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      clientName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(),

                // 📝 Banner de Pedido Bloqueado (Seguridad y Resguardo de Datos)
                if (isLocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pedido Entregado - Bloqueado',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Por seguridad, este pedido ya no puede ser editado.',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Info Cliente
                if (userId != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final userName = userData?['name'] ?? 'Desconocido';
                      final userPhone = userData?['phone'] ?? '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              if (userPhone.isNotEmpty)
                                InkWell(
                                  onTap: () =>
                                      _launchWhatsApp(userName, userPhone),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: SvgPicture.network(
                                      'https://static.whatsapp.net/rsrc.php/yZ/r/JvsnINJ2CZv.svg',
                                      width: 24,
                                      height: 24,
                                      placeholderBuilder: (_) => const Icon(
                                        Icons.phone,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                userPhone,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const Divider(),
                        ],
                      );
                    },
                  ),

                // Link de Pago
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paymentLinkController,
                        readOnly: isLocked,
                        decoration: InputDecoration(
                          labelText: 'Link de Pago',
                          hintText: 'https://...',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                          fillColor: isLocked ? Colors.grey.shade100 : null,
                          filled: isLocked,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSavingLink
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: isLocked ? null : _savePaymentLink,
                            icon: Icon(
                              Icons.save,
                              color: isLocked ? Colors.grey : Colors.blue,
                            ),
                            tooltip: 'Guardar Link',
                          ),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Control Section
                const Text(
                  'Control de Pagos y Descuentos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        readOnly: isLocked,
                        decoration: InputDecoration(
                          labelText: 'Descuento (%)',
                          hintText: 'Ej: 5',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.percent),
                          fillColor: isLocked ? Colors.grey.shade100 : null,
                          filled: isLocked,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isLocked ? null : _savePaymentDetails,
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Pago Realizado:'),
                    Switch(
                      value: _isPaid,
                      onChanged: isLocked
                          ? null
                          : (val) {
                              setState(() => _isPaid = val);
                              _savePaymentDetails();
                            },
                      activeThumbColor: Colors.green,
                    ),
                  ],
                ),
                // Metodo de pago opciones
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Método de Pago',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payment),
                    fillColor: isLocked ? Colors.grey.shade100 : null,
                    filled: isLocked,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                  ],
                  onChanged: isLocked
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _paymentMethod = val);
                            _savePaymentDetails();
                          }
                        },
                ),
                if (_paymentMethod == 'transferencia') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _institutionController,
                    readOnly: isLocked,
                    decoration: InputDecoration(
                      labelText: 'Institución Financiera',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.account_balance),
                      fillColor: isLocked ? Colors.grey.shade100 : null,
                      filled: isLocked,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _voucherController,
                    readOnly: isLocked,
                    decoration: InputDecoration(
                      labelText: 'Número de Comprobante/Voucher',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.receipt),
                      fillColor: isLocked ? Colors.grey.shade100 : null,
                      filled: isLocked,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: isLocked ? null : _savePaymentDetails,
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('Guardar Detalles Transferencia'),
                    ),
                  ),
                ],
                const Divider(),

                // Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estado:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value:
                          [
                            'pendiente',
                            'confirmado',
                            'entregado',
                            'cancelado',
                          ].contains(status)
                          ? status
                          : 'pendiente',
                      items:
                          ['pendiente', 'confirmado', 'entregado', 'cancelado']
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.toUpperCase(),
                                    style: TextStyle(
                                      color: widget.statusColorCallback(s),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: isLocked
                          ? null
                          : (newStatus) async {
                              if (newStatus != null) {
                                await FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(widget.doc.id)
                                    .update({'status': newStatus});

                                // Notificar cambio de estado
                                if (userId != null) {
                                  NotificationService()
                                      .notifyOrderStatusChanged(
                                        widget.doc.id,
                                        userId,
                                        newStatus,
                                      );
                                }
                              }
                            },
                    ),
                  ],
                ),
                const Divider(),
                const Text(
                  'Productos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final cost =
                      (item['purchaseCost'] as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['quantity']}x ${item['name']}',
                              ),
                            ),
                            Text(
                              '\$${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        if (!isLocked)
                          InkWell(
                            onTap: () => _showCostDialog(index, cost),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 4.0,
                                left: 16,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cost > 0
                                        ? 'Costo: \$${cost.toStringAsFixed(2)}'
                                        : 'Agregar costo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cost > 0
                                          ? Colors.green[700]
                                          : Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                // Debug: Log supplier section visibility
                Builder(
                  builder: (context) {
                    debugPrint(
                      '🔍 [${widget.doc.id}] Supplier section check: isLocked=$isLocked, _isLoadingProducts=$_isLoadingProducts, cacheSize=${_productCache.length}',
                    );
                    return const SizedBox.shrink();
                  },
                ),

                // Supplier Actions Section
                if (!_isLoadingProducts) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    children: [
                      const Text(
                        'Gestión de Proveedores',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      if (isLocked) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.lock, size: 14, color: Colors.grey),
                        const Text(
                          ' (Solo lectura)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSupplierActions(items),
                ],

                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isLocked ? null : widget.onDelete,
                    icon: Icon(
                      Icons.delete,
                      color: isLocked ? Colors.grey : Colors.red,
                    ),
                    label: Text(
                      'Eliminar Pedido',
                      style: TextStyle(
                        color: isLocked ? Colors.grey : Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
