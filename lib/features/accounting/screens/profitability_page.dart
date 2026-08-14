import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/services/ai_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/services/profitability_service.dart';

enum _SortMode { profit, margin, revenue, units }

class ProfitabilityPage extends ConsumerStatefulWidget {
  const ProfitabilityPage({super.key});

  @override
  ConsumerState<ProfitabilityPage> createState() => _ProfitabilityPageState();
}

class _ProfitabilityPageState extends ConsumerState<ProfitabilityPage> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  _SortMode _sortMode = _SortMode.profit;
  bool _ascending = false;
  bool _showOnlyWithSales = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductProfitability> _applyFilters(List<ProductProfitability> products) {
    var list = _showOnlyWithSales ? products.where((p) => p.unitsSold > 0).toList() : products.toList();

    if (_searchTerm.isNotEmpty) {
      list = list.where((p) =>
          p.name.toLowerCase().contains(_searchTerm) ||
          p.categoryName.toLowerCase().contains(_searchTerm)).toList();
    }

    double value(ProductProfitability p) => switch (_sortMode) {
          _SortMode.profit => p.profit,
          _SortMode.margin => p.marginPct,
          _SortMode.revenue => p.revenue,
          _SortMode.units => p.unitsSold.toDouble(),
        };

    list.sort((a, b) {
      final cmp = value(a).compareTo(value(b));
      return _ascending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(profitabilityReportProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Rentabilidad por Producto'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error al cargar rentabilidad'),
              const SizedBox(height: 8),
              Text('$err', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        data: (report) {
          final products = _applyFilters(report.products);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(profitabilityReportProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(report),
                const SizedBox(height: 16),
                _buildAiInsights(report),
                const SizedBox(height: 16),
                _buildFilters(report.products.length),
                const SizedBox(height: 8),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Sin resultados')),
                  )
                else
                  for (final p in products) _buildProductCard(p),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(ProfitabilityReport report) {
    return Row(
      children: [
        _summaryCard('Ingresos', '\$${report.totalRevenue.toStringAsFixed(2)}', Colors.green, Icons.trending_up, report),
        const SizedBox(width: 10),
        _summaryCard('Utilidad', '\$${report.totalProfit.toStringAsFixed(2)}', Colors.blue, Icons.savings, report),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon, ProfitabilityReport report) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(
              '${report.totalUnitsSold} unid · margen prom. ${report.avgMarginPct.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInsights(ProfitabilityReport report) {
    final insights = AiService().analyzeSales(report.products.map((p) => p.toMap()).toList());
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text('Análisis IA de ventas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
            ],
          ),
          const SizedBox(height: 10),
          for (final insight in insights.take(4)) _insightRow(insight),
        ],
      ),
    );
  }

  Widget _insightRow(SalesInsight insight) {
    final (icon, color) = switch (insight.type) {
      'alerta' => (Icons.warning_amber_rounded, Colors.orange[700]!),
      'oportunidad' => (Icons.lightbulb_outline, Colors.green[700]!),
      _ => (Icons.thumb_up_outlined, Colors.blue[700]!),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(insight.detail, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(int total) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar producto o categoría...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                    _searchController.clear();
                    setState(() => _searchTerm = '');
                  })
                : null,
          ),
          onChanged: (v) => setState(() => _searchTerm = v.toLowerCase()),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<_SortMode>(
                initialValue: _sortMode,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
                items: const [
                  DropdownMenuItem(value: _SortMode.profit, child: Text('Orden: Utilidad')),
                  DropdownMenuItem(value: _SortMode.margin, child: Text('Orden: Margen %')),
                  DropdownMenuItem(value: _SortMode.revenue, child: Text('Orden: Ingresos')),
                  DropdownMenuItem(value: _SortMode.units, child: Text('Orden: Unidades')),
                ],
                onChanged: (v) => setState(() => _sortMode = v ?? _SortMode.profit),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: _ascending ? 'Ascendente' : 'Descendente',
              icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 20),
              onPressed: () => setState(() => _ascending = !_ascending),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Con ventas'),
              selected: _showOnlyWithSales,
              onSelected: (v) => setState(() => _showOnlyWithSales = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductProfitability p) {
    final marginColor = p.marginPct >= 25
        ? Colors.green
        : p.marginPct >= 0
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(p.categoryName, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: marginColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${p.marginPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: marginColor)),
                    ),
                    const SizedBox(height: 2),
                    Text('\$${p.profit.toStringAsFixed(2)} util.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: marginColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (p.marginPct.clamp(0, 100)) / 100,
                minHeight: 5,
                backgroundColor: marginColor.withValues(alpha: 0.1),
                color: marginColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('Vendidos', '${p.unitsSold}'),
                const SizedBox(width: 16),
                _stat('Ingresos', '\$${p.revenue.toStringAsFixed(2)}'),
                const SizedBox(width: 16),
                _stat('Costo u.', '\$${p.unitCost.toStringAsFixed(2)}'),
                const SizedBox(width: 16),
                _stat('Stock', '${p.stock}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}
