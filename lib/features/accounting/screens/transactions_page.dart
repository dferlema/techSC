import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'package:tscomputer/core/widgets/app_error_widget.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/closure_form_dialog.dart';
import 'package:tscomputer/features/accounting/widgets/transaction_form_dialog.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Movimientos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _TransactionsBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const TransactionFormDialog(),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TransactionsBody extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TransactionsBody> createState() => _TransactionsBodyState();
}

class _TransactionsBodyState extends ConsumerState<_TransactionsBody> {
  @override
  Widget build(BuildContext context) {
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
            data: (transactions) => _buildTransactionList(context, ref, transactions),
            loading: () => const AppLoadingIndicator(),
            error: (err, _) => AppErrorWidget(error: err, onRetry: () => _onRetry(ref)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, DateTimeRange range) {
    final df = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Resumen de Movimientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sincronizar Ventas e Inventario',
                color: AppColors.primaryBlue,
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronizando...'), duration: Duration(seconds: 2)),
                  );
                  final count = await ref.read(accountingServiceProvider).syncPastSalesToAccounting();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count > 0 ? '$count movimiento(s) sincronizado(s)' : 'Todos al día'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
              TextButton.icon(
                onPressed: () => _selectDateRange(context, ref, range),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('${df.format(range.start)} - ${df.format(range.end)}'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref, DateTimeRange currentRange) async {
    final picked = await showDateRangePicker(
      context: context, initialDateRange: currentRange, firstDate: DateTime(2022), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) ref.read(accountingDateRangeProvider.notifier).state = picked;
  }

  void _onRetry(WidgetRef ref) => ref.invalidate(transactionsStreamProvider);

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref, AsyncValue<List<TransactionModel>> transactionsAsync) {
    return transactionsAsync.when(
      loading: () => const SizedBox(height: 200, child: AppLoadingIndicator()),
      error: (err, _) => SizedBox(height: 200, child: AppErrorWidget(error: err, message: 'Error al cargar datos', onRetry: () => _onRetry(ref))),
      data: (transactions) {
        double ingresosVentas = 0, ingresosOtros = 0, egresos = 0, ivaVentas = 0;
        for (var t in transactions) {
          if (t.type == TransactionType.ingreso) {
            if (t.category == 'Venta' || t.category == 'Servicio') ingresosVentas += t.amount;
            else ingresosOtros += t.amount;
            ivaVentas += t.vatAmount;
          } else {
            // RIMPE: el IVA de compras se capitaliza al costo → el egreso real es el total.
            egresos += t.total;
          }
        }
        final utilidadBruta = (ingresosVentas + ingresosOtros) - egresos;
        // RIMPE (negocio popular): el IVA de compras NO es acreditable.
        // El IVA a pagar es únicamente el IVA generado en las ventas (0%).
        final ivaPorPagar = ivaVentas;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildSummaryItem('Ingresos', ingresosVentas + ingresosOtros + ivaVentas, Colors.green),
                  const SizedBox(width: 12),
                  _buildSummaryItem('Gastos', egresos, Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSummaryItem('IVA por Pagar', ivaPorPagar, Colors.orange),
                  const SizedBox(width: 12),
                  _buildSummaryItem('Utilidad (S.T)', utilidadBruta, AppColors.primaryBlue),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showClosureDialog(context, ingresosVentas + ingresosOtros + ivaVentas, egresos),
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Realizar Cierre de Caja'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(child: Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
        ]),
      ),
    );
  }

  Widget _buildSRISection(AsyncValue<List<TransactionModel>> transactionsAsync) {
    return transactionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (transactions) {
        double baseIva0Ventas = 0, baseIva15Ventas = 0, ivaVentas = 0;
        double baseIva0Compras = 0, baseIva15Compras = 0, ivaCompras = 0;
        for (var t in transactions) {
          final conIva = t.vatAmount > 0;
          if (t.type == TransactionType.ingreso) {
            if (conIva) baseIva15Ventas += t.amount;
            else baseIva0Ventas += t.amount;
            ivaVentas += t.vatAmount;
          } else {
            if (conIva) baseIva15Compras += t.amount;
            else baseIva0Compras += t.amount;
            ivaCompras += t.vatAmount;
          }
        }
        // RIMPE (negocio popular): el IVA de compras NO es acreditable.
        // El IVA a pagar es únicamente el IVA generado en las ventas.
        final ivaPorPagar = ivaVentas;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(Icons.account_balance, color: AppColors.primaryBlue),
              title: const Text('Resumen SRI', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('IVA a pagar: \$${ivaPorPagar.toStringAsFixed(2)}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('VENTAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      _sriRow('Base Imponible 0%', baseIva0Ventas),
                      _sriRow('Base Imponible 15%', baseIva15Ventas),
                      _sriRow('IVA Generado', ivaVentas),
                      const Divider(height: 20),
                      const Text('COMPRAS / GASTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      _sriRow('Base Imponible 0%', baseIva0Compras),
                      _sriRow('Base Imponible 15%', baseIva15Compras),
                      _sriRow('IVA en Compras (no acreditable)', ivaCompras),
                      const Divider(height: 20),
                      _sriRow('IVA por Pagar (F.104)', ivaPorPagar, isBold: true),
                      const SizedBox(height: 8),
                      const Text(
                        'Nota: Negocio popular RIMPE. El IVA de compras se capitaliza al costo y no genera crédito tributario.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sriRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? AppColors.primaryBlue : null)),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, WidgetRef ref, List<TransactionModel> transactions) {
    if (transactions.isEmpty) return const Center(child: Text('No hay transacciones en este periodo.'));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(transactionsStreamProvider),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];
          final isIngreso = t.type == TransactionType.ingreso;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (isIngreso ? Colors.green : Colors.red).withValues(alpha: 0.12),
                child: Icon(isIngreso ? Icons.add_chart : Icons.shopping_bag_outlined, color: isIngreso ? Colors.green : Colors.red),
              ),
              title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${DateFormat('dd/MM/yyyy').format(t.date)} - ${t.description}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isIngreso ? "+" : "-"}\$${t.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: isIngreso ? Colors.green : Colors.red, fontSize: 15)),
                  if (t.vatAmount > 0) Text('IVA: \$${t.vatAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              onLongPress: () => _confirmDelete(context, ref, t),
            ),
          );
        },
      ),
    );
  }

  void _showClosureDialog(BuildContext context, double totalIn, double totalOut) {
    showDialog(context: context, builder: (context) => ClosureFormDialog(totalIngresos: totalIn, totalEgresos: totalOut, systemBalance: totalIn - totalOut));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, TransactionModel t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Transacción'),
        content: const Text('¿Estás seguro de eliminar este registro contable?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) await ref.read(accountingServiceProvider).deleteTransaction(t.id);
  }
}
