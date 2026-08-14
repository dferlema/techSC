import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/financial_report_service.dart';
import 'package:tscomputer/features/admin/services/pdf_report_service.dart';

class FinancialReportsPage extends ConsumerWidget {
  const FinancialReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Reportes Financieros'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
              ),
              child: TabBar(
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppColors.primaryBlue,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Balance General'),
                  Tab(text: 'Estado Resultados'),
                  Tab(text: 'Libro Mayor'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BalanceSheetView(),
                  _IncomeStatementView(),
                  _GeneralLedgerView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceSheetView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BalanceSheetView> createState() => _BalanceSheetViewState();
}

class _BalanceSheetViewState extends ConsumerState<_BalanceSheetView> {
  final _reportService = FinancialReportService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _reportService.getBalanceSheet(DateTime.now());
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_downloading || _data == null) return;
    setState(() => _downloading = true);
    try {
      await PdfReportService().generateBalanceSheetPDF(_data!, DateTime.now());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const Center(child: Text('Error al cargar balance'));

    final d = _data!;
    final activo = d['activo'] as double;
    final pasivo = d['pasivo'] as double;
    final patrimonio = d['patrimonio'] as double;
    final utilidad = d['utilidad'] as double;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Balance General', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      IconButton(
                        tooltip: 'Descargar PDF',
                        icon: _downloading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download, color: Colors.white, size: 20),
                        onPressed: _download,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section('ACTIVO', [
              _reportRow('Efectivo', d['efectivo'] as double),
              _reportRow('Cuentas por Cobrar', d['cuentasPorCobrar'] as double),
              _reportRow('Inventario', d['inventario'] as double),
            ], activo, Colors.blue),
            if ((d['detalleActivo'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              _detailSection('Desglose Activo', d['detalleActivo'] as List, Colors.blue),
            ],
            const SizedBox(height: 16),
            _section('PASIVO', [
              _reportRow('Cuentas por Pagar', d['cuentasPorPagar'] as double),
              _reportRow('IVA por Pagar', d['ivaPorPagar'] as double),
            ], pasivo, Colors.orange),
            if ((d['detallePasivo'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              _detailSection('Desglose Pasivo', d['detallePasivo'] as List, Colors.orange),
            ],
            const SizedBox(height: 16),
            _section('PATRIMONIO', [
              _reportRow('Capital', d['capital'] as double),
              _reportRow('Utilidad del Ejercicio', utilidad),
            ], patrimonio, Colors.green),
            if ((d['detallePatrimonio'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              _detailSection('Desglose Patrimonio', d['detallePatrimonio'] as List, Colors.green),
            ],
            const Divider(height: 24),
            Card(
              elevation: 0,
              color: Colors.purple.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL PASIVO + PATRIMONIO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800])),
                    Text('\$${(pasivo + patrimonio).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple[800])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeStatementView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_IncomeStatementView> createState() => _IncomeStatementViewState();
}

class _IncomeStatementViewState extends ConsumerState<_IncomeStatementView> {
  final _reportService = FinancialReportService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final data = await _reportService.getIncomeStatement(start, now);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_downloading || _data == null) return;
    setState(() => _downloading = true);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      await PdfReportService().generateIncomeStatementPDF(_data!, start, now);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const Center(child: Text('Error al cargar'));

    final d = _data!;
    final totalIngresos = d['totalIngresos'] as double;
    final totalGastos = d['totalGastos'] as double;
    final utilidad = d['utilidad'] as double;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[700]!, Colors.teal[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estado de Resultados', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      IconButton(
                        tooltip: 'Descargar PDF',
                        icon: _downloading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download, color: Colors.white, size: 20),
                        onPressed: _download,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Periodo actual', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INGRESOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 13)),
                  const SizedBox(height: 8),
                  _reportRow('Venta de Productos', d['ingresosVentas'] as double),
                  _reportRow('Servicios Técnicos', d['ingresosServicios'] as double),
                  _reportRow('Otros Ingresos', d['ingresosOtros'] as double),
                  const Divider(),
                  _reportRow('Total Ingresos', totalIngresos, isBold: true, color: Colors.green[800]),
                ],
              ),
            ),
            if ((d['detalleIngresos'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              _detailSection('Desglose de Ingresos', d['detalleIngresos'] as List, Colors.green),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GASTOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800], fontSize: 13)),
                  const SizedBox(height: 8),
                  _reportRow('Costo de Ventas (COGS)', d['gastosCogs'] as double),
                  _reportRow('Gastos de Personal', d['gastosPersonal'] as double),
                  _reportRow('Gastos Operativos', d['gastosOperativos'] as double),
                  _reportRow('Gastos Administrativos', d['gastosAdmin'] as double),
                  const Divider(),
                  _reportRow('Total Gastos', totalGastos, isBold: true, color: Colors.red[800]),
                ],
              ),
            ),
            if ((d['detalleGastos'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              _detailSection('Desglose de Gastos', d['detalleGastos'] as List, Colors.red),
            ],
            const Divider(height: 24),
            Card(
              elevation: 0,
              color: (utilidad >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('UTILIDAD / PÉRDIDA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: utilidad >= 0 ? Colors.green[800] : Colors.red[800])),
                    Text('\$${utilidad.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: utilidad >= 0 ? Colors.green[800] : Colors.red[800])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralLedgerView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GeneralLedgerView> createState() => _GeneralLedgerViewState();
}

class _GeneralLedgerViewState extends ConsumerState<_GeneralLedgerView> {
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final df = DateFormat('dd/MM/yyyy');

    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cuenta...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchTerm = ''); })
                    : null,
              ),
              onChanged: (v) => setState(() => _searchTerm = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (transactions) {
                final filtered = _searchTerm.isEmpty ? transactions : transactions.where((t) =>
                    t.category.toLowerCase().contains(_searchTerm) ||
                    t.description.toLowerCase().contains(_searchTerm)).toList();

                if (filtered.isEmpty) return const Center(child: Text('No se encontraron movimientos.'));

                double saldo = 0;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Fecha / Concepto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
                            Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                      );
                    }
                    if (index == filtered.length + 1) {
                      return Card(
                        elevation: 0,
                        color: AppColors.primaryBlue.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('SALDO FINAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
                              Text('\$${saldo.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                      color: saldo >= 0 ? Colors.green[700] : Colors.red[700])),
                            ],
                          ),
                        ),
                      );
                    }
                    final t = filtered[index - 1];
                    saldo += t.type == TransactionType.ingreso ? t.total : -t.total;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      elevation: 0,
                      color: Colors.grey.withValues(alpha: 0.03),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text('${df.format(t.date)}  ·  ${t.category}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Text(
                              '${t.type == TransactionType.ingreso ? "+" : "-"}\$${t.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: t.type == TransactionType.ingreso ? Colors.green[700] : Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _section(String title, List<Widget> rows, double total, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        const SizedBox(height: 8),
        ...rows,
        const Divider(),
        _reportRow('Total $title', total, isBold: true, color: color),
      ],
    ),
  );
}

Widget _detailSection(String title, List<dynamic> accounts, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
            Text('Cuentas del plan de cuentas', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in accounts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text('${item['code']}', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text('${item['name']}', style: const TextStyle(fontSize: 11)),
                ),
                Text(
                  '\$${((item['balance'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _reportRow(String label, double value, {bool isBold = false, Color? color, double fontSize = 13}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        Text('\$${value.toStringAsFixed(2)}', style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color ?? (value >= 0 ? Colors.green[700] : Colors.red[700]))),
      ],
    ),
  );
}
