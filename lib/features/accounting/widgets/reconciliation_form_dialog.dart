import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/bank_reconciliation_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

class ReconciliationFormDialog extends ConsumerStatefulWidget {
  const ReconciliationFormDialog({super.key});

  @override
  ConsumerState<ReconciliationFormDialog> createState() =>
      _ReconciliationFormDialogState();
}

class _ReconciliationFormDialogState
    extends ConsumerState<ReconciliationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bankCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _systemCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _statementDate = DateTime.now();
  final _lines = <_LineEntry>[];

  @override
  void dispose() {
    _bankCtrl.dispose();
    _accountCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _systemCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.descCtrl.dispose();
      l.amountCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Conciliación Bancaria'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Banco',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _accountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número de Cuenta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fecha Estado: ${_statementDate.day}/${_statementDate.month}/${_statementDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _statementDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null)
                          setState(() => _statementDate = picked);
                      },
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _openCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Saldo Inicial',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _closeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Saldo Según Extracto',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _systemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Saldo del Sistema',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Movimientos del Extracto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._lines.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: entry.value.descCtrl,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Descripción',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: entry.value.amountCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Monto',
                              border: const OutlineInputBorder(),
                              prefixText: '\$ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          value: entry.value.type,
                          items: const [
                            DropdownMenuItem(
                              value: 'debito',
                              child: Text(
                                'Débito',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'credito',
                              child: Text(
                                'Crédito',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => entry.value.type = v ?? 'debito'),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              setState(() => _lines.removeAt(entry.key)),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineEntry())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Agregar Movimiento',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final lines = _lines
        .map(
          (l) => BankTransactionLine(
            id: '',
            date: _statementDate,
            description: l.descCtrl.text.trim(),
            amount: double.tryParse(l.amountCtrl.text) ?? 0,
            type: l.type == 'credito'
                ? ReconTransactionType.credito
                : ReconTransactionType.debito,
          ),
        )
        .toList();

    final recon = BankReconciliationModel(
      id: '',
      bankName: _bankCtrl.text.trim(),
      accountNumber: _accountCtrl.text.trim().isEmpty
          ? null
          : _accountCtrl.text.trim(),
      statementDate: _statementDate,
      openingBalance: double.tryParse(_openCtrl.text) ?? 0,
      closingBalance: double.tryParse(_closeCtrl.text) ?? 0,
      lines: lines,
      systemBalance: double.tryParse(_systemCtrl.text) ?? 0,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    try {
      await ref
          .read(bankReconciliationServiceProvider)
          .createReconciliation(recon);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _LineEntry {
  TextEditingController descCtrl;
  TextEditingController amountCtrl;
  String type;

  _LineEntry()
    : descCtrl = TextEditingController(),
      amountCtrl = TextEditingController(),
      type = 'debito';
}
