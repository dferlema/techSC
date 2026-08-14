import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

/// Formulario para registrar un préstamo o crédito bancario.
///
/// Asiento contable:
///   DR Bancos (1.1.01.03)  /  CR Oblig. Financieras CP (2.1.06.01) o LP (2.2.01)
class CreditFormDialog extends ConsumerStatefulWidget {
  const CreditFormDialog({super.key});

  @override
  ConsumerState<CreditFormDialog> createState() => _CreditFormDialogState();
}

class _CreditFormDialogState extends ConsumerState<CreditFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bankController = TextEditingController();
  final _interestRateController = TextEditingController(text: '12');
  final _termMonthsController = TextEditingController(text: '12');
  final _dateController = TextEditingController();

  String _loanType = 'cp';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _updateDateController();
  }

  void _updateDateController() {
    _dateController.text = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _bankController.dispose();
    _interestRateController.dispose();
    _termMonthsController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Préstamo / Crédito'),
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
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
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
                    child: Text('Corto Plazo (< 1 año)'),
                  ),
                  DropdownMenuItem(
                    value: 'lp',
                    child: Text('Largo Plazo (> 1 año)'),
                  ),
                ],
                onChanged: (val) => setState(() => _loanType = val ?? 'cp'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto del Préstamo',
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interestRateController,
                      decoration: const InputDecoration(
                        labelText: 'Tasa Interés %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _termMonthsController,
                      decoration: const InputDecoration(
                        labelText: 'Plazo (meses)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Concepto',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Préstamo para capital de trabajo',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Fecha del Crédito',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _updateDateController();
                    });
                  }
                },
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
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Registrar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final description = _descriptionController.text.trim().isEmpty
        ? 'Préstamo de ${_bankController.text.trim()}'
        : _descriptionController.text.trim();

    final liabilityAccount = _loanType == 'cp' ? '2.1.06.01' : '2.2.01';

    final transaction = TransactionModel(
      id: '',
      type: TransactionType.credito,
      category: 'Préstamo Bancario',
      amount: amount,
      vatAmount: 0,
      vatRate: 0,
      total: amount,
      date: _selectedDate,
      description: description,
      counterpartyName: _bankController.text.trim(),
      accountCode: liabilityAccount,
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _postJournalEntry(TransactionModel transaction) async {
    try {
      final lines = <Map<String, dynamic>>[
        {
          'accountCode': '1.1.01.03',
          'debit': transaction.total,
          'credit': 0.0,
        },
        {
          'accountCode': transaction.accountCode ?? '2.1.06.01',
          'debit': 0.0,
          'credit': transaction.total,
        },
      ];

      await JournalEntryService().createEntryFromEvent(
        referenceType: 'credito',
        referenceId: transaction.id.isNotEmpty
            ? transaction.id
            : DateTime.now().microsecondsSinceEpoch.toString(),
        date: transaction.date,
        description: transaction.description,
        lines: lines,
      );
    } catch (e) {
      debugPrint('⚠️ Error al crear asiento de crédito: $e');
    }
  }
}
