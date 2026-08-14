import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/payable_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

class PayableFormDialog extends ConsumerStatefulWidget {
  const PayableFormDialog({super.key});

  @override
  ConsumerState<PayableFormDialog> createState() => _PayableFormDialogState();
}

class _PayableFormDialogState extends ConsumerState<PayableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Cuenta por Pagar'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del Proveedor', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'RUC / Cédula', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextFormField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Monto Total', prefixText: '\$ ', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Emisión: ${_issueDate.day}/${_issueDate.month}/${_issueDate.year}', style: const TextStyle(fontSize: 12))),
                  TextButton(onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _issueDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setState(() => _issueDate = picked);
                  }, child: const Text('Cambiar')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('Vence: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}', style: const TextStyle(fontSize: 12))),
                  TextButton(onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setState(() => _dueDate = picked);
                  }, child: const Text('Cambiar')),
                ],
              ),
              TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()), maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final payable = PayableModel(
      id: '',
      supplierName: _nameCtrl.text.trim(),
      supplierIdentification: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
      supplierPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      originType: 'manual',
      originId: '',
      totalAmount: double.tryParse(_amountCtrl.text) ?? 0,
      issueDate: _issueDate,
      dueDate: _dueDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    try {
      await ref.read(payableServiceProvider).createPayable(payable);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
