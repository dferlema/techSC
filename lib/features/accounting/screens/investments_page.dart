import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/investment_form_dialog.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';

class InvestmentsPage extends ConsumerWidget {
  const InvestmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inversiones y Aportes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final investments = transactions
              .where((t) => t.type == TransactionType.inversion)
              .toList();
          if (investments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay inversiones registradas',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Presione + para registrar un aporte',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: investments.length,
            itemBuilder: (context, index) {
              final t = investments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: const Icon(Icons.trending_up, color: Colors.green),
                  ),
                  title: Text(
                    t.counterpartyName?.isNotEmpty == true
                        ? t.counterpartyName!
                        : t.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${t.date.day}/${t.date.month}/${t.date.year} • ${t.description}',
                  ),
                  trailing: Text(
                    '\$${t.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const InvestmentFormDialog(),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Registrar Aporte'),
      ),
    );
  }
}
