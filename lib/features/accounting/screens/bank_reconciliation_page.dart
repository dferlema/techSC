import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/bank_reconciliation_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/reconciliation_form_dialog.dart';

class BankReconciliationPage extends ConsumerWidget {
  const BankReconciliationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reconsAsync = ref.watch(reconciliationsStreamProvider);
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Conciliación Bancaria'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: reconsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recons) {
          if (recons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.compare_arrows_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No hay conciliaciones', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: () => showDialog(context: context, builder: (context) => const ReconciliationFormDialog()),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Conciliación'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(reconciliationsStreamProvider),
            child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: recons.length,
            itemBuilder: (context, index) {
              final r = recons[index];
              final reconciled = r.lines.where((l) => l.status == ReconStatus.conciliado).length;
              final total = r.lines.length;
              final diff = r.difference;
              final isBalanced = diff.abs() < 0.01;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: isBalanced ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                    child: Icon(isBalanced ? Icons.check_circle : Icons.warning, color: isBalanced ? Colors.green : Colors.orange, size: 22),
                  ),
                  title: Text('${r.bankName}  ·  ${df.format(r.statementDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    '$reconciled/$total conciliados  ·  Diferencia: \$${diff.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _infoRow('Saldo Inicial', r.openingBalance),
                                const SizedBox(height: 4),
                                _infoRow('Saldo según Extracto', r.closingBalance),
                                const SizedBox(height: 4),
                                _infoRow('Saldo del Sistema', r.systemBalance),
                              ],
                            ),
                          ),
                          const Divider(height: 16),
                          ...r.lines.asMap().entries.map((entry) => ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                title: Text(entry.value.description, style: const TextStyle(fontSize: 12)),
                                subtitle: Text(df.format(entry.value.date), style: const TextStyle(fontSize: 10)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '\$${entry.value.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: entry.value.type == ReconTransactionType.debito ? Colors.red[700] : Colors.green[700],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusChip(entry.value.status),
                                    IconButton(
                                      icon: const Icon(Icons.swap_horiz, size: 18),
                                      onPressed: () {
                                        final newStatus = entry.value.status == ReconStatus.conciliado
                                            ? ReconStatus.pendiente
                                            : ReconStatus.conciliado;
                                        ref.read(bankReconciliationServiceProvider).updateLineStatus(r.id, 'line_${entry.key}', newStatus);
                                      },
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (context) => const ReconciliationFormDialog()),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _infoRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text('\$${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statusChip(ReconStatus status) {
    final color = status == ReconStatus.conciliado
        ? Colors.green
        : status == ReconStatus.noConciliado ? Colors.red : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.name[0].toUpperCase(),
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
