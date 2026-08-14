import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/features/admin/models/report_models.dart';
import 'package:tscomputer/features/admin/services/report_data_service.dart';
import 'package:tscomputer/core/widgets/cart_badge.dart';
import 'package:intl/intl.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  int _selectedTab = 0;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  ValidatedReportData? _reportData;
  bool _isLoading = false;
  String? _error;

  final ReportDataService _reportService = ReportDataService();


  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _reportService.generateReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) setState(() { _reportData = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      _loadReport();
    }
  }

  String get _periodLabel {
    final fmt = DateFormat('dd/MM/yyyy');
    return '${fmt.format(_startDate)} - ${fmt.format(_endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Por favor, inicie sesión.')));
    }
    final roleAsync = ref.watch(userRoleProvider(user.uid));

    return roleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (userRole) => _buildPage(userRole),
    );
  }

  Widget _buildPage(String userRole) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/main');
            }
          },
        ),
        title: const Text('Dashboard Inteligente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'Seleccionar período',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'Actualizar datos',
          ),
          const CartBadge(),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _isLoading ? const LinearProgressIndicator() : const SizedBox.shrink(),
        ),
      ),
      body: _error != null
          ? _buildError()
          : _reportData == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(userRole),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('Error al cargar datos', style: TextStyle(fontSize: 18, color: Colors.red[700])),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String userRole) {
    final data = _reportData!;
    return Column(
      children: [
        _buildPeriodBanner(data),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _DashboardTab(data: data),
              _SalesTab(data: data, userRole: userRole),
              _ServicesTab(data: data, userRole: userRole),
              _FinancialTab(data: data, userRole: userRole),
              _InventoryTab(data: data),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodBanner(ValidatedReportData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.indigo.shade50,
      child: Row(
        children: [
          Icon(Icons.date_range, size: 16, color: Colors.indigo[700]),
          const SizedBox(width: 8),
          Text(_periodLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo[700])),
          const Spacer(),
          Text(
            'Generado: ${DateFormat('dd/MM HH:mm').format(data.generatedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (i) => setState(() => _selectedTab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Resumen'),
        NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Ventas'),
        NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Servicios'),
        NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: 'Finanzas'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 0: DASHBOARD PRINCIPAL
// ═══════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final ValidatedReportData data;
  const _DashboardTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrendInsight(data.trends),
          const SizedBox(height: 16),
          _buildKPIGrid(data.kpis),
          const SizedBox(height: 16),
          _buildAlertsSection(data.alerts),
          const SizedBox(height: 16),
          _buildMiniChart('Ventas Diarias', data.trends.dailySales, Colors.green),
          const SizedBox(height: 16),
          _buildMiniChart('Servicios Diarios', data.trends.dailyServices, Colors.blue),
          const SizedBox(height: 16),
          _buildTopItemsRow('Top Productos', data.topProducts, Colors.orange),
          const SizedBox(height: 16),
          _buildTopItemsRow('Top Servicios', data.topServices, Colors.indigo),
          if (data.technicians.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTechnicianRanking(data.technicians),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendInsight(TrendAnalysis trends) {
    final color = trends.trendDirection == 'up'
        ? Colors.green
        : trends.trendDirection == 'down'
            ? Colors.red
            : Colors.orange;
    final icon = trends.trendDirection == 'up'
        ? Icons.trending_up
        : trends.trendDirection == 'down'
            ? Icons.trending_down
            : Icons.trending_flat;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade50, Colors.white]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Análisis del Período', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color.shade800)),
                const SizedBox(height: 4),
                Text(trends.insight, style: TextStyle(fontSize: 13, color: color.shade700)),
                const SizedBox(height: 4),
                Text(
                  'Ventas: ${trends.salesGrowthPct >= 0 ? '+' : ''}${trends.salesGrowthPct.toStringAsFixed(1)}%  |  Servicios: ${trends.servicesGrowthPct >= 0 ? '+' : ''}${trends.servicesGrowthPct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid(BusinessKPIs kpis) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 900
            ? 6
            : constraints.maxWidth > 600
                ? 4
                : 3;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _kpiCard(Icons.attach_money, 'Ventas', '\$${kpis.totalSales.toStringAsFixed(0)}', Colors.green),
            _kpiCard(Icons.build, 'Servicios', '\$${kpis.totalServices.toStringAsFixed(0)}', Colors.blue),
            _kpiCard(Icons.receipt_long, 'Ticket Prom.', '\$${kpis.avgTicket.toStringAsFixed(0)}', Colors.purple),
            _kpiCard(Icons.check_circle, 'Completados', '${kpis.completedCount}', Colors.teal, subtitle: '${kpis.conversionRate.toStringAsFixed(0)}% conversión'),
            _kpiCard(Icons.schedule, 'Pendientes', '${kpis.pendingCount}', Colors.orange),
            _kpiCard(Icons.cancel, 'Cancelados', '${kpis.cancelledCount}', Colors.red),
          ],
        );
      },
    );
  }

  Widget _kpiCard(IconData icon, String label, String value, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(List<BusinessAlert> alerts) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 10),
            Text('Todo en orden — sin alertas activas', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
            const SizedBox(width: 6),
            Text('Alertas (${alerts.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 8),
        ...alerts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _alertCard(a),
        )),
      ],
    );
  }

  Widget _alertCard(BusinessAlert alert) {
    final color = alert.severity == AlertSeverity.critical
        ? Colors.red
        : alert.severity == AlertSeverity.warning
            ? Colors.orange
            : Colors.blue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            alert.severity == AlertSeverity.critical ? Icons.error : alert.severity == AlertSeverity.warning ? Icons.warning : Icons.info,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color.shade800)),
                const SizedBox(height: 2),
                Text(alert.message, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart(String title, List<TimeSeriesPoint> points, Color color) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.take(14).map((p) {
                final height = maxVal > 0 ? (p.value / maxVal) * 70 : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height.clamp(2, 70),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: \$${points.fold(0.0, (s, p) => s + p.value).toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              Text('Promedio: \$${(points.fold(0.0, (s, p) => s + p.value) / points.length).toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopItemsRow(String title, List<TopItem> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.take(5).length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
                    const SizedBox(height: 4),
                    Text('\$${item.revenue.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                    Text('${item.quantity} unidades', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianRanking(List<TechnicianPerformance> techs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: Colors.indigo[700], size: 20),
            const SizedBox(width: 6),
            const Text('Rendimiento Técnicos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 8),
        ...techs.take(5).map((t) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo[100],
                child: Text(t.technicianName.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.technicianName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${t.completedServices}/${t.totalServices} completados', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${t.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                  Text('${t.completionRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1: ANÁLISIS DE VENTAS
// ═══════════════════════════════════════════════════════════════

class _SalesTab extends StatelessWidget {
  final ValidatedReportData data;
  final String userRole;
  const _SalesTab({required this.data, required this.userRole});

  @override
  Widget build(BuildContext context) {
    if (userRole == RoleService.TECHNICIAN) {
      return const Center(child: Text('Acceso Restringido: Solo Admin/Vendedor'));
    }
    final k = data.kpis;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Resumen de Ventas'),
          const SizedBox(height: 10),
          _buildSalesOverview(k),
          const SizedBox(height: 16),
          _sectionTitle('Distribución por Método de Pago'),
          const SizedBox(height: 10),
          _buildPaymentDistribution(k),
          const SizedBox(height: 16),
          _sectionTitle('Top 5 Productos Más Vendidos'),
          const SizedBox(height: 10),
          _buildTopProductsTable(data.topProducts),
          const SizedBox(height: 16),
          _sectionTitle('Flujo Diario de Ventas'),
          const SizedBox(height: 10),
          _buildDetailedChart(data.trends.dailySales, Colors.green, '\$'),
          const SizedBox(height: 16),
          _sectionTitle('Cuentas por Cobrar'),
          const SizedBox(height: 10),
          _buildReceivablesSummary(data.receivables),
        ],
      ),
    );
  }

  Widget _buildSalesOverview(BusinessKPIs kpis) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: Row(
        children: [
          _statBlock('Total Ventas', '\$${kpis.totalSales.toStringAsFixed(2)}', Colors.green),
          _statBlock('Efectivo', '\$${kpis.cashTotal.toStringAsFixed(0)}', Colors.green.shade700),
          _statBlock('Tarjeta', '\$${kpis.cardTotal.toStringAsFixed(0)}', Colors.blue),
          _statBlock('Transfer.', '\$${kpis.transferTotal.toStringAsFixed(0)}', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildPaymentDistribution(BusinessKPIs kpis) {
    final total = kpis.cashTotal + kpis.cardTotal + kpis.transferTotal;
    if (total == 0) return const Text('Sin datos de pago');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _paymentBar('Efectivo', kpis.cashTotal, total, Colors.green),
          const SizedBox(height: 8),
          _paymentBar('Tarjeta', kpis.cardTotal, total, Colors.blue),
          const SizedBox(height: 8),
          _paymentBar('Transferencia', kpis.transferTotal, total, Colors.purple),
        ],
      ),
    );
  }

  Widget _paymentBar(String label, double amount, double total, Color color) {
    final pct = total > 0 ? amount / total : 0.0;
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 18, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text('\$${amount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
        const SizedBox(width: 4),
        SizedBox(width: 40, child: Text('${(pct * 100).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
      ],
    );
  }

  Widget _buildTopProductsTable(List<TopItem> products) {
    if (products.isEmpty) return const Text('Sin datos de productos');
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _tableHeader(['Producto', 'Unid.', 'Ingreso']),
          ...products.take(5).map((p) => _tableRow([p.name, '${p.quantity}', '\$${p.revenue.toStringAsFixed(2)}'])),
        ],
      ),
    );
  }

  Widget _buildDetailedChart(List<TimeSeriesPoint> points, Color color, String prefix) {
    if (points.isEmpty) return const Text('Sin datos');
    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: points.take(14).map((p) {
            final height = maxVal > 0 ? (p.value / maxVal) * 110 : 0.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(prefix == '\$' ? p.value.toStringAsFixed(0) : p.value.toStringAsFixed(0), style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: '${DateFormat('dd/MM').format(p.date)}: $prefix${p.value.toStringAsFixed(2)}',
                    child: Container(
                      height: height.clamp(3, 110),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReceivablesSummary(ReceivablesSummary rec) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
      child: Column(
        children: [
          _infoLine('Total por Cobrar', '\$${rec.totalReceivables.toStringAsFixed(2)}', Colors.orange),
          _infoLine('Vencidas', '\$${rec.overdueAmount.toStringAsFixed(2)} (${rec.overdueCount})', Colors.red),
          _infoLine('Cobrado en Período', '\$${rec.paidThisPeriod.toStringAsFixed(2)}', Colors.green),
          if (rec.aging.isNotEmpty) ...[
            const Divider(),
            const Text('Antigüedad:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ...rec.aging.map((a) => _infoLine(a.period, '\$${a.amount.toStringAsFixed(2)}', Colors.orange)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 2: ANÁLISIS DE SERVICIOS
// ═══════════════════════════════════════════════════════════════

class _ServicesTab extends StatelessWidget {
  final ValidatedReportData data;
  final String userRole;
  const _ServicesTab({required this.data, required this.userRole});

  @override
  Widget build(BuildContext context) {
    if (userRole == RoleService.SELLER) {
      return const Center(child: Text('Acceso Restringido: Solo Admin/Técnico'));
    }
    final k = data.kpis;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Resumen de Servicios'),
          const SizedBox(height: 10),
          _buildServiceOverview(k),
          const SizedBox(height: 16),
          _sectionTitle('Top Servicios Más Solicitados'),
          const SizedBox(height: 10),
          _buildTopServicesTable(data.topServices),
          const SizedBox(height: 16),
          _sectionTitle('Rendimiento por Técnico'),
          const SizedBox(height: 10),
          ...data.technicians.map((t) => _buildTechnicianCard(t)),
          const SizedBox(height: 16),
          _sectionTitle('Flujo Diario de Servicios'),
          const SizedBox(height: 10),
          _buildDetailedChart(data.trends.dailyServices, Colors.blue, '\$'),
        ],
      ),
    );
  }

  Widget _buildServiceOverview(BusinessKPIs kpis) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
      child: Row(
        children: [
          _statBlock('Total Servicios', '\$${kpis.totalServices.toStringAsFixed(0)}', Colors.blue),
          _statBlock('Completados', '${kpis.completedCount}', Colors.green),
          _statBlock('Pendientes', '${kpis.pendingCount}', Colors.orange),
          _statBlock('Cancelados', '${kpis.cancelledCount}', Colors.red),
        ],
      ),
    );
  }

  Widget _buildTopServicesTable(List<TopItem> services) {
    if (services.isEmpty) return const Text('Sin datos de servicios');
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _tableHeader(['Servicio', 'Veces', 'Ingreso']),
          ...services.take(5).map((s) => _tableRow([s.name, '${s.quantity}', '\$${s.revenue.toStringAsFixed(2)}'])),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard(TechnicianPerformance tech) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.indigo[100],
                child: Text(tech.technicianName.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tech.technicianName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(tech.specialties.join(' • '), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${tech.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  Text('Ingresos totales', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _techMetric('Servicios', '${tech.completedServices}/${tech.totalServices}', Colors.blue),
              _techMetric('Tasa Éxito', '${tech.completionRate.toStringAsFixed(0)}%', Colors.green),
              _techMetric('Valor Prom.', '\$${tech.avgServiceValue.toStringAsFixed(0)}', Colors.purple),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: tech.completionRate / 100, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(tech.completionRate >= 80 ? Colors.green : tech.completionRate >= 50 ? Colors.orange : Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _techMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedChart(List<TimeSeriesPoint> points, Color color, String prefix) {
    if (points.isEmpty) return const Text('Sin datos');
    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: points.take(14).map((p) {
            final height = maxVal > 0 ? (p.value / maxVal) * 110 : 0.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(prefix == '\$' ? p.value.toStringAsFixed(0) : p.value.toStringAsFixed(0), style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: '${DateFormat('dd/MM').format(p.date)}: $prefix${p.value.toStringAsFixed(2)}',
                    child: Container(
                      height: height.clamp(3, 110),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 3: ANÁLISIS FINANCIERO
// ═══════════════════════════════════════════════════════════════

class _FinancialTab extends StatelessWidget {
  final ValidatedReportData data;
  final String userRole;
  const _FinancialTab({required this.data, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final acc = data.accounting;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Estado de Situación Financiera'),
          const SizedBox(height: 10),
          _buildBalanceSheet(acc),
          const SizedBox(height: 16),
          _sectionTitle('Resultado del Período'),
          const SizedBox(height: 10),
          _buildIncomeStatement(acc),
          const SizedBox(height: 16),
          _sectionTitle('Cuentas por Cobrar (CxC)'),
          const SizedBox(height: 10),
          _buildReceivablesDetail(data.receivables),
          const SizedBox(height: 16),
          _sectionTitle('Cuentas por Pagar (CxP)'),
          const SizedBox(height: 10),
          _buildPayablesDetail(data.payables),
        ],
      ),
    );
  }

  Widget _buildBalanceSheet(AccountingSummary acc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigo.shade200)),
      child: Column(
        children: [
          _infoLine('Activos (1.x)', '\$${acc.totalAssets.toStringAsFixed(2)}', Colors.indigo),
          _infoLine('Pasivos (2.x)', '\$${acc.totalLiabilities.toStringAsFixed(2)}', Colors.orange),
          _infoLine('Patrimonio (3.x)', '\$${acc.totalEquity.toStringAsFixed(2)}', Colors.green),
          const Divider(),
          _infoLine('Ecuación Contable', '', Colors.black, bold: true),
          Text('Activos = Pasivos + Patrimonio', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(
            '\$${acc.totalAssets.toStringAsFixed(2)} = \$${acc.totalLiabilities.toStringAsFixed(2)} + \$${acc.totalEquity.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: (acc.totalAssets - acc.totalLiabilities - acc.totalEquity).abs() < 0.01 ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeStatement(AccountingSummary acc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (acc.incomeByCategory.isNotEmpty) ...[
            const Text('Ingresos (4.x)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...acc.incomeByCategory.entries.map((e) => _infoLine(e.key, '\$${e.value.toStringAsFixed(2)}', Colors.green)),
            const Divider(),
          ],
          if (acc.expensesByCategory.isNotEmpty) ...[
            const Text('Gastos y Costos (5.x / 6.x)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...acc.expensesByCategory.entries.map((e) => _infoLine(e.key, '\$${e.value.toStringAsFixed(2)}', Colors.red)),
            const Divider(),
          ],
          _infoLine('Resultado Neto', '\$${acc.netIncome.toStringAsFixed(2)}', acc.netIncome >= 0 ? Colors.green : Colors.red, bold: true),
        ],
      ),
    );
  }

  Widget _buildReceivablesDetail(ReceivablesSummary rec) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
      child: Column(
        children: [
          _infoLine('Total Pendiente', '\$${rec.totalReceivables.toStringAsFixed(2)}', Colors.orange),
          _infoLine('Vencidas (>15 días)', '\$${rec.overdueAmount.toStringAsFixed(2)} (${rec.overdueCount} docs)', Colors.red),
          _infoLine('Cobrado en Período', '\$${rec.paidThisPeriod.toStringAsFixed(2)}', Colors.green),
          if (rec.aging.isNotEmpty) ...[
            const Divider(),
            const Text('Antigüedad de Cartera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            ...rec.aging.map((a) => _infoLine(a.period, '\$${a.amount.toStringAsFixed(2)}', Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _buildPayablesDetail(PayablesSummary pay) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
      child: Column(
        children: [
          _infoLine('Total Pendiente', '\$${pay.totalPayables.toStringAsFixed(2)}', Colors.red),
          _infoLine('Vencidas', '\$${pay.overdueAmount.toStringAsFixed(2)} (${pay.overdueCount} docs)', Colors.red.shade700),
          _infoLine('Pagado en Período', '\$${pay.paidThisPeriod.toStringAsFixed(2)}', Colors.green),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 4: INVENTARIO
// ═══════════════════════════════════════════════════════════════

class _InventoryTab extends StatelessWidget {
  final ValidatedReportData data;
  const _InventoryTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final inv = data.inventory;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Resumen de Inventario'),
          const SizedBox(height: 10),
          _buildInventoryOverview(inv),
          const SizedBox(height: 16),
          if (inv.topSelling.isNotEmpty) ...[
            _sectionTitle('Top 5 Productos (Mayor Valor)'),
            const SizedBox(height: 10),
            _buildProductsTable(inv.topSelling),
            const SizedBox(height: 16),
          ],
          if (inv.slowMoving.isNotEmpty) ...[
            _sectionTitle('Productos de Movimiento Lento'),
            const SizedBox(height: 10),
            _buildProductsTable(inv.slowMoving),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryOverview(InventorySummary inv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              _statBlock('Productos', '${inv.totalProducts}', Colors.teal),
              _statBlock('Valor Stock', '\$${inv.totalStockValue.toStringAsFixed(0)}', Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statBlock('Stock Bajo', '${inv.lowStockCount}', Colors.orange),
              _statBlock('Sin Stock', '${inv.outOfStockCount}', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(List<TopItem> products) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _tableHeader(['Producto', 'Stock', 'Precio', 'Margen']),
          ...products.map((p) => _tableRow([
            p.name,
            '${p.quantity}',
            '\$${p.revenue.toStringAsFixed(2)}',
            '${p.margin.toStringAsFixed(0)}%',
          ])),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WIDGETS COMPARTIDOS
// ═══════════════════════════════════════════════════════════════

Widget _sectionTitle(String title) {
  return Row(
    children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ],
  );
}

Widget _statBlock(String label, String value, Color color) {
  return Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    ),
  );
}

Widget _infoLine(String label, String value, Color color, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: Colors.grey[800])),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    ),
  );
}

Widget _tableHeader(List<String> headers) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
    child: Row(
      children: headers.map((h) => Expanded(
        child: Text(h, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      )).toList(),
    ),
  );
}

Widget _tableRow(List<String> cells) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
    child: Row(
      children: cells.map((c) => Expanded(
        child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      )).toList(),
    ),
  );
}