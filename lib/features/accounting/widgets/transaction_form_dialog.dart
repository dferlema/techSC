import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/utils/ecuador_validator.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

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
    'Electricidad',
    'Agua',
    'Teléfono/Internet',
    'Combustible',
    'Marketing',
    'Comisiones',
    'Honorarios',
    'Gasto General',
    'Otros',
  ];
  final List<String> _categoriesIN = [
    'Venta Manual',
    'Servicio Técnico',
    'Venta de Activos',
    'Alquiler de Equipos',
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
                  if (val.length == 10 && !EcuadorValidator.validateCedula(val)) {
                    return 'Cédula inválida';
                  }
                  if (val.length == 13 && !EcuadorValidator.validateRUC(val)) {
                    return 'RUC inválido';
                  }
                  if (val.length != 10 && val.length != 13) {
                    return 'Debe tener 10 o 13 dígitos';
                  }
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
                initialValue: _selectedVatRate,
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
                initialValue: _selectedCategory,
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

      // Asiento contable automático (mapeo categoría → cuenta del plan 4.x/5.x)
      await _postJournalEntry(transaction);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _accountForCategory(String category, TransactionType type) {
    if (type == TransactionType.ingreso) {
      switch (category) {
        case 'Venta Manual':
          return '4.1'; // Ventas de Productos
        case 'Servicio Técnico':
          return '4.2'; // Servicios Técnicos
        case 'Venta de Activos':
          return '4.3.04'; // Venta de Activos Fijos
        case 'Alquiler de Equipos':
          return '4.3.03'; // Ingresos por Alquiler de Equipos
        case 'Ajuste de Saldo':
          return '4.3.06'; // Otros Ingresos Operativos
        default:
          return '4.3.06';
      }
    }
    switch (category) {
      case 'Arriendo':
        return '5.2.01.01'; // Arriendo de Local Comercial
      case 'Sueldos':
        return '5.1.01'; // Sueldos y Salarios
      case 'Suministros':
        return '5.2.03.01'; // Material de Oficina
      case 'Material de Oficina':
        return '5.2.03.01';
      case 'Servicios Básicos':
        return '5.2.02'; // Servicios Básicos (grupo)
      case 'Electricidad':
        return '5.2.02.01'; // Energía Eléctrica
      case 'Agua':
        return '5.2.02.02'; // Agua Potable
      case 'Teléfono/Internet':
        return '5.2.02.03'; // Telecomunicaciones
      case 'Combustible':
        return '5.3.01'; // Combustibles y Lubricantes
      case 'Marketing':
      case 'Publicidad':
        return '5.4.01'; // Publicidad y Marketing
      case 'Comisiones':
        return '5.4.04'; // Comisiones en Ventas
      case 'Honorarios':
        return '5.8.01'; // Honorarios Profesionales
      case 'Gasto General':
      case 'Otros':
        return '5.9.06'; // Gastos Generales
      default:
        return '5.9.06';
    }
  }

  Future<void> _postJournalEntry(TransactionModel transaction) async {
    try {
      final total = transaction.total;
      final expenseAccount = _accountForCategory(
        transaction.category,
        transaction.type,
      );
      final description = transaction.description.isNotEmpty
          ? transaction.description
          : 'Movimiento ${transaction.type == TransactionType.ingreso ? 'de ingreso' : 'de gasto'} (${transaction.category})';

      final List<Map<String, dynamic>> lines = [];
      if (transaction.type == TransactionType.ingreso) {
        // Negocio popular RIMPE: no cobra IVA en ventas.
        // DR Caja por el total / CR Ingreso por el total.
        lines.add({'accountCode': '1.1.01.01', 'debit': total, 'credit': 0.0});
        lines.add({'accountCode': expenseAccount, 'debit': 0.0, 'credit': total});
      } else {
        // Negocio popular (RIMPE): el IVA del gasto NO es acreditable, se
        // capitaliza como parte del gasto. DR Gasto por el total / CR Caja.
        lines.add({'accountCode': expenseAccount, 'debit': total, 'credit': 0.0});
        lines.add({'accountCode': '1.1.01.01', 'debit': 0.0, 'credit': total});
      }

      await JournalEntryService().createEntryFromEvent(
        referenceType: 'manual_${transaction.type.name}',
        referenceId: transaction.id.isNotEmpty ? transaction.id : DateTime.now().microsecondsSinceEpoch.toString(),
        date: transaction.date,
        description: description,
        lines: lines,
      );
    } catch (e) {
      debugPrint('⚠️ Error al crear asiento de movimiento manual: $e');
    }
  }
}
