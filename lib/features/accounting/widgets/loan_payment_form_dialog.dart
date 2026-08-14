import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Formulario para registrar el pago de una cuota de préstamo.
///
/// Asiento contable:
///   DR Oblig. Financieras (2.1.06.01 o 2.2.01) - capital
///   DR Gasto Financiero / Intereses (5.5.02) - interés
///   CR Bancos (1.1.01.03) - total pagado
class LoanPaymentFormDialog extends ConsumerStatefulWidget {
  const LoanPaymentFormDialog({super.key});

  @override
  ConsumerState<LoanPaymentFormDialog> createState() =>
      _LoanPaymentFormDialogState();
}

class _LoanPaymentFormDialogState extends ConsumerState<LoanPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bankController = TextEditingController(text: 'Banco Pichincha');

  String _loanType = 'cp';

  double get _totalPaid {
    final p = double.tryParse(_principalController.text) ?? 0;
    final i = double.tryParse(_interestController.text) ?? 0;
    return p + i;
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    _descriptionController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pago de Cuota de Préstamo'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _bankController,
                decoration: const InputDecoration(
                  labelText: 'Entidad Bancaria',
                  prefixIcon: Icon(Icons.account_balance),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _loanType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Préstamo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'cp',
                    child: Text('Corto Plazo'),
                  ),
                  DropdownMenuItem(
                    value: 'lp',
                    child: Text('Largo Plazo'),
                  ),
                ],
                onChanged: (val) => setState(() => _loanType = val ?? 'cp'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _principalController,
                decoration: const InputDecoration(
                  labelText: 'Capital (abono al préstamo)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestController,
                decoration: const InputDecoration(
                  labelText: 'Intereses',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a pagar:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '\$${_totalPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción / N° Cuota',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Cuota #3 mensual',
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
          child: const Text('Registrar Pago'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final principal = double.tryParse(_principalController.text) ?? 0;
    final interest = double.tryParse(_interestController.text) ?? 0;
    final total = principal + interest;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El total del pago debe ser mayor a 0')),
      );
      return;
    }

    final description = _descriptionController.text.trim().isEmpty
        ? 'Pago cuota préstamo - ${_bankController.text.trim()}'
        : _descriptionController.text.trim();

    final liabilityAccount = _loanType == 'cp' ? '2.1.06.01' : '2.2.01';

    final transaction = TransactionModel(
      id: '',
      type: TransactionType.pagoCredito,
      category: 'Pago Préstamo',
      amount: total,
      vatAmount: 0,
      vatRate: 0,
      total: total,
      date: DateTime.now(),
      description: description,
      counterpartyName: _bankController.text.trim(),
      principalAmount: principal,
      interestAmount: interest,
      accountCode: liabilityAccount,
    );

    try {
      await ref.read(accountingServiceProvider).saveTransaction(transaction);
      await _postJournalEntry(transaction, principal, interest, liabilityAccount);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _postJournalEntry(
    TransactionModel transaction,
    double principal,
    double interest,
    String liabilityAccount,
  ) async {
    try {
      final lines = <Map<String, dynamic>>[];

      // DR Obligación Financiera (capital)
      if (principal > 0) {
        lines.add({
          'accountCode': liabilityAccount,
          'debit': principal,
          'credit': 0.0,
        });
      }

      // DR Gasto Financiero / Intereses (si hay)
      if (interest > 0) {
        lines.add({
          'accountCode': '5.5.02',
          'debit': interest,
          'credit': 0.0,
        });
      }

      // CR Bancos (total)
      lines.add({
        'accountCode': '1.1.01.03',
        'debit': 0.0,
        'credit': transaction.total,
      });

      await JournalEntryService().createEntryFromEvent(
        referenceType: 'pago_credito',
        referenceId: transaction.id.isNotEmpty
            ? transaction.id
            : DateTime.now().microsecondsSinceEpoch.toString(),
        date: transaction.date,
        description: transaction.description,
        lines: lines,
      );
    } catch (e) {
      debugPrint('⚠️ Error al crear asiento de pago de préstamo: $e');
    }
  }
}
