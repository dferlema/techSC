import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/purchase_invoice_model.dart';
import 'package:tscomputer/features/accounting/models/payable_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/screens/purchase_invoice_detail_page.dart';
import 'package:tscomputer/features/accounting/widgets/purchase_invoice_form_dialog.dart';
import 'package:tscomputer/features/accounting/widgets/payment_dialog.dart';

/// Pantalla de Facturas de Compra y Gastos.
///
/// Lista las facturas registradas (gastos y compras de inventario) con su
/// estado de pago, y permite registrar nuevas facturas o pagarlas (la CxP
/// generada se liquida desde aquí o desde el módulo de Cuentas por Pagar).
class PurchaseInvoicesPage extends ConsumerStatefulWidget {
  const PurchaseInvoicesPage({super.key});

  @override
  ConsumerState<PurchaseInvoicesPage> createState() =>
      _PurchaseInvoicesPageState();
}

class _PurchaseInvoicesPageState extends ConsumerState<PurchaseInvoicesPage> {
  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(purchaseInvoicesStreamProvider);
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Facturas de Compra y Gastos'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay facturas registradas'),
                  SizedBox(height: 4),
                  Text(
                    'Registra compras y gastos con su factura.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final totalPendiente = invoices
              .where((i) => i.status == PurchaseInvoiceStatus.pendiente)
              .fold(0.0, (sum, i) => sum + i.total);
          final totalMes = invoices
              .where((i) =>
                  i.issueDate.month == DateTime.now().month &&
                  i.issueDate.year == DateTime.now().year)
              .fold(0.0, (sum, i) => sum + i.total);

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[800]!, Colors.indigo[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pendientes de pago',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                        Text('\$${totalPendiente.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Mes actual',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                        Text('\$${totalMes.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(purchaseInvoicesStreamProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: invoices.length,
                    itemBuilder: (context, index) {
                      final inv = invoices[index];
                      return _buildInvoiceCard(context, inv, df);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const PurchaseInvoiceFormDialog(),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, PurchaseInvoiceModel inv, DateFormat df) {
    final isInventory = inv.type == PurchaseInvoiceType.inventario;
    final statusColor = inv.status == PurchaseInvoiceStatus.pagada
        ? Colors.green
        : inv.status == PurchaseInvoiceStatus.anulada
            ? Colors.grey
            : Colors.orange;
    final color = isInventory ? Colors.indigo : AppColors.primaryBlue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseInvoiceDetailPage(invoice: inv),
          ),
        ),
        onLongPress: () => _confirmDelete(context, ref, inv),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              isInventory ? Icons.inventory_2_outlined : Icons.receipt_outlined,
              color: color,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  inv.supplierName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  inv.status.name.toUpperCase(),
                  style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${inv.documentType} ${inv.documentNumber.isNotEmpty ? 'N° ${inv.documentNumber}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${df.format(inv.issueDate)} · ${inv.category} · ${inv.paymentType}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (inv.items.isNotEmpty)
                Text(
                  '${inv.items.length} ítem(s)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${inv.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (inv.status == PurchaseInvoiceStatus.pendiente && inv.payableId != null)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => _showPaymentDialog(context, ref, inv),
                  child: const Text('Pagar', style: TextStyle(fontSize: 11)),
                )
              else
                Text(
                  isInventory ? 'Inventario' : 'Gasto',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(
      BuildContext context, WidgetRef ref, PurchaseInvoiceModel inv) async {
    final payableId = inv.payableId;
    if (payableId == null) return;
    final payable = await _findPayable(payableId);
    if (payable == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró la CxP de esta factura')),
      );
      return;
    }
    final result = await showPaymentDialog(
      context,
      title: 'Pago - ${inv.supplierName}',
      labelPrefix: 'Pago Factura',
      currentBalance: payable.balance,
    );
    if (result == null) return;
    try {
      await ref.read(payableServiceProvider).registerPayment(
        payableId,
        result['amount'] as double,
        result['method'] as String,
        applyVAT: result['applyVAT'] as bool,
        date: result['date'] as DateTime?,
        reference: result['reference'] as String?,
        bank: result['bank'] as String?,
        accountNumber: result['accountNumber'] as String?,
        accountHolder: result['accountHolder'] as String?,
        cardLast4: result['cardLast4'] as String?,
        notes: result['notes'] as String?,
      );
      // Actualizar estado de la factura según el nuevo saldo de la CxP.
      final updated = await _findPayable(payableId);
      final newStatus = updated != null && updated.status.name == 'pagada'
          ? PurchaseInvoiceStatus.pagada
          : PurchaseInvoiceStatus.pendiente;
      await ref
          .read(purchaseInvoiceServiceProvider)
          .updateStatus(inv.id, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago registrado: \$${(result['amount'] as double).toStringAsFixed(2)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<PayableModel?> _findPayable(String payableId) async {
    try {
      final payables = await ref.read(payableServiceProvider).getAllPayables();
      return payables.where((p) => p.id == payableId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, PurchaseInvoiceModel inv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar factura'),
        content: Text('¿Eliminar factura de ${inv.supplierName} (${inv.documentNumber})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(purchaseInvoiceServiceProvider).deleteInvoice(inv.id);
    }
  }
}
