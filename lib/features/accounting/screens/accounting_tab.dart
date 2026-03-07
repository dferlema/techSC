import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';
import 'package:techsc/features/accounting/models/transaction_model.dart';
import 'package:techsc/features/accounting/providers/accounting_providers.dart';
import 'package:techsc/features/accounting/widgets/closure_form_dialog.dart';

/// Pestaña principal de Contabilidad para el Panel de Administración.
///
/// Muestra un resumen financiero, una lista de transacciones recientes
/// y permite filtrar por rangos de fecha.
class AccountingTab extends ConsumerWidget {
  const AccountingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final dateRange = ref.watch(accountingDateRangeProvider);

    return Column(
      children: [
        _buildHeader(context, ref, dateRange),
        _buildSummaryCards(context, ref, transactionsAsync),
        _buildSRISection(transactionsAsync),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(),
        ),
        Expanded(
          child: transactionsAsync.when(
            data: (transactions) =>
                _buildTransactionList(context, ref, transactions),
            loading: () => const AppLoadingIndicator(),
            error: (err, _) => AppErrorWidget(error: err),
          ),
        ),
      ],
    );
  }

  /// Construye la cabecera con el selector de fechas.
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange range,
  ) {
    final df = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Movimientos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton.icon(
            onPressed: () => _selectDateRange(context, ref, range),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('${df.format(range.start)} - ${df.format(range.end)}'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
          ),
        ],
      ),
    );
  }

  /// Diálogo para seleccionar el rango de fechas de los reportes.
  Future<void> _selectDateRange(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange currentRange,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      ref.read(accountingDateRangeProvider.notifier).state = picked;
    }
  }

  /// Construye tarjetas de resumen (Ingresos, Egresos, IVA por pagar, Utilidad).
  Widget _buildSummaryCards(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TransactionModel>> transactionsAsync,
  ) {
    return transactionsAsync.maybeWhen(
      data: (transactions) {
        double ingresosVentas = 0;
        double ingresosOtros = 0;
        double egresos = 0;
        double ivaVentas = 0;
        double ivaCompras = 0;

        for (var t in transactions) {
          if (t.type == TransactionType.ingreso) {
            if (t.category == 'Venta' || t.category == 'Servicio') {
              ingresosVentas += t.amount; // Subtotal
            } else {
              ingresosOtros += t.amount;
            }
            ivaVentas += t.vatAmount;
          } else {
            egresos += t.amount;
            ivaCompras += t.vatAmount;
          }
        }

        final utilidadBruta = (ingresosVentas + ingresosOtros) - egresos;
        final ivaPorPagar = ivaVentas - ivaCompras;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildSummaryItem(
                    'Ingresos',
                    ingresosVentas + ingresosOtros + ivaVentas,
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryItem('Gastos', egresos + ivaCompras, Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSummaryItem(
                    'IVA por Pagar',
                    ivaPorPagar,
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryItem(
                    'Utilidad (S.T)',
                    utilidadBruta,
                    AppColors.primaryBlue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Botón de Cierre de Caja
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showClosureDialog(
                    context,
                    ingresosVentas + ingresosOtros + ivaVentas,
                    egresos + ivaCompras,
                  ),
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Realizar Cierre de Caja'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                '\$${value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sección colapsable con el resumen tributario para el SRI (Formulario 104).
  Widget _buildSRISection(
    AsyncValue<List<TransactionModel>> transactionsAsync,
  ) {
    return transactionsAsync.maybeWhen(
      data: (transactions) {
        double baseIva0Ventas = 0;
        double baseIva15Ventas = 0;
        double ivaVentas = 0;
        double baseIva0Compras = 0;
        double baseIva15Compras = 0;
        double ivaCompras = 0;

        for (var t in transactions) {
          if (t.type == TransactionType.ingreso) {
            if (t.vatRate == 0) {
              baseIva0Ventas += t.amount;
            } else {
              baseIva15Ventas += t.amount;
            }
            ivaVentas += t.vatAmount;
          } else {
            if (t.vatRate == 0) {
              baseIva0Compras += t.amount;
            } else {
              baseIva15Compras += t.amount;
            }
            ivaCompras += t.vatAmount;
          }
        }

        final ivaPorPagar = ivaVentas - ivaCompras;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: Icon(
                Icons.account_balance,
                color: AppColors.primaryBlue,
              ),
              title: const Text(
                'Resumen SRI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'IVA a pagar: \$${ivaPorPagar.toStringAsFixed(2)}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'VENTAS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _sriRow('Base Imponible 0%', baseIva0Ventas),
                      _sriRow('Base Imponible 15%', baseIva15Ventas),
                      _sriRow('IVA Generado', ivaVentas),
                      const Divider(height: 20),
                      const Text(
                        'COMPRAS / GASTOS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _sriRow('Base Imponible 0%', baseIva0Compras),
                      _sriRow('Base Imponible 15%', baseIva15Compras),
                      _sriRow('Crédito Tributario (IVA)', ivaCompras),
                      const Divider(height: 20),
                      _sriRow(
                        'IVA por Pagar (F.104)',
                        ivaPorPagar,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Fila helper para el resumen tributario SRI.
  Widget _sriRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.primaryBlue : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la lista de transacciones.
  Widget _buildTransactionList(
    BuildContext context,
    WidgetRef ref,
    List<TransactionModel> transactions,
  ) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No hay transacciones en este periodo.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[index];
        final isIngreso = t.type == TransactionType.ingreso;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (isIngreso ? Colors.green : Colors.red)
                  .withAlpha(30),
              child: Icon(
                isIngreso ? Icons.add_chart : Icons.shopping_bag_outlined,
                color: isIngreso ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              t.category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy').format(t.date)} - ${t.description}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIngreso ? "+" : "-"}\$${t.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIngreso ? Colors.green : Colors.red,
                    fontSize: 15,
                  ),
                ),
                if (t.vatAmount > 0)
                  Text(
                    'IVA: \$${t.vatAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            onLongPress: () => _confirmDelete(context, ref, t),
          ),
        );
      },
    );
  }

  /// Muestra el diálogo para el cierre de caja.
  void _showClosureDialog(
    BuildContext context,
    double totalIn,
    double totalOut,
  ) {
    showDialog(
      context: context,
      builder: (context) => ClosureFormDialog(
        totalIngresos: totalIn,
        totalEgresos: totalOut,
        systemBalance: totalIn - totalOut,
      ),
    );
  }

  /// Confirmación para eliminar una transacción.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionModel t,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Transacción'),
        content: const Text(
          '¿Estás seguro de eliminar este registro contable?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(accountingServiceProvider).deleteTransaction(t.id);
    }
  }
}
