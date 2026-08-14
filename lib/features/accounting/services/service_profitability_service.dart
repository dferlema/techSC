import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/features/accounting/models/service_profitability_model.dart';

/// Servicio de rentabilidad por servicio técnico.
///
/// Calcula métricas de rentabilidad basadas en las reservaciones reales
/// completadas, incluyendo costo de piezas vs mano de obra, rendimiento
/// de técnicos, análisis de tiempos y problemas recurrentes.
class ServiceProfitabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _reservationsCollection = 'reservations';
  static const _productsCollection = 'products';
  static const _usersCollection = 'users';

  static const _completedStatuses = [
    'completado',
    'entregado',
    'completed',
    'delivered',
  ];

  /// Genera el reporte completo de rentabilidad por servicio.
  Future<ServiceProfitabilityReport> getReport({DateTime? since}) async {
    final results = await Future.wait([
      _loadReservations(since),
      _loadProducts(),
    ]);

    final reservations = results[0] as List<Map<String, dynamic>>;
    final productCosts = results[1] as Map<String, double>;

    final technicianNames = await _loadTechnicianNames(reservations);

    final services = _computeByServiceType(reservations, productCosts);
    final technicians = _computeByTechnician(reservations, productCosts, technicianNames);
    final timeAnalysis = _computeTimeAnalysis(reservations);
    final recurringIssues = _computeRecurringIssues(reservations);

    final totalRevenue = services.fold(0.0, (a, s) => a + s.totalRevenue);
    final totalPartsCost = services.fold(0.0, (a, s) => a + s.totalPartsCost);
    final totalProfit = totalRevenue - totalPartsCost;
    final avgMargin = totalRevenue > 0 ? totalProfit / totalRevenue * 100 : 0.0;
    final totalCompleted = services.fold(0, (a, s) => a + s.completedServices);
    final totalServicesCount = services.fold(0, (a, s) => a + s.totalServices);

    return ServiceProfitabilityReport(
      services: services,
      technicians: technicians,
      timeAnalysis: timeAnalysis,
      recurringIssues: recurringIssues,
      totalRevenue: totalRevenue,
      totalPartsCost: totalPartsCost,
      totalProfit: totalProfit,
      avgMarginPct: avgMargin,
      totalCompleted: totalCompleted,
      totalServices: totalServicesCount,
    );
  }

  // ─── Data Loading ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _loadReservations(DateTime? since) async {
    Query query = _firestore.collection(_reservationsCollection);
    if (since != null) {
      query = query.where('scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  Future<Map<String, double>> _loadProducts() async {
    final snap = await _firestore.collection(_productsCollection).get();
    final costs = <String, double>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final costWithTax = (data['purchaseCostWithTax'] as num?)?.toDouble();
      final cost = (data['purchaseCost'] as num?)?.toDouble();
      final finalCost = costWithTax ?? (cost != null ? cost * 1.15 : 0.0);
      costs[doc.id] = finalCost;
    }
    return costs;
  }

  Future<Map<String, String>> _loadTechnicianNames(
      List<Map<String, dynamic>> reservations) async {
    final ids = <String>{};
    for (final r in reservations) {
      final tid = r['technicianId'] as String? ?? '';
      if (tid.isNotEmpty) ids.add(tid);
    }

    final names = <String, String>{};
    for (final id in ids) {
      try {
        final doc = await _firestore.collection(_usersCollection).doc(id).get();
        if (doc.exists) {
          final data = doc.data();
          names[id] = data?['name'] as String? ??
              data?['displayName'] as String? ??
              id;
        } else {
          names[id] = id;
        }
      } catch (_) {
        names[id] = id;
      }
    }
    return names;
  }

  // ─── Computation by Service Type ───────────────────────────────

  List<ServiceProfitability> _computeByServiceType(
    List<Map<String, dynamic>> reservations,
    Map<String, double> productCosts,
  ) {
    final byType = <String, _ServiceAggregator>{};

    for (final r in reservations) {
      final type = (r['serviceType'] as String? ?? 'desconocido').toLowerCase();
      byType.putIfAbsent(type, () => _ServiceAggregator(type));

      final agg = byType[type]!;
      agg.totalServices++;

      final status = (r['status'] as String? ?? '').toLowerCase();
      final isCompleted = _completedStatuses.contains(status);
      if (isCompleted) agg.completedServices++;

      final repairCost = (r['repairCost'] as num?)?.toDouble() ?? 0.0;
      agg.totalRevenue += repairCost;
      agg.totalRepairCost += repairCost;

      if (isCompleted) {
        final partsCost = _computePartsCost(r, productCosts);
        agg.totalPartsCost += partsCost;
        agg.completedRevenue += repairCost;

        final time = _computeRepairTime(r);
        if (time != null) {
          agg.repairTimes.add(time);
        }
      }

      final device = (r['device'] as String? ?? 'otro').toLowerCase();
      agg.deviceBreakdown[device] = (agg.deviceBreakdown[device] ?? 0) + 1;
    }

    final results = <ServiceProfitability>[];
    for (final agg in byType.values) {
      final laborRevenue =
          agg.completedRevenue - agg.totalPartsCost;
      final margin =
          agg.completedRevenue > 0 ? laborRevenue / agg.completedRevenue * 100 : 0.0;
      final avgTime = agg.repairTimes.isNotEmpty
          ? agg.repairTimes.reduce((a, b) => a + b) / agg.repairTimes.length
          : 0.0;

      results.add(ServiceProfitability(
        serviceType: agg.type,
        serviceTypeName: _serviceDisplayName(agg.type),
        totalServices: agg.totalServices,
        completedServices: agg.completedServices,
        totalRevenue: agg.completedRevenue,
        totalPartsCost: agg.totalPartsCost,
        totalLaborRevenue: laborRevenue,
        avgRepairTime: avgTime,
        avgRepairCost:
            agg.completedServices > 0 ? agg.completedRevenue / agg.completedServices : 0,
        marginPct: margin,
        completionRate:
            agg.totalServices > 0 ? agg.completedServices / agg.totalServices * 100 : 0,
        deviceBreakdown: Map.fromEntries(
          agg.deviceBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
        ),
      ));
    }

    results.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return results;
  }

  // ─── Computation by Technician ─────────────────────────────────

  List<TechnicianServiceStats> _computeByTechnician(
    List<Map<String, dynamic>> reservations,
    Map<String, double> productCosts,
    Map<String, String> technicianNames,
  ) {
    final byTech = <String, _TechAggregator>{};

    for (final r in reservations) {
      final tid = r['technicianId'] as String? ?? '';
      if (tid.isEmpty) continue;

      byTech.putIfAbsent(tid, () => _TechAggregator(tid));
      final agg = byTech[tid]!;
      agg.totalServices++;

      final status = (r['status'] as String? ?? '').toLowerCase();
      final isCompleted = _completedStatuses.contains(status);
      if (isCompleted) agg.completedServices++;

      final repairCost = (r['repairCost'] as num?)?.toDouble() ?? 0.0;
      agg.totalRevenue += repairCost;

      if (isCompleted) {
        agg.totalPartsCost += _computePartsCost(r, productCosts);

        final time = _computeRepairTime(r);
        if (time != null) agg.repairTimes.add(time);

        final type = (r['serviceType'] as String? ?? 'otro').toLowerCase();
        agg.specialties[type] = (agg.specialties[type] ?? 0) + 1;
      }
    }

    final results = <TechnicianServiceStats>[];
    for (final agg in byTech.values) {
      final avgTime = agg.repairTimes.isNotEmpty
          ? agg.repairTimes.reduce((a, b) => a + b) / agg.repairTimes.length
          : 0.0;

      final sortedSpecialties = Map.fromEntries(
        agg.specialties.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      );

      results.add(TechnicianServiceStats(
        technicianId: agg.id,
        technicianName: technicianNames[agg.id] ?? agg.id,
        completedServices: agg.completedServices,
        totalServices: agg.totalServices,
        totalRevenue: agg.totalRevenue,
        totalPartsCost: agg.totalPartsCost,
        avgRepairCost: agg.completedServices > 0
            ? agg.totalRevenue / agg.completedServices
            : 0,
        avgRepairTime: avgTime,
        completionRate: agg.totalServices > 0
            ? agg.completedServices / agg.totalServices * 100
            : 0,
        specialties: sortedSpecialties,
      ));
    }

    results.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return results;
  }

  // ─── Time Analysis ─────────────────────────────────────────────

  List<ServiceTimeAnalysis> _computeTimeAnalysis(
    List<Map<String, dynamic>> reservations,
  ) {
    final byType = <String, List<double>>{};

    for (final r in reservations) {
      final status = (r['status'] as String? ?? '').toLowerCase();
      if (!_completedStatuses.contains(status)) continue;

      final time = _computeRepairTime(r);
      if (time == null || time <= 0) continue;

      final type = (r['serviceType'] as String? ?? 'desconocido').toLowerCase();
      byType.putIfAbsent(type, () => []);
      byType[type]!.add(time);
    }

    final results = <ServiceTimeAnalysis>[];
    for (final entry in byType.entries) {
      final times = entry.value..sort();
      final avg = times.reduce((a, b) => a + b) / times.length;
      final median = times.length % 2 == 0
          ? (times[times.length ~/ 2 - 1] + times[times.length ~/ 2]) / 2
          : times[times.length ~/ 2];

      results.add(ServiceTimeAnalysis(
        serviceType: entry.key,
        serviceTypeName: _serviceDisplayName(entry.key),
        avgHours: avg,
        medianHours: median,
        minHours: times.first,
        maxHours: times.last,
        sampleSize: times.length,
      ));
    }

    results.sort((a, b) => b.avgHours.compareTo(a.avgHours));
    return results;
  }

  // ─── Recurring Issues ──────────────────────────────────────────

  List<RecurringIssue> _computeRecurringIssues(
    List<Map<String, dynamic>> reservations,
  ) {
    final issueMap = <String, _IssueAggregator>{};

    for (final r in reservations) {
      final device = (r['device'] as String? ?? 'otro').toLowerCase();
      final description = (r['description'] as String? ?? '').toLowerCase();
      if (description.isEmpty) continue;

      final words = description.split(RegExp(r'\s+')).take(5).join(' ');
      final key = '$device|||$words';

      issueMap.putIfAbsent(key, () => _IssueAggregator(device, words));
      final agg = issueMap[key]!;
      agg.count++;

      final repairCost = (r['repairCost'] as num?)?.toDouble() ?? 0.0;
      agg.totalRevenue += repairCost;

      final solution = (r['solution'] as String? ?? '').trim();
      if (solution.isNotEmpty && !agg.solutions.contains(solution)) {
        agg.solutions.add(solution);
      }
    }

    final results = issueMap.values
        .where((a) => a.count >= 2)
        .map((a) => RecurringIssue(
              device: a.device,
              issue: a.issue,
              count: a.count,
              totalRevenue: a.totalRevenue,
              solutions: a.solutions,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return results.take(15).toList();
  }

  // ─── Helpers ───────────────────────────────────────────────────

  double _computePartsCost(
      Map<String, dynamic> r, Map<String, double> productCosts) {
    final partsData = r['partsData'] as List<dynamic>?;
    if (partsData == null || partsData.isEmpty) return 0.0;

    double total = 0;
    for (final part in partsData) {
      final map = part as Map<String, dynamic>;
      final productId = map['productId'] as String? ?? '';
      final qty = (map['quantity'] as num?)?.toInt() ?? 1;

      if (productId.isNotEmpty && productCosts.containsKey(productId)) {
        total += productCosts[productId]! * qty;
      } else {
        final cost = (map['cost'] as num?)?.toDouble() ??
            (map['price'] as num?)?.toDouble() ??
            0.0;
        total += cost * qty;
      }
    }
    return total;
  }

  double? _computeRepairTime(Map<String, dynamic> r) {
    final createdAt = r['createdAt'] as Timestamp?;
    final scheduledDate = r['scheduledDate'] as Timestamp?;
    if (createdAt == null || scheduledDate == null) return null;

    final start = createdAt.toDate();
    final end = scheduledDate.toDate();
    final diff = end.difference(start);
    return diff.inMinutes / 60.0;
  }

  String _serviceDisplayName(String type) {
    const names = {
      'reparacion laptop': 'Reparación Laptop',
      'reparacion de laptop': 'Reparación Laptop',
      'reparacion pc': 'Reparación PC',
      'reparacion de pc': 'Reparación PC',
      'reparacion impresora': 'Reparación Impresora',
      'reparacion de impresora': 'Reparación Impresora',
      'mantenimiento': 'Mantenimiento',
      'mantenimiento preventivo': 'Mantenimiento Preventivo',
      'instalacion': 'Instalación',
      'instalacion de sistema': 'Instalación SO',
      'configuracion': 'Configuración',
      'configuracion de red': 'Config. Red',
      'soporte remoto': 'Soporte Remoto',
      'recuperacion de datos': 'Recuperación Datos',
      'diagnostico': 'Diagnóstico',
    };
    return names[type] ??
        type.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

// ─── Internal Aggregators ──────────────────────────────────────────

class _ServiceAggregator {
  final String type;
  int totalServices = 0;
  int completedServices = 0;
  double totalRevenue = 0;
  double completedRevenue = 0;
  double totalRepairCost = 0;
  double totalPartsCost = 0;
  final List<double> repairTimes = [];
  final Map<String, int> deviceBreakdown = {};

  _ServiceAggregator(this.type);
}

class _TechAggregator {
  final String id;
  int totalServices = 0;
  int completedServices = 0;
  double totalRevenue = 0;
  double totalPartsCost = 0;
  final List<double> repairTimes = [];
  final Map<String, int> specialties = {};

  _TechAggregator(this.id);
}

class _IssueAggregator {
  final String device;
  final String issue;
  int count = 0;
  double totalRevenue = 0;
  final List<String> solutions = [];

  _IssueAggregator(this.device, this.issue);
}
