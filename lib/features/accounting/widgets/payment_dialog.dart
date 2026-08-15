import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Diálogo para registrar un pago contra una CxC o CxP.
/// Retorna un `Map` con `amount`, `method`, `applyVAT`, `date` y el detalle
/// del pago (`reference`, `bank`, `accountNumber`, `accountHolder`,
/// `cardLast4`, `notes`) si el usuario confirma, o `null` si cancela.
Future<Map<String, dynamic>?> showPaymentDialog(
  BuildContext context, {
  required String title,
  required String labelPrefix,
  double maxAmount = 0,
  double currentBalance = 0,
}) {
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final bankController = TextEditingController();
  final accountNumberController = TextEditingController();
  final accountHolderController = TextEditingController();
  final cardLast4Controller = TextEditingController();
  final notesController = TextEditingController();
  String method = 'efectivo';
  bool applyVAT = false;
  DateTime paymentDate = DateTime.now();
  final df = DateFormat('dd/MM/yyyy');

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final isTransfer = method == 'transferencia';
          final isCard = method == 'tarjeta';
          final isDeposit = method == 'deposito';

          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: paymentDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              helpText: 'Fecha del pago',
            );
            if (picked != null) {
              setDialogState(() => paymentDate = picked);
            }
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentBalance > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        'Saldo pendiente: \$${currentBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto a pagar',
                      prefixText: '\$ ',
                      border: const OutlineInputBorder(),
                      hintText: maxAmount > 0 ? 'Máx: \$${maxAmount.toStringAsFixed(2)}' : '0.00',
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha del pago',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      child: Text(
                        df.format(paymentDate),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                      DropdownMenuItem(value: 'deposito', child: Text('Depósito')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => method = v);
                    },
                  ),
                  if (isTransfer || isDeposit) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: bankController,
                      decoration: InputDecoration(
                        labelText: 'Banco',
                        hintText: isTransfer ? 'Banco emisor / destino' : 'Banco',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (isTransfer) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: accountHolderController,
                        decoration: const InputDecoration(
                          labelText: 'Titular de la cuenta',
                          hintText: 'Nombre del titular',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: accountNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Número de cuenta',
                          hintText: 'Cuenta destino',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Nº de referencia / comprobante',
                        hintText: 'Referencia de la operación',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (isCard) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: cardLast4Controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Últimos 4 dígitos de la tarjeta',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Nº de referencia / voucher',
                        hintText: 'Referencia del cobro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      hintText: 'Notas adicionales (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Aplicar IVA 15%'),
                    subtitle: const Text('Incluir IVA en el monto'),
                    value: applyVAT,
                    onChanged: (v) => setDialogState(() => applyVAT = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final amountStr = amountController.text.trim();
                  final amount = double.tryParse(amountStr);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese un monto válido')),
                    );
                    return;
                  }
                  if (maxAmount > 0 && amount > maxAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('El monto no puede exceder \$${maxAmount.toStringAsFixed(2)}')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'amount': amount,
                    'method': method,
                    'applyVAT': applyVAT,
                    'date': paymentDate,
                    'reference': referenceController.text.trim(),
                    'bank': bankController.text.trim(),
                    'accountNumber': accountNumberController.text.trim(),
                    'accountHolder': accountHolderController.text.trim(),
                    'cardLast4': cardLast4Controller.text.trim(),
                    'notes': notesController.text.trim(),
                  });
                },
                icon: const Icon(Icons.payment, size: 18),
                label: Text('Registrar $labelPrefix'),
              ),
            ],
          );
        },
      );
    },
  );
}