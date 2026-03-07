import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/features/accounting/models/daily_closure_model.dart';
import 'package:techsc/features/accounting/providers/accounting_providers.dart';

/// Diálogo para realizar el cierre de caja diario.
///
/// Compara el balance del sistema con el efectivo físico contado por el usuario.
class ClosureFormDialog extends ConsumerStatefulWidget {
  final double systemBalance;
  final double totalIngresos;
  final double totalEgresos;

  const ClosureFormDialog({
    super.key,
    required this.systemBalance,
    required this.totalIngresos,
    required this.totalEgresos,
  });

  @override
  ConsumerState<ClosureFormDialog> createState() => _ClosureFormDialogState();
}

class _ClosureFormDialogState extends ConsumerState<ClosureFormDialog> {
  final _physicalCashController = TextEditingController();
  final _notesController = TextEditingController();
  double _difference = 0.0;

  @override
  void initState() {
    super.initState();
    _difference =
        -widget.systemBalance; // Inicialmente la diferencia es todo el balance
  }

  void _calculateDifference(String value) {
    final physical = double.tryParse(value) ?? 0.0;
    setState(() {
      _difference = physical - widget.systemBalance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cierre de Caja Diario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Ingresos Sistema:',
              '\$${widget.totalIngresos.toStringAsFixed(2)}',
              Colors.green,
            ),
            _buildInfoRow(
              'Egresos Sistema:',
              '\$${widget.totalEgresos.toStringAsFixed(2)}',
              Colors.red,
            ),
            const Divider(),
            _buildInfoRow(
              'Balance Esperado:',
              '\$${widget.systemBalance.toStringAsFixed(2)}',
              AppColors.primaryBlue,
              isBold: true,
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _physicalCashController,
              decoration: const InputDecoration(
                labelText: 'Efectivo Físico / Contado',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                helperText: 'Ingrese la cantidad de dinero real en caja.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _calculateDifference,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_difference.abs() < 0.01 ? Colors.green : Colors.orange)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _difference.abs() < 0.01
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _difference.abs() < 0.01
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _difference.abs() < 0.01
                          ? 'Caja cuadrada correctamente.'
                          : 'Diferencia de \$${_difference.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _difference.abs() < 0.01
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas / Observaciones',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitClosure,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmar Cierre'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitClosure() async {
    final physical = double.tryParse(_physicalCashController.text) ?? 0.0;
    final user = FirebaseAuth.instance.currentUser;

    final closure = DailyClosureModel(
      id: '', // Firestore genera ID
      date: DateTime.now(),
      totalIngresos: widget.totalIngresos,
      totalEgresos: widget.totalEgresos,
      balanceSistema: widget.systemBalance,
      efectivoFisico: physical,
      diferencia: _difference,
      notes: _notesController.text.trim(),
      closedBy: user?.email ?? 'Unknown',
    );

    try {
      await ref.read(accountingServiceProvider).saveClosure(closure);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cierre de caja guardado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
