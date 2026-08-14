import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/services/ai_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/service_profitability_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

class ServiceProfitabilityPage extends ConsumerStatefulWidget {
  const ServiceProfitabilityPage({super.key});

  @override
  ConsumerState<ServiceProfitabilityPage> createState() =>
      _ServiceProfitabilityPageState();
}

class _ServiceProfitabilityPageState
    extends ConsumerState<ServiceProfitabilityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(serviceProfitabilityReportProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Rentabilidad por Servicio'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Servicios'),
            Tab(text: 'Técnicos'),
            Tab(text: 'Tiempos'),
            Tab(text: 'Recurrentes'),
          ],
        ),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error al cargar rentabilidad'),
              const SizedBox(height: 8),
              Text('$err',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        data: (report) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(serviceProfitabilityReportProvider),
          child: Column(
            children: [
              _buildSummaryHeader(report),
              _buildAiInsights(report),
              _buildSearchBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildServicesTab(report),
                    _buildTechniciansTab(report),
                    _buildTimesTab(report),
                    _buildRecurringTab(report),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Summary Header ─────────────────────────────────────────────

  Widget _buildSummaryHeader(ServiceProfitabilityReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _kpiCard(
                  'Ingresos', '\$${report.totalRevenue.toStringAsFixed(0)}', Colors.green, Icons.trending_up),
              const SizedBox(width: 8),
              _kpiCard(
                  'Utilidad', '\$${report.totalProfit.toStringAsFixed(0)}', Colors.blue, Icons.savings),
              const SizedBox(width: 8),
              _kpiCard(
                  'Margen', '${report.avgMarginPct.toStringAsFixed(1)}%', AppColors.primaryBlue, Icons.percent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpiCard(
                  'Completados', '${report.totalCompleted}', Colors.teal, Icons.check_circle),
              const SizedBox(width: 8),
              _kpiCard(
                  'Total', '${report.totalServices}', Colors.orange, Icons.list),
              const SizedBox(width: 8),
              _kpiCard(
                  'Piezas',
                  '\$${report.totalPartsCost.toStringAsFixed(0)}',
                  Colors.red,
                  Icons.inventory_2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ─── AI Insights ────────────────────────────────────────────────

  Widget _buildAiInsights(ServiceProfitabilityReport report) {
    final insights = AiService().analyzeServiceProfitability(
      services: report.services.map((s) => s.toMap()).toList(),
      technicians: report.technicians.map((t) => t.toMap()).toList(),
      timeAnalysis: report.timeAnalysis
          .map((t) => {
                'name': t.serviceTypeName,
                'avgHours': t.avgHours,
                'medianHours': t.medianHours,
                'maxHours': t.maxHours,
              })
          .toList(),
      recurringIssues: report.recurringIssues
          .map((r) => {
                'device': r.device,
                'issue': r.issue,
                'count': r.count,
                'solutions': r.solutions,
              })
          .toList(),
    );

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text('Análisis IA de servicios',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primaryBlue)),
            ],
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                Text(insight.detail,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search ─────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar servicio o técnico...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchTerm = '');
                  })
              : null,
        ),
        onChanged: (v) => setState(() => _searchTerm = v.toLowerCase()),
      ),
    );
  }

  // ─── Tab 1: Services ───────────────────────────────────────────

  Widget _buildServicesTab(ServiceProfitabilityReport report) {
    var services = report.services;
    if (_searchTerm.isNotEmpty) {
      services = services
          .where((s) =>
              s.serviceTypeName.toLowerCase().contains(_searchTerm) ||
              s.serviceType.toLowerCase().contains(_searchTerm))
          .toList();
    }

    if (services.isEmpty) {
      return const Center(child: Text('Sin servicios para mostrar'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: services.length,
      itemBuilder: (ctx, i) => _buildServiceCard(services[i]),
    );
  }

  Widget _buildServiceCard(ServiceProfitability s) {
    final marginColor = s.marginPct >= 40
        ? Colors.green
        : s.marginPct >= 20
            ? Colors.orange
            : Colors.red;

    final topDevices = s.deviceBreakdown.entries.take(3).toList();

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
                      Text(s.serviceTypeName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                          '${s.completedServices}/${s.totalServices} completados',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: marginColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${s.marginPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: marginColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (s.marginPct.clamp(0, 100)) / 100,
                minHeight: 5,
                backgroundColor: marginColor.withValues(alpha: 0.1),
                color: marginColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('Ingresos', '\$${s.totalRevenue.toStringAsFixed(0)}'),
                const SizedBox(width: 14),
                _metric('Piezas', '\$${s.totalPartsCost.toStringAsFixed(0)}'),
                const SizedBox(width: 14),
                _metric('Mano obra', '\$${s.totalLaborRevenue.toStringAsFixed(0)}'),
                const SizedBox(width: 14),
                _metric('Tiempo', '${s.avgRepairTime.toStringAsFixed(1)}h'),
              ],
            ),
            if (topDevices.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: topDevices
                    .map((e) => Chip(
                          label: Text('${e.key} (${e.value})',
                              style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Tab 2: Technicians ────────────────────────────────────────

  Widget _buildTechniciansTab(ServiceProfitabilityReport report) {
    var techs = report.technicians;
    if (_searchTerm.isNotEmpty) {
      techs = techs
          .where((t) =>
              t.technicianName.toLowerCase().contains(_searchTerm))
          .toList();
    }

    if (techs.isEmpty) {
      return const Center(child: Text('Sin técnicos para mostrar'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: techs.length,
      itemBuilder: (ctx, i) => _buildTechCard(techs[i]),
    );
  }

  Widget _buildTechCard(TechnicianServiceStats t) {
    final marginColor = t.marginPct >= 40
        ? Colors.green
        : t.marginPct >= 20
            ? Colors.orange
            : Colors.red;

    final specialties = t.specialties.entries.take(3).toList();

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
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    t.technicianName.isNotEmpty
                        ? t.technicianName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.technicianName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                          '${t.completedServices}/${t.totalServices} completados · ${t.completionRate.toStringAsFixed(0)}%',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${t.totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${t.marginPct.toStringAsFixed(1)}% margen',
                        style: TextStyle(
                            fontSize: 10, color: marginColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('Costo prom.', '\$${t.avgRepairCost.toStringAsFixed(0)}'),
                const SizedBox(width: 14),
                _metric('Tiempo prom.', '${t.avgRepairTime.toStringAsFixed(1)}h'),
                const SizedBox(width: 14),
                _metric('Piezas', '\$${t.totalPartsCost.toStringAsFixed(0)}'),
              ],
            ),
            if (specialties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: specialties
                    .map((e) => Chip(
                          label: Text('${e.key} (${e.value})',
                              style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Tab 3: Times ──────────────────────────────────────────────

  Widget _buildTimesTab(ServiceProfitabilityReport report) {
    if (report.timeAnalysis.isEmpty) {
      return const Center(child: Text('Sin datos de tiempo disponibles'));
    }

    final maxHours = report.timeAnalysis
        .map((t) => t.avgHours)
        .reduce((a, b) => a > b ? a : b);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: report.timeAnalysis.length,
      itemBuilder: (ctx, i) {
        final t = report.timeAnalysis[i];
        return _buildTimeCard(t, maxHours);
      },
    );
  }

  Widget _buildTimeCard(ServiceTimeAnalysis t, double maxHours) {
    final barWidth = maxHours > 0 ? t.avgHours / maxHours : 0.0;

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
                Text(t.serviceTypeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${t.sampleSize} muestras',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barWidth.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metric('Promedio', '${t.avgHours.toStringAsFixed(1)}h'),
                const SizedBox(width: 14),
                _metric('Mediana', '${t.medianHours.toStringAsFixed(1)}h'),
                const SizedBox(width: 14),
                _metric('Mín', '${t.minHours.toStringAsFixed(1)}h'),
                const SizedBox(width: 14),
                _metric('Máx', '${t.maxHours.toStringAsFixed(1)}h'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 4: Recurring Issues ──────────────────────────────────

  Widget _buildRecurringTab(ServiceProfitabilityReport report) {
    if (report.recurringIssues.isEmpty) {
      return const Center(child: Text('Sin problemas recurrentes detectados'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: report.recurringIssues.length,
      itemBuilder: (ctx, i) => _buildRecurringCard(report.recurringIssues[i]),
    );
  }

  Widget _buildRecurringCard(RecurringIssue r) {
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
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${r.count}x',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.device,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(r.issue,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('\$${r.totalRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            if (r.solutions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Soluciones aplicadas:',
                  style:
                      TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 4),
              for (final sol in r.solutions.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(sol,
                            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Shared Widget ──────────────────────────────────────────────

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }
}
