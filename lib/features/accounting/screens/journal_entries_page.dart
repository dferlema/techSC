import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/journal_entry_form_dialog.dart';

class JournalEntriesPage extends ConsumerWidget {
  const JournalEntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesStreamProvider);
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Asientos Contables'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Recalcular saldos de todas las cuentas',
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final role = await RoleService().getUserRole(user.uid);
              if (!context.mounted) return;
              if (role == RoleService.ADMIN || role == RoleService.ACCOUNTING) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Recalcular Saldos'),
                    content: const Text(
                      'Recalculará todos los saldos del plan de cuentas desde cero usando los asientos contabilizados. ¿Continuar?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Recalcular'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔄 Recalculando saldos...')),
                  );
                  final changes = await ref.read(chartOfAccountsServiceProvider).recalculateAllBalances();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Saldos recalculados: ${changes.length} cuentas procesadas')),
                  );
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solo administradores y contabilidad')),
                );
              }
            },
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No hay asientos contables', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: () => _showEntryForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo Asiento'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(entriesStreamProvider),
            child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final statusIcon = entry.status == EntryStatus.contabilizado
                  ? Icons.check_circle
                  : entry.status == EntryStatus.cancelado
                      ? Icons.cancel
                      : Icons.edit_note;
              final statusColor = entry.status == EntryStatus.contabilizado
                  ? Colors.green
                  : entry.status == EntryStatus.cancelado
                      ? Colors.red
                      : Colors.orange;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  title: Text(entry.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${df.format(entry.date)}  ·  ${entry.description}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${entry.totalDebit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      PopupMenuButton(
                        iconSize: 20,
                        itemBuilder: (context) => [
                          if (entry.status == EntryStatus.borrador) ...[
                            const PopupMenuItem(value: 'post', child: Text('Contabilizar')),
                            const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          ],
                          const PopupMenuItem(value: 'cancel', child: Text('Anular')),
                        ],
                        onSelected: (val) async {
                          if (val == 'post') {
                            try {
                              await ref.read(journalEntryServiceProvider).postEntry(entry.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            }
                          } else if (val == 'cancel') {
                            await ref.read(journalEntryServiceProvider).cancelEntry(entry.id);
                          } else if (val == 'edit') {
                            await _showEntryForm(context, ref, entry: entry);
                          }
                        },
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(flex: 4, child: Text('Cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text('Débito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text('Crédito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[700]))),
                              ],
                            ),
                            const Divider(height: 8),
                            ...entry.lines.map((l) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 4, child: Text('${l.accountCode} ${l.accountName}', style: const TextStyle(fontSize: 11))),
                                      Expanded(
                                        flex: 2,
                                        child: Text(l.debit > 0 ? '\$${l.debit.toStringAsFixed(2)}' : '',
                                            style: TextStyle(fontSize: 11, color: l.debit > 0 ? Colors.red[700] : null)),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(l.credit > 0 ? '\$${l.credit.toStringAsFixed(2)}' : '',
                                            style: TextStyle(fontSize: 11, color: l.credit > 0 ? Colors.green[700] : null)),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
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
        onPressed: () => _showEntryForm(context, ref),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEntryForm(BuildContext context, WidgetRef ref, {AccountingEntryModel? entry}) async {
    await showDialog(
      context: context,
      builder: (context) => JournalEntryFormDialog(entry: entry),
    );
  }
}
