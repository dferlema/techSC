import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/purchase_invoice_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/purchase_invoice_form_dialog.dart';

/// Detalle de una factura de compra o gasto.
///
/// Muestra toda la información del documento. Permite editar la factura
/// únicamente a los roles Administrador y Contabilidad (usuario autenticado).
/// Se mantiene sincronizado con [purchaseInvoicesStreamProvider], por lo que
/// refleja los cambios hechos en el formulario de edición.
class PurchaseInvoiceDetailPage extends ConsumerStatefulWidget {
  final PurchaseInvoiceModel invoice;

  const PurchaseInvoiceDetailPage({super.key, required this.invoice});

  @override
  ConsumerState<PurchaseInvoiceDetailPage> createState() =>
      _PurchaseInvoiceDetailPageState();
}

class _PurchaseInvoiceDetailPageState
    extends ConsumerState<PurchaseInvoiceDetailPage> {
  static const _df = 'dd/MM/yyyy';

  PurchaseInvoiceModel _invoice(PurchaseInvoiceModel fallback) {
    final invoices = ref.read(purchaseInvoicesStreamProvider).valueOrNull;
    if (invoices == null) return fallback;
    return invoices.where((i) => i.id == fallback.id).firstOrNull ?? fallback;
  }

  bool get _canEdit {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return false;
    final role = ref.read(userRoleProvider(user.uid)).valueOrNull;
    return role == RoleService.ADMIN || role == RoleService.ACCOUNTING;
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice(widget.invoice);
    final isInventory = invoice.type == PurchaseInvoiceType.inventario;
    final color = isInventory ? Colors.indigo : AppColors.primaryBlue;
    final statusColor = invoice.status == PurchaseInvoiceStatus.pagada
        ? Colors.green
        : invoice.status == PurchaseInvoiceStatus.anulada
            ? Colors.grey
            : Colors.orange;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Detalle de Factura'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(invoice, color, statusColor),
          const SizedBox(height: 16),
          _buildSection('Información',
              children: _buildInfoRows(invoice, isInventory)),
          const SizedBox(height: 16),
          if (invoice.items.isNotEmpty) ...[
            _buildSection('Ítems', children: _buildItems(invoice)),
            const SizedBox(height: 16),
          ],
          _buildSection('Totales', children: _buildTotals(invoice)),
          const SizedBox(height: 16),
          _buildNotes(invoice),
          if (_canEdit) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _edit(context, invoice),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar Factura'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(PurchaseInvoiceModel inv, Color color, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[800]!, Colors.indigo[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  inv.type == PurchaseInvoiceType.inventario
                      ? Icons.inventory_2_outlined
                      : Icons.receipt_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.supplierName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${inv.documentType} '
                      '${inv.documentNumber.isNotEmpty ? 'N° ${inv.documentNumber}' : ''}',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _chip(inv.status.name.toUpperCase(), statusColor, Colors.white),
              const SizedBox(width: 8),
              _chip(inv.type.name.toUpperCase(), color, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _buildInfoRows(PurchaseInvoiceModel inv, bool isInventory) {
    final df = DateFormat(_df);
    final rows = <(String, String)>[
      ('Emisión', df.format(inv.issueDate)),
      ('Vence', inv.dueDate != null ? df.format(inv.dueDate!) : '—'),
      ('Pago', _paymentLabel(inv.paymentType)),
      ('Categoría', inv.category),
      ('Cuenta', inv.accountCode),
    ];
    if (inv.supplierIdentification != null &&
        inv.supplierIdentification!.isNotEmpty) {
      rows.insert(0, ('RUC / Cédula', inv.supplierIdentification!));
    }
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(row.$1,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
              Expanded(
                child: Text(row.$2,
                    style:
                        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
    ];
  }

  String _paymentLabel(String paymentType) {
    switch (paymentType) {
      case 'contado':
        return 'Contado';
      case 'transferencia':
        return 'Transferencia';
      case 'credito':
        return 'Crédito';
      default:
        return paymentType;
    }
  }

  List<Widget> _buildItems(PurchaseInvoiceModel inv) {
    return [
      for (final item in inv.items)
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('x${item.quantity} · '
                        '\$${item.unitCost.toStringAsFixed(2)}/u',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Text('\$${item.totalCost.toStringAsFixed(2)}',
                  style:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildTotals(PurchaseInvoiceModel inv) {
    return [
      _totalRow('Subtotal', inv.subtotal),
      _totalRow('IVA (${(inv.vatRate * 100).toStringAsFixed(0)}%)',
          inv.vatAmount),
      const Divider(height: 12),
      _totalRow('Total (IVA capitalizado)', inv.total, isBold: true),
    ];
  }

  Widget _totalRow(String label, double value, {bool isBold = false}) {
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
                  color: isBold ? AppColors.primaryBlue : null)),
        ],
      ),
    );
  }

  Widget _buildNotes(PurchaseInvoiceModel inv) {
    if (inv.notes == null || inv.notes!.isEmpty) return const SizedBox.shrink();
    return _buildSection('Notas',
        children: [
          Text(inv.notes!,
              style: const TextStyle(fontSize: 12, height: 1.4)),
        ]);
  }

  Widget _buildSection(String title, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, PurchaseInvoiceModel inv) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => PurchaseInvoiceFormDialog(invoice: inv),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factura actualizada')),
    );
    setState(() {});
  }
}
