import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Formulario para registrar inversiones o aportes de socios.
///
/// Asiento contable:
///   DR Efectivo/Bancos (1.1.01.xx)  /  CR Capital Social (3.1.01)
class InvestmentFormDialog extends ConsumerStatefulWidget {
  const InvestmentFormDialog({super.key});

  @override
  ConsumerState<InvestmentFormDialog> createState() =>
      _InvestmentFormDialogState();
}

class _InvestmentFormDialogState extends ConsumerState<InvestmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _partnerController = TextEditingController();

  String _assetType = 'efectivo';
  String _bankAccount = '1.1.01.01';

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _partnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Inversión / Aporte'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _partnerController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Socio / Inversionista',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _assetType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Activo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'banco', child: Text('Transferencia Bancaria')),
                  DropdownMenuItem(value: 'equipo', child: Text('Equipo / Activo Fijo')),
                ],
                onChanged: (val) {
                  setState(() {
                    _assetType = val ?? 'efectivo';
                    if (_assetType == 'efectivo') {
                      _bankAccount = '1.1.01.01';
                    } else {
                      _bankAccount = '1.1.01.03';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto del Aporte',
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
                  labelText: 'Descripción / Concepto',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Aporte inicial para capital de trabajo',
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
          child: const Text('Registrar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final description = _descriptionController.text.trim().isEmpty
        ? 'Aporte de ${_partnerController.text.trim()}'
        : _descriptionController.text.trim();

    final transaction = TransactionModel(
      id: '',
      type: TransactionType.inversion,
      category: 'Aporte de Socio',
      amount: amount,
      vatAmount: 0,
      vatRate: 0,
      total: amount,
      date: DateTime.now(),
      description: description,
      counterpartyName: _partnerController.text.trim(),
      accountCode: _bankAccount,
    );

    try {
      await ref.read(accountingServiceProvider).saveTransaction(transaction);
      await _postJournalEntry(transaction);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _postJournalEntry(TransactionModel transaction) async {
    try {
      final lines = <Map<String, dynamic>>[
        {
          'accountCode': transaction.accountCode ?? '1.1.01.01',
          'debit': transaction.total,
          'credit': 0.0,
        },
        {
          'accountCode': '3.1.01',
          'debit': 0.0,
          'credit': transaction.total,
        },
      ];

      await JournalEntryService().createEntryFromEvent(
        referenceType: 'inversion',
        referenceId: transaction.id.isNotEmpty
            ? transaction.id
            : DateTime.now().microsecondsSinceEpoch.toString(),
        date: transaction.date,
        description: transaction.description,
        lines: lines,
      );
    } catch (e) {
      debugPrint('⚠️ Error al crear asiento de inversión: $e');
    }
  }
}
