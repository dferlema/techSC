import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/payable_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/payable_form_dialog.dart';
import 'package:tscomputer/features/accounting/widgets/payment_dialog.dart';
import 'package:tscomputer/features/accounting/services/financial_report_service.dart';

class PayablesPage extends ConsumerStatefulWidget {
  const PayablesPage({super.key});

  @override
  ConsumerState<PayablesPage> createState() => _PayablesPageState();
}

class _PayablesPageState extends ConsumerState<PayablesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _aging;
  bool _loadingAging = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _loadAging();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAging() async {
    setState(() => _loadingAging = true);
    try {
      final aging = await FinancialReportService().getPayablesAging();
      if (mounted) setState(() { _aging = aging; _loadingAging = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Cuentas por Pagar'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Envejecimiento'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingView(),
          _buildAgingView(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (context) => const PayableFormDialog()),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPendingView() {
    final payablesAsync = ref.watch(payablesStreamProvider);
    final df = DateFormat('dd/MM/yyyy');

    return payablesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (payables) {
        if (payables.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hay cuentas por pagar'),
              ],
            ),
          );
        }
        final totalPending = payables
            .where((p) => p.status != PayableStatus.pagada)
            .fold(0.0, (sum, p) => sum + p.balance);
        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[800]!, Colors.red[600]!],
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
                    child: const Icon(Icons.pending_actions, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Pendiente', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      Text('\$${totalPending.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(payablesStreamProvider);
                  await _loadAging();
                },
                child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: payables.length,
                itemBuilder: (context, index) {
                  final p = payables[index];
                  final statusColor = p.status == PayableStatus.pagada
                      ? Colors.green
                      : p.status == PayableStatus.vencida ? Colors.red : Colors.orange;
                  final isPaid = p.status == PayableStatus.pagada;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(Icons.business, color: statusColor, size: 22),
                      ),
                      title: Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        '${df.format(p.issueDate)}  ·  ${p.originType}\nSaldo: \$${p.balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.status.name.toUpperCase(),
                              style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      onTap: isPaid ? null : () => _showPaymentDialog(context, ref, p),
                      onLongPress: () => _confirmDelete(context, ref, p),
                    ),
                  );
                },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAgingView() {
    if (_loadingAging) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_aging == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Cargar envejecimiento'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _loadAging, child: const Text('Cargar')),
          ],
        ),
      );
    }

    final d = _aging!;
    return RefreshIndicator(
      onRefresh: _loadAging,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.deepPurple[700]!, Colors.deepPurple[500]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Envejecimiento CxP', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                const SizedBox(height: 4),
                Text('Total: \$${(d['total'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _agingRow('0 - 30 días', d['0_30'] as double, Colors.green),
          const SizedBox(height: 8),
          _agingRow('31 - 60 días', d['31_60'] as double, Colors.orange),
          const SizedBox(height: 8),
          _agingRow('61 - 90 días', d['61_90'] as double, Colors.deepOrange),
          const SizedBox(height: 8),
          _agingRow('90+ días', d['90plus'] as double, Colors.red),
        ],
      ),
      ),
    );
  }

  Widget _agingRow(String label, double amount, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PayableModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar CxP'),
        content: Text('¿Eliminar cuenta de ${p.supplierName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(payableServiceProvider).deletePayable(p.id);
    }
  }

  Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref, PayableModel p) async {
    final result = await showPaymentDialog(
      context,
      title: 'Pago - ${p.supplierName}',
      labelPrefix: 'Pago CxP',
      currentBalance: p.balance,
    );
    if (result == null) return;
    try {
      await ref.read(payableServiceProvider).registerPayment(
        p.id,
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago registrado: \$${(result['amount'] as double).toStringAsFixed(2)}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
