import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/core/utils/ecuador_validator.dart';
import 'package:techsc/features/accounting/models/transaction_model.dart';
import 'package:techsc/features/accounting/providers/accounting_providers.dart';

/// Diálogo para registrar una nueva transacción contable (Gasto o Ingreso manual).
///
/// Diseñado para el contexto de Ecuador, permitiendo seleccionar tasas de IVA.
class TransactionFormDialog extends ConsumerStatefulWidget {
  const TransactionFormDialog({super.key});

  @override
  ConsumerState<TransactionFormDialog> createState() =>
      _TransactionFormDialogState();
}

class _TransactionFormDialogState extends ConsumerState<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _idController = TextEditingController();

  TransactionType _selectedType = TransactionType.egreso;
  String _selectedCategory = 'Gasto General';
  double _selectedVatRate = 0.15; // Tasa IVA estándar Ecuador (2024+)

  final List<String> _categoriesEG = [
    'Arriendo',
    'Sueldos',
    'Suministros',
    'Servicios Básicos',
    'Gasto General',
    'Otros',
  ];
  final List<String> _categoriesIN = [
    'Venta Manual',
    'Ajuste de Saldo',
    'Otros',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Movimiento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de Tipo
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.ingreso,
                    label: Text('Ingreso'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                  ButtonSegment(
                    value: TransactionType.egreso,
                    label: Text('Egreso'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedType = val.first;
                    _selectedCategory = _selectedType == TransactionType.ingreso
                        ? _categoriesIN[0]
                        : _categoriesEG[0];
                  });
                },
              ),
              const SizedBox(height: 16),

              // Identificación (Cédula o RUC)
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'RUC / Cédula (Ecuador)',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                  helperText: '10 o 13 dígitos válidos.',
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requerido para SRI';
                  if (val.length == 10 && !EcuadorValidator.validateCedula(val))
                    return 'Cédula inválida';
                  if (val.length == 13 && !EcuadorValidator.validateRUC(val))
                    return 'RUC inválido';
                  if (val.length != 10 && val.length != 13)
                    return 'Debe tener 10 o 13 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Monto Subtotal
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto Subtotal (sin IVA)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // Selector de IVA (Ecuador)
              DropdownButtonFormField<double>(
                value: _selectedVatRate,
                decoration: const InputDecoration(
                  labelText: 'Tasa de IVA',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0.15, child: Text('IVA 15%')),
                  DropdownMenuItem(
                    value: 0.08,
                    child: Text('IVA 8% (Turismo)'),
                  ),
                  DropdownMenuItem(value: 0.0, child: Text('IVA 0%')),
                ],
                onChanged: (val) =>
                    setState(() => _selectedVatRate = val ?? 0.15),
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items:
                    (_selectedType == TransactionType.ingreso
                            ? _categoriesIN
                            : _categoriesEG)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? ''),
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Concepto',
                  border: OutlineInputBorder(),
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final subtotal = double.tryParse(_amountController.text) ?? 0.0;

    final transaction = TransactionModel.createWithTax(
      id: '', // Firestore generará el ID
      type: _selectedType,
      category: _selectedCategory,
      subtotal: subtotal,
      vatRate: _selectedVatRate,
      date: DateTime.now(),
      description: _descriptionController.text.trim(),
      clientIdentification: _idController.text.trim(),
    );

    try {
      await ref.read(accountingServiceProvider).saveTransaction(transaction);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
