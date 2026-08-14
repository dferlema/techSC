import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/purchase_invoice_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/account_mapper.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';
import 'package:tscomputer/features/catalog/providers/product_providers.dart';

/// Diálogo para registrar o editar una factura de compra o gasto.
///
/// Soporta dos tipos:
///  - **Gasto**: categoría + subtotal (sin inventario).
///  - **Inventario**: ítems de producto (cantidad y costo unitario).
///
/// El registro es idempotente: genera transacción + asiento + CxP sin duplicar.
/// Si se recibe [invoice], opera en modo edición: precarga los valores y al
/// guardar actualiza la factura y sus artefactos contables.
class PurchaseInvoiceFormDialog extends ConsumerStatefulWidget {
  final PurchaseInvoiceModel? invoice;

  const PurchaseInvoiceFormDialog({super.key, this.invoice});

  bool get isEditing => invoice != null;

  @override
  ConsumerState<PurchaseInvoiceFormDialog> createState() =>
      _PurchaseInvoiceFormDialogState();
}

class _PurchaseInvoiceFormDialogState
    extends ConsumerState<PurchaseInvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController();
  final _supplierIdCtrl = TextEditingController();
  final _documentNumberCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  PurchaseInvoiceType _type = PurchaseInvoiceType.gasto;
  String _documentType = 'Factura';
  String _paymentType = 'credito';
  double _vatRate = 0.15;
  String _category = 'Gasto General';
  String _inventoryAccount = '1.1.03.02';
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  final List<PurchaseInvoiceItem> _items = [];

  final List<String> _documentTypes = ['Factura', 'Nota de Venta', 'Recibo', 'Otro'];
  final List<String> _expenseCategories = [
    'Arriendo',
    'Sueldos',
    'Suministros',
    'Servicios Básicos',
    'Electricidad',
    'Agua',
    'Teléfono/Internet',
    'Combustible',
    'Marketing',
    'Comisiones',
    'Honorarios',
    'Gasto General',
    'Otros',
  ];
  static const List<Map<String, String>> _inventoryAccounts = [
    {'code': '1.1.03.01', 'name': 'Inventario de Equipos'},
    {'code': '1.1.03.02', 'name': 'Inventario de Partes y Piezas'},
    {'code': '1.1.03.03', 'name': 'Inventario de Accesorios'},
    {'code': '1.1.03.04', 'name': 'Inventario de Software y Licencias'},
    {'code': '1.1.03.05', 'name': 'Inventario de Insumos Técnicos'},
  ];

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv != null) {
      _type = inv.type;
      _documentType = inv.documentType;
      _paymentType = inv.paymentType;
      _vatRate = inv.vatRate;
      _category = inv.category;
      _issueDate = inv.issueDate;
      _dueDate = inv.dueDate ?? inv.issueDate.add(const Duration(days: 30));
      _inventoryAccount = inv.type == PurchaseInvoiceType.inventario
          ? inv.accountCode
          : '1.1.03.02';
      _supplierCtrl.text = inv.supplierName;
      _supplierIdCtrl.text = inv.supplierIdentification ?? '';
      _documentNumberCtrl.text = inv.documentNumber;
      if (inv.type == PurchaseInvoiceType.gasto) {
        _subtotalCtrl.text = inv.subtotal.toStringAsFixed(2);
      }
      _notesCtrl.text = inv.notes ?? '';
      _items.addAll(inv.items);
    }
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _supplierIdCtrl.dispose();
    _documentNumberCtrl.dispose();
    _subtotalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _computedSubtotal {
    if (_type == PurchaseInvoiceType.gasto) {
      return double.tryParse(_subtotalCtrl.text) ?? 0.0;
    }
    return _items.fold(0.0, (sum, i) => sum + i.totalCost);
  }

  /// Valores de subtotal/IVA/total correctos:
  /// Al editar, preserva los valores originales de la factura para no
  /// recalcular IVA sobre montos que ya lo incluyen.
  double get _summarySubtotal {
    if (widget.isEditing) return widget.invoice!.subtotal;
    return _computedSubtotal;
  }

  double get _summaryVatAmount {
    if (widget.isEditing) return widget.invoice!.vatAmount;
    return _computedSubtotal * _vatRate;
  }

  double get _summaryTotal {
    if (widget.isEditing) return widget.invoice!.total;
    return _computedSubtotal * (1 + _vatRate);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(filteredProductsProvider(''));
    return AlertDialog(
      title: Text(widget.isEditing
          ? 'Editar Factura de Compra'
          : 'Registrar Factura de Compra'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<PurchaseInvoiceType>(
                  segments: const [
                    ButtonSegment(
                      value: PurchaseInvoiceType.gasto,
                      label: Text('Gasto'),
                      icon: Icon(Icons.receipt_outlined),
                    ),
                    ButtonSegment(
                      value: PurchaseInvoiceType.inventario,
                      label: Text('Inventario'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (val) =>
                      setState(() => _type = val.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _supplierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _supplierIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'RUC / Cédula',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _documentType,
                        decoration: const InputDecoration(
                          labelText: 'Documento',
                          border: OutlineInputBorder(),
                        ),
                        items: _documentTypes
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _documentType = v ?? 'Factura'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _documentNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'N° Documento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _paymentType,
                        decoration: const InputDecoration(
                          labelText: 'Pago',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'contado', child: Text('Contado')),
                          DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                          DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                        ],
                        onChanged: (v) =>
                            setState(() => _paymentType = v ?? 'credito'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(
                          context,
                          (d) => setState(() => _issueDate = d),
                          _issueDate,
                        ),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Emisión',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${_issueDate.day}/${_issueDate.month}/${_issueDate.year}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(
                          context,
                          (d) => setState(() => _dueDate = d),
                          _dueDate,
                        ),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Vence',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.event),
                          ),
                          child: Text(
                            '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: _vatRate,
                  decoration: const InputDecoration(
                    labelText: 'Tasa de IVA',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0.15, child: Text('IVA 15%')),
                    DropdownMenuItem(value: 0.08, child: Text('IVA 8% (Turismo)')),
                    DropdownMenuItem(value: 0.0, child: Text('IVA 0%')),
                  ],
                  onChanged: (v) => setState(() => _vatRate = v ?? 0.15),
                ),
                const SizedBox(height: 12),
                if (_type == PurchaseInvoiceType.gasto) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Categoría de Gasto',
                      border: OutlineInputBorder(),
                    ),
                    items: _expenseCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'Gasto General'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subtotalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subtotal (sin IVA)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (_type != PurchaseInvoiceType.gasto) return null;
                      final val = double.tryParse(v ?? '');
                      return (val == null || val <= 0) ? 'Monto requerido' : null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _inventoryAccount,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta de Inventario',
                      border: OutlineInputBorder(),
                    ),
                    items: _inventoryAccounts
                        .map((a) =>
                            DropdownMenuItem(value: a['code'], child: Text(a['name'] ?? '')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _inventoryAccount = v ?? '1.1.03.02'),
                  ),
                  const SizedBox(height: 12),
                  _buildItemsHeader(context, productsAsync),
                  const SizedBox(height: 8),
                  _buildItemsList(),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryRow('Subtotal', _summarySubtotal),
                      _summaryRow(
                        'IVA (${(_vatRate * 100).toStringAsFixed(0)}%)',
                        _summaryVatAmount,
                      ),
                      const Divider(height: 12),
                      _summaryRow(
                        'Total (IVA capitalizado)',
                        _summaryTotal,
                        isBold: true,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'RIMPE: el IVA de compras se capitaliza al costo y no es acreditable.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_saving
              ? 'Guardando...'
              : widget.isEditing
                  ? 'Guardar Cambios'
                  : 'Registrar'),
        ),
      ],
    );
  }

  Widget _buildItemsHeader(
      BuildContext context, AsyncValue<List<ProductModel>> productsAsync) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Ítems de compra (${_items.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Agregar ítem',
          icon: const Icon(Icons.add),
          color: AppColors.primaryBlue,
          onPressed: productsAsync.hasValue
              ? () => _showAddItemDialog(context, productsAsync.value!)
              : null,
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: const Text(
          'Sin ítems. Toca + para agregar productos.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return Column(
      children: [
        for (final item in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('x${item.quantity} · \$${item.unitCost.toStringAsFixed(2)}/u',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text('\$${item.totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: () => setState(() => _items.remove(item)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showAddItemDialog(BuildContext context, List<ProductModel> products) async {
    final result = await showDialog<_DraftItem>(
      context: context,
      builder: (dialogContext) => _ProductPickerDialog(products: products),
    );
    if (result == null) return;
    setState(() {
      _items.add(PurchaseInvoiceItem(
        productId: result.productId,
        productName: result.productName,
        quantity: result.quantity,
        unitCost: result.unitCost,
        totalCost: result.unitCost * result.quantity,
        inventoryAccountCode: _inventoryAccount,
      ));
    });
  }

  Future<void> _pickDate(
      BuildContext context, void Function(DateTime) onPick, DateTime initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) onPick(picked);
  }

  Widget _summaryRow(String label, double value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == PurchaseInvoiceType.inventario && _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un ítem')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(purchaseInvoiceServiceProvider);
      final subtotal = _computedSubtotal;
      final total = subtotal * (1 + _vatRate);
      String? invoiceId;

      if (widget.isEditing) {
        final original = widget.invoice!;
        final updated = PurchaseInvoiceModel(
          id: original.id,
          supplierName: _supplierCtrl.text.trim(),
          supplierIdentification: _supplierIdCtrl.text.trim().isEmpty
              ? null
              : _supplierIdCtrl.text.trim(),
          supplierPhone: original.supplierPhone,
          documentType: _documentType,
          documentNumber: _documentNumberCtrl.text.trim(),
          issueDate: _issueDate,
          dueDate: _dueDate,
          subtotal: original.subtotal,
          vatAmount: original.vatAmount,
          vatRate: original.vatRate,
          total: original.total,
          paymentType: _paymentType,
          category: _type == PurchaseInvoiceType.gasto
              ? _category
              : 'Compra de Inventario',
          accountCode: _type == PurchaseInvoiceType.gasto
              ? AccountMapper.expenseAccountForCategory(_category)
              : _inventoryAccount,
          type: _type,
          status: _paymentType == 'contado' || _paymentType == 'transferencia'
              ? PurchaseInvoiceStatus.pagada
              : PurchaseInvoiceStatus.pendiente,
          items: _items,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: original.createdAt,
          payableId: original.payableId,
          originType: original.originType,
          originId: original.originId,
        );
        invoiceId = await service.updateInvoice(updated);
      } else if (_type == PurchaseInvoiceType.gasto) {
        invoiceId = await service.registerExpenseInvoice(
          supplierName: _supplierCtrl.text.trim(),
          supplierIdentification: _supplierIdCtrl.text.trim().isEmpty
              ? null
              : _supplierIdCtrl.text.trim(),
          documentType: _documentType,
          documentNumber: _documentNumberCtrl.text.trim(),
          issueDate: _issueDate,
          dueDate: _dueDate,
          subtotal: subtotal,
          vatRate: _vatRate,
          paymentType: _paymentType,
          category: _category,
          accountCode: AccountMapper.expenseAccountForCategory(_category),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        invoiceId = await service.registerInventoryInvoice(
          supplierName: _supplierCtrl.text.trim(),
          supplierIdentification: _supplierIdCtrl.text.trim().isEmpty
              ? null
              : _supplierIdCtrl.text.trim(),
          documentType: _documentType,
          documentNumber: _documentNumberCtrl.text.trim(),
          issueDate: _issueDate,
          dueDate: _dueDate,
          subtotal: subtotal,
          vatRate: _vatRate,
          total: total,
          paymentType: _paymentType,
          inventoryAccountCode: _inventoryAccount,
          items: _items,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      if (invoiceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEditing
              ? 'No se pudo actualizar la factura'
              : 'No se pudo registrar la factura')),
        );
        return;
      }
      Navigator.pop(context, invoiceId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Ítem pendiente de confirmación en el selector de productos.
class _DraftItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitCost;

  const _DraftItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });
}

/// Diálogo para buscar y seleccionar un producto de forma visual.
///
/// Presenta un campo de búsqueda y una grilla de tarjetas con la imagen,
/// stock y costo de cada producto. Al seleccionar uno se configuran la
/// cantidad y el costo unitario antes de confirmar.
class _ProductPickerDialog extends StatefulWidget {
  final List<ProductModel> products;

  const _ProductPickerDialog({required this.products});

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  ProductModel? _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(_syncCostPreview);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  List<ProductModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          (p.categoryId.isNotEmpty && p.categoryId.toLowerCase().contains(q));
    }).toList();
  }

  void _syncCostPreview() {
    setState(() {});
  }

  void _select(ProductModel p) {
    setState(() {
      _selected = p;
      final cost = p.purchaseCost ?? p.purchaseCostWithTax ?? 0.0;
      _costCtrl.text = cost > 0 ? cost.toStringAsFixed(2) : '';
      _qtyCtrl.text = '1';
    });
  }

  double get _previewCost {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text) ?? 0.0;
    return qty * cost;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 520,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Buscar producto por nombre, descripción...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_selected == null)
              Expanded(child: _buildGrid())
            else
              Expanded(child: _buildSelectedDetail()),
            const Divider(height: 1),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agregar producto',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('Selecciona un producto para la factura',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Sin resultados', style: TextStyle(fontSize: 15, color: Colors.grey)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildProductCard(filtered[index]),
    );
  }

  Widget _buildProductCard(ProductModel p) {
    final hasImage = p.imageUrl != null && p.imageUrl!.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _select(p),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: p.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.inventory_2_outlined,
                                size: 32, color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          width: double.infinity,
                          child: Icon(Icons.inventory_2_outlined,
                              size: 32, color: Colors.grey[400]),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: p.stock > 0
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stock: ${p.stock}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: p.stock > 0 ? Colors.green[800] : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                (p.purchaseCost ?? p.purchaseCostWithTax ?? 0) > 0
                    ? '\$${(p.purchaseCost ?? p.purchaseCostWithTax ?? 0).toStringAsFixed(2)}/u'
                    : 'Sin costo',
                style: TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDetail() {
    final p = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: p.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey[100],
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey[100],
                            child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey[100],
                          child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400]),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Stock disponible: ${p.stock}',
                          style: TextStyle(fontSize: 12, color: p.stock > 0 ? Colors.green[800] : Colors.red[700])),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selected = null;
                    _costCtrl.clear();
                    _qtyCtrl.text = '1';
                  }),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  onChanged: (_) => _syncCostPreview(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  onChanged: (_) => _syncCostPreview(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario (con IVA)',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal ítem', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '\$${_previewCost.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          if (_selected != null)
            Expanded(
              child: Text(
                '${_qtyCtrl.text.isEmpty ? '0' : _qtyCtrl.text} × \$${_costCtrl.text.isEmpty ? '0.00' : _costCtrl.text}/u',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          if (_selected != null) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _selected == null ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Agregar a la factura'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final p = _selected;
    if (p == null) return;
    final qty = int.tryParse(_qtyCtrl.text);
    final cost = double.tryParse(_costCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad inválida')),
      );
      return;
    }
    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Costo unitario inválido')),
      );
      return;
    }
    Navigator.pop(
      context,
      _DraftItem(
        productId: p.id,
        productName: p.name,
        quantity: qty,
        unitCost: cost,
      ),
    );
  }
}
