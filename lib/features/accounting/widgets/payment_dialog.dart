import 'package:flutter/material.dart';

/// Diálogo para registrar un pago contra una CxC o CxP.
/// Retorna un `Map` con `amount`, `method` y `applyVAT` si el usuario confirma,
/// o `null` si cancela.
Future<Map<String, dynamic>?> showPaymentDialog(
  BuildContext context, {
  required String title,
  required String labelPrefix,
  double maxAmount = 0,
  double currentBalance = 0,
}) {
  final amountController = TextEditingController();
  String method = 'efectivo';
  bool applyVAT = false;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 16),
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
