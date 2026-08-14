import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Formulario para registrar transferencias entre cuentas bancarias o caja.
///
/// Asiento contable:
///   DR Cuenta destino  /  CR Cuenta origen
class TransferFormDialog extends ConsumerStatefulWidget {
  const TransferFormDialog({super.key});

  @override
  ConsumerState<TransferFormDialog> createState() =>
      _TransferFormDialogState();
}

class _TransferFormDialogState extends ConsumerState<TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _originAccount = '1.1.01.01';
  String _destinationAccount = '1.1.01.03';

  static const List<Map<String, String>> _accounts = [
    {'code': '1.1.01.01', 'name': 'Caja General'},
    {'code': '1.1.01.02', 'name': 'Caja Chica'},
    {'code': '1.1.01.03', 'name': 'Bancos - Cuenta Corriente'},
    {'code': '1.1.01.04', 'name': 'Bancos - Cuenta de Ahorros'},
    {'code': '1.1.01.05', 'name': 'Depósitos a Plazo'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transferencia Bancaria'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _originAccount,
                decoration: const InputDecoration(
                  labelText: 'Cuenta Origen',
                  border: OutlineInputBorder(),
                ),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                          value: a['code'],
                          child: Text(a['name']!),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _originAccount = val ?? '1.1.01.01'),
                validator: (v) {
                  if (v == null) return 'Requerido';
                  if (v == _destinationAccount) return 'Debe ser diferente al destino';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Icon(Icons.arrow_downward, color: Colors.grey),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _destinationAccount,
                decoration: const InputDecoration(
                  labelText: 'Cuenta Destino',
                  border: OutlineInputBorder(),
                ),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                          value: a['code'],
                          child: Text(a['name']!),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _destinationAccount = val ?? '1.1.01.03'),
                validator: (v) {
                  if (v == null) return 'Requerido';
                  if (v == _originAccount) return 'Debe ser diferente al origen';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Transferencia a cuenta de ahorros',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Transferir'),
        ),
      ],
    );
  }

  String _accountName(String code) {
    return _accounts.firstWhere(
      (a) => a['code'] == code,
      orElse: () => {'name': code},
    )['name']!;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final originName = _accountName(_originAccount);
    final destName = _accountName(_destinationAccount);
    final description = _descriptionController.text.trim().isEmpty
        ? 'Transferencia de $originName a $destName'
        : _descriptionController.text.trim();

    final transaction = TransactionModel(
      id: '',
      type: TransactionType.transferencia,
      category: 'Transferencia',
      amount: amount,
      vatAmount: 0,
      vatRate: 0,
      total: amount,
      date: DateTime.now(),
      description: description,
      accountCode: _originAccount,
    );

    try {
      await ref.read(accountingServiceProvider).saveTransaction(transaction);
      await _postJournalEntry(amount);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _postJournalEntry(double amount) async {
    try {
      final lines = <Map<String, dynamic>>[
        {
          'accountCode': _destinationAccount,
          'debit': amount,
          'credit': 0.0,
        },
        {
          'accountCode': _originAccount,
          'debit': 0.0,
          'credit': amount,
        },
      ];

      await JournalEntryService().createEntryFromEvent(
        referenceType: 'transferencia',
        referenceId: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        description: _descriptionController.text.trim().isEmpty
            ? 'Transferencia interna'
            : _descriptionController.text.trim(),
        lines: lines,
      );
    } catch (e) {
      debugPrint('⚠️ Error al crear asiento de transferencia: $e');
    }
  }
}
