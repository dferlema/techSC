import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/credit_form_dialog.dart';
import 'package:tscomputer/features/accounting/widgets/loan_payment_form_dialog.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';

class CreditsPage extends ConsumerWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos y Préstamos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final credits = transactions
              .where((t) =>
                  t.type == TransactionType.credito ||
                  t.type == TransactionType.pagoCredito)
              .toList();
          if (credits.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay préstamos registrados',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Registre un préstamo o crédito bancario',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          // Agrupar por banco/contraparte
          final Map<String, List<TransactionModel>> grouped = {};
          for (final t in credits) {
            final key = t.counterpartyName ?? 'Sin entidad';
            grouped.putIfAbsent(key, () => []).add(t);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final bankName = grouped.keys.elementAt(index);
              final bankTx = grouped[bankName]!;

              double totalLoan = 0;
              double totalPaid = 0;
              for (final t in bankTx) {
                if (t.type == TransactionType.credito) {
                  totalLoan += t.total;
                } else {
                  totalPaid += t.principalAmount ?? t.total;
                }
              }
              final balance = totalLoan - totalPaid;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child:
                        const Icon(Icons.account_balance, color: Colors.orange),
                  ),
                  title: Text(
                    bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Préstamo: \$${totalLoan.toStringAsFixed(2)} | '
                    'Pagado: \$${totalPaid.toStringAsFixed(2)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Saldo',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balance > 0 ? Colors.red : Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  children: bankTx.map((t) {
                    final isLoan = t.type == TransactionType.credito;
                    return ListTile(
                      leading: Icon(
                        isLoan ? Icons.add_circle : Icons.remove_circle,
                        color: isLoan ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      title: Text(
                        isLoan ? 'Préstamo recibido' : 'Pago de cuota',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${t.date.day}/${t.date.month}/${t.date.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${isLoan ? '+' : '-'}\$${t.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLoan ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'loan_payment',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const LoanPaymentFormDialog(),
            ),
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            icon: const Icon(Icons.payment),
            label: const Text('Pagar Cuota'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new_credit',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const CreditFormDialog(),
            ),
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo Préstamo'),
          ),
        ],
      ),
    );
  }
}
