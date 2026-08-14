import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tscomputer/features/admin/models/report_models.dart';

/// Servicio que genera reportes validados con datos reales de Firestore.
class ReportDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ValidatedReportData> generateReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final period = DateTimeRange(start: startDate, end: endDate);
    final startTs = Timestamp.fromDate(startDate);
    final endTs = Timestamp.fromDate(endDate.add(const Duration(days: 1)));

    final results = await Future.wait([
      _loadOrders(startTs, endTs),
      _loadReservations(startTs, endTs),
      _loadReceivables(),
      _loadPayables(),
      _loadInventory(),
      _loadAccounting(),
    ]);

    final List<QueryDocumentSnapshot> orders = results[0];
    final List<QueryDocumentSnapshot> reservations = results[1];
    final List<QueryDocumentSnapshot> receivableDocs = results[2];
    final List<QueryDocumentSnapshot> payableDocs = results[3];
    final List<QueryDocumentSnapshot> productDocs = results[4];
    final List<QueryDocumentSnapshot> accountingDocs = results[5];

    final kpis = _computeKPIs(orders, reservations, receivableDocs, payableDocs, productDocs);
    final trends = _computeTrends(orders, reservations, startDate, endDate);
    final topProducts = _computeTopProducts(orders);
    final topServices = _computeTopServices(reservations);
    final technicians = _computeTechnicianPerformance(reservations);
    final receivables = _computeReceivables(receivableDocs);
    final payables = _computePayables(payableDocs);
    final accounting = _computeAccounting(accountingDocs);
    final inventory = _computeInventory(productDocs);
    final alerts = _generateAlerts(kpis, receivables, payables, inventory, reservations);

    return ValidatedReportData(
      kpis: kpis,
      trends: trends,
      topProducts: topProducts,
      topServices: topServices,
      technicians: technicians,
      alerts: alerts,
      receivables: receivables,
      payables: payables,
      accounting: accounting,
      inventory: inventory,
      generatedAt: DateTime.now(),
      period: period,
    );
  }

  // ─── DATA LOADING ───────────────────────────────────────

  Future<List<QueryDocumentSnapshot>> _loadOrders(Timestamp start, Timestamp end) async {
    try {
      final snap = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();
      return snap.docs;
    } catch (e) {
      debugPrint('Error loading orders: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _loadReservations(Timestamp start, Timestamp end) async {
    try {
      final snap = await _firestore
          .collection('reservations')
          .where('scheduledDate', isGreaterThanOrEqualTo: start)
          .where('scheduledDate', isLessThanOrEqualTo: end)
          .get();
      return snap.docs;
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _loadReceivables() async {
    try {
      final snap = await _firestore
          .collection('accounts_receivable')
          .where('status', whereIn: ['pendiente', 'parcial'])
          .get();
      return snap.docs;
    } catch (e) {
      debugPrint('Error loading receivables: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _loadPayables() async {
    try {
      final snap = await _firestore
          .collection('accounts_payable')
          .where('status', whereIn: ['pendiente', 'parcial'])
          .get();
      return snap.docs;
    } catch (e) {
      debugPrint('Error loading payables: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _loadInventory() async {
    try {
      final snap = await _firestore.collection('products').get();
      return snap.docs;
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _loadAccounting() async {
    try {
      final snap = await _firestore
          .collection('chart_of_accounts')
          .where('isActive', isEqualTo: true)
          .get();
      return snap.docs;
    } catch (e) {
      debugPrint('Error loading accounting: $e');
      return [];
    }
  }

  // ─── KPI COMPUTATION ────────────────────────────────────

  BusinessKPIs _computeKPIs(
    List<QueryDocumentSnapshot> orders,
    List<QueryDocumentSnapshot> reservations,
    List<QueryDocumentSnapshot> receivables,
    List<QueryDocumentSnapshot> payables,
    List<QueryDocumentSnapshot> products,
  ) {
    double totalSales = 0, totalServices = 0;
    double cashTotal = 0, cardTotal = 0, transferTotal = 0;
    int completed = 0, pending = 0, cancelled = 0;

    for (final doc in orders) {
      final d = doc.data() as Map<String, dynamic>;
      final total = (d['total'] ?? 0.0).toDouble();
      final status = (d['status'] ?? '').toString().toLowerCase();
      final pm = (d['paymentMethod'] ?? '').toString().toLowerCase();
      totalSales += total;

      if (pm == 'tarjeta') {
        cardTotal += total;
      } else if (pm == 'transferencia') {
        transferTotal += total;
      } else {
        cashTotal += total;
      }

      if (status == 'completado' || status == 'entregado' || status == 'completed' || status == 'delivered') {
        completed++;
      } else if (status == 'cancelado' || status == 'cancelled') {
        cancelled++;
      } else {
        pending++;
      }
    }

    for (final doc in reservations) {
      final d = doc.data() as Map<String, dynamic>;
      final cost = (d['repairCost'] ?? 0.0).toDouble();
      totalServices += cost;
      final status = (d['status'] ?? '').toString().toLowerCase();
      if (status == 'completado' || status == 'completed') {
        completed++;
      } else if (status == 'cancelado' || status == 'cancelled') {
        cancelled++;
      } else {
        pending++;
      }
    }

    double pendingReceivables = 0;
    for (final doc in receivables) {
      final d = doc.data() as Map<String, dynamic>;
      final balance = (d['balance'] ?? 0.0).toDouble();
      pendingReceivables += balance;
    }

    double pendingPayables = 0;
    for (final doc in payables) {
      final d = doc.data() as Map<String, dynamic>;
      final balance = (d['balance'] ?? 0.0).toDouble();
      pendingPayables += balance;
    }

    int lowStock = 0, outOfStock = 0;
    for (final doc in products) {
      final d = doc.data() as Map<String, dynamic>;
      final stock = (d['stock'] as num?)?.toInt() ?? 0;
      final minStock = (d['minStock'] as num?)?.toInt() ?? 5;
      if (stock <= 0) {
        outOfStock++;
      } else if (stock <= minStock) {
        lowStock++;
      }
    }

    final totalTransactions = completed + pending + cancelled;
    final totalRevenue = totalSales + totalServices;
    final avgTicket = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;
    final conversionRate = totalTransactions > 0 ? (completed / totalTransactions) * 100 : 0.0;

    return BusinessKPIs(
      totalSales: totalSales,
      totalServices: totalServices,
      totalOrders: orders.length + reservations.length,
      completedCount: completed,
      pendingCount: pending,
      cancelledCount: cancelled,
      cashTotal: cashTotal,
      cardTotal: cardTotal,
      transferTotal: transferTotal,
      pendingReceivables: pendingReceivables,
      pendingPayables: pendingPayables,
      lowStockItems: lowStock,
      outOfStockItems: outOfStock,
      avgTicket: avgTicket,
      conversionRate: conversionRate,
    );
  }

  // ─── TREND COMPUTATION ──────────────────────────────────

  TrendAnalysis _computeTrends(
    List<QueryDocumentSnapshot> orders,
    List<QueryDocumentSnapshot> reservations,
    DateTime start,
    DateTime end,
  ) {
    final dailySalesMap = <String, double>{};
    final dailyServicesMap = <String, double>{};

    for (final doc in orders) {
      final d = doc.data() as Map<String, dynamic>;
      final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
      final total = (d['total'] ?? 0.0).toDouble();
      if (createdAt != null) {
        final key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        dailySalesMap[key] = (dailySalesMap[key] ?? 0) + total;
      }
    }

    for (final doc in reservations) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['scheduledDate'] as Timestamp?)?.toDate();
      final cost = (d['repairCost'] ?? 0.0).toDouble();
      if (date != null) {
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyServicesMap[key] = (dailyServicesMap[key] ?? 0) + cost;
      }
    }

    final dailySales = dailySalesMap.entries.map((e) {
      final parts = e.key.split('-');
      return TimeSeriesPoint(
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        value: e.value,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final dailyServices = dailyServicesMap.entries.map((e) {
      final parts = e.key.split('-');
      return TimeSeriesPoint(
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        value: e.value,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final totalDays = end.difference(start).inDays.clamp(1, 365);
    final midDate = start.add(Duration(days: totalDays ~/ 2));

    double firstHalfSales = 0, secondHalfSales = 0;
    for (final p in dailySales) {
      if (p.date.isBefore(midDate)) {
        firstHalfSales += p.value;
      } else {
        secondHalfSales += p.value;
      }
    }

    double firstHalfServices = 0, secondHalfServices = 0;
    for (final p in dailyServices) {
      if (p.date.isBefore(midDate)) {
        firstHalfServices += p.value;
      } else {
        secondHalfServices += p.value;
      }
    }

    final salesGrowth = firstHalfSales > 0 ? ((secondHalfSales - firstHalfSales) / firstHalfSales) * 100 : 0.0;
    final servicesGrowth = firstHalfServices > 0 ? ((secondHalfServices - firstHalfServices) / firstHalfServices) * 100 : 0.0;

    String trendDir;
    String insight;
    if (salesGrowth > 5 && servicesGrowth > 5) {
      trendDir = 'up';
      insight = 'Negocio en crecimiento: ventas +${salesGrowth.toStringAsFixed(1)}% y servicios +${servicesGrowth.toStringAsFixed(1)}%';
    } else if (salesGrowth < -5 && servicesGrowth < -5) {
      trendDir = 'down';
      insight = 'Atención: tendencia a la baja. Ventas ${salesGrowth.toStringAsFixed(1)}%, Servicios ${servicesGrowth.toStringAsFixed(1)}%';
    } else {
      trendDir = 'stable';
      insight = 'Negocio estable dentro del rango esperado';
    }

    return TrendAnalysis(
      dailySales: dailySales,
      dailyServices: dailyServices,
      dailyOrders: [],
      salesGrowthPct: salesGrowth,
      servicesGrowthPct: servicesGrowth,
      trendDirection: trendDir,
      insight: insight,
    );
  }

  // ─── TOP ITEMS ──────────────────────────────────────────

  List<TopItem> _computeTopProducts(List<QueryDocumentSnapshot> orders) {
    final productMap = <String, TopItem>{};
    for (final doc in orders) {
      final d = doc.data() as Map<String, dynamic>;
      final items = d['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          final name = item['name'] ?? item['productName'] ?? 'Desconocido';
          final id = item['productId'] ?? name;
          final price = (item['price'] ?? 0.0).toDouble();
          final qty = (item['quantity'] ?? 1).toInt();
          final existing = productMap[id];
          if (existing != null) {
            productMap[id] = TopItem(id: id, name: name, quantity: existing.quantity + qty as int, revenue: existing.revenue + price, margin: 0);
          } else {
            productMap[id] = TopItem(id: id, name: name, quantity: qty, revenue: price, margin: 0);
          }
        }
      }
    }
    final sorted = productMap.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
    return sorted.take(10).toList();
  }

  List<TopItem> _computeTopServices(List<QueryDocumentSnapshot> reservations) {
    final serviceMap = <String, TopItem>{};
    for (final doc in reservations) {
      final d = doc.data() as Map<String, dynamic>;
      final serviceType = d['serviceType'] ?? 'General';
      final cost = (d['repairCost'] ?? 0.0).toDouble();
      final services = d['servicesData'] as List<dynamic>?;
      if (services != null) {
        for (final s in services) {
          final name = s['name'] ?? serviceType;
          final price = (s['price'] ?? 0.0).toDouble();
          final existing = serviceMap[name];
          if (existing != null) {
            serviceMap[name] = TopItem(id: name, name: name, quantity: existing.quantity + 1, revenue: existing.revenue + price, margin: 0);
          } else {
            serviceMap[name] = TopItem(id: name, name: name, quantity: 1, revenue: price, margin: 0);
          }
        }
      } else if (cost > 0) {
        final existing = serviceMap[serviceType];
        if (existing != null) {
          serviceMap[serviceType] = TopItem(id: serviceType, name: serviceType, quantity: existing.quantity + 1, revenue: existing.revenue + cost, margin: 0);
        } else {
          serviceMap[serviceType] = TopItem(id: serviceType, name: serviceType, quantity: 1, revenue: cost, margin: 0);
        }
      }
    }
    final sorted = serviceMap.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
    return sorted.take(10).toList();
  }

  // ─── TECHNICIAN PERFORMANCE ─────────────────────────────

  List<TechnicianPerformance> _computeTechnicianPerformance(List<QueryDocumentSnapshot> reservations) {
    final techMap = <String, _TechAccumulator>{};
    for (final doc in reservations) {
      final d = doc.data() as Map<String, dynamic>;
      final techId = d['technicianId'] ?? '';
      final techName = d['technicianName'] ?? d['technician'] ?? 'Sin asignar';
      final cost = (d['repairCost'] ?? 0.0).toDouble();
      final status = (d['status'] ?? '').toString().toLowerCase();
      final serviceType = d['serviceType'] ?? '';

      if (techId.isEmpty && techName == 'Sin asignar') continue;

      final acc = techMap.putIfAbsent(techId, () => _TechAccumulator(name: techName));
      acc.totalServices++;
      acc.totalRevenue += cost;
      acc.specialties.add(serviceType);
      if (status == 'completado' || status == 'completed') acc.completedServices++;
    }

    return techMap.entries.map((e) {
      final acc = e.value;
      return TechnicianPerformance(
        technicianId: e.key,
        technicianName: acc.name,
        completedServices: acc.completedServices,
        totalServices: acc.totalServices,
        totalRevenue: acc.totalRevenue,
        avgServiceValue: acc.totalServices > 0 ? acc.totalRevenue / acc.totalServices : 0,
        completionRate: acc.totalServices > 0 ? (acc.completedServices / acc.totalServices) * 100 : 0,
        specialties: acc.specialties.toSet().toList(),
      );
    }).toList()..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
  }

  // ─── RECEIVABLES ────────────────────────────────────────

  ReceivablesSummary _computeReceivables(List<QueryDocumentSnapshot> docs) {
    double total = 0, overdue = 0, paid = 0;
    int overdueCount = 0;
    final aging = <String, double>{};

    final now = DateTime.now();
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final balance = (d['balance'] ?? 0.0).toDouble();
      final paidAmount = (d['paidAmount'] ?? 0.0).toDouble();
      final status = (d['status'] ?? '').toString();
      final dueDate = (d['dueDate'] as Timestamp?)?.toDate();

      total += balance;
      paid += paidAmount;

      if (status == 'parcial' || status == 'pendiente') {
        final daysOverdue = dueDate != null ? now.difference(dueDate).inDays : 0;
        if (daysOverdue > 30) {
          overdue += balance;
          overdueCount++;
          aging['+60 días'] = (aging['+60 días'] ?? 0) + balance;
        } else if (daysOverdue > 15) {
          overdue += balance;
          overdueCount++;
          aging['31-60 días'] = (aging['31-60 días'] ?? 0) + balance;
        } else if (daysOverdue > 0) {
          aging['16-30 días'] = (aging['16-30 días'] ?? 0) + balance;
        } else {
          aging['0-15 días'] = (aging['0-15 días'] ?? 0) + balance;
        }
      }
    }

    return ReceivablesSummary(
      totalReceivables: total,
      overdueAmount: overdue,
      overdueCount: overdueCount,
      paidThisPeriod: paid,
      aging: aging.entries.map((e) => ReceivableAging(period: e.key, amount: e.value, count: 0)).toList(),
    );
  }

  // ─── PAYABLES ───────────────────────────────────────────

  PayablesSummary _computePayables(List<QueryDocumentSnapshot> docs) {
    double total = 0, overdue = 0, paid = 0;
    int overdueCount = 0;
    final now = DateTime.now();

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final balance = (d['balance'] ?? 0.0).toDouble();
      final paidAmount = (d['paidAmount'] ?? 0.0).toDouble();
      final status = (d['status'] ?? '').toString();
      final dueDate = (d['dueDate'] as Timestamp?)?.toDate();

      total += balance;
      paid += paidAmount;

      if ((status == 'parcial' || status == 'pendiente') && dueDate != null) {
        if (now.isAfter(dueDate)) {
          overdue += balance;
          overdueCount++;
        }
      }
    }

    return PayablesSummary(
      totalPayables: total,
      overdueAmount: overdue,
      overdueCount: overdueCount,
      paidThisPeriod: paid,
    );
  }

  // ─── ACCOUNTING ─────────────────────────────────────────

  AccountingSummary _computeAccounting(List<QueryDocumentSnapshot> docs) {
    double totalAssets = 0, totalLiabilities = 0, totalEquity = 0;
    final incomeByCategory = <String, double>{};
    final expensesByCategory = <String, double>{};

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final code = (d['code'] ?? '').toString();
      final balance = (d['balance'] ?? 0.0).toDouble();

      if (code.startsWith('1')) {
        totalAssets += balance;
      } else if (code.startsWith('2')) {
        totalLiabilities += balance;
      } else if (code.startsWith('3')) {
        totalEquity += balance;
      } else if (code.startsWith('4')) {
        final name = d['name'] ?? code;
        incomeByCategory[name] = (incomeByCategory[name] ?? 0) + balance;
      } else if (code.startsWith('5') || code.startsWith('6')) {
        final name = d['name'] ?? code;
        expensesByCategory[name] = (expensesByCategory[name] ?? 0) + balance;
      }
    }

    final totalIncome = incomeByCategory.values.fold(0.0, (a, b) => a + b);
    final totalExpenses = expensesByCategory.values.fold(0.0, (a, b) => a + b);

    return AccountingSummary(
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      totalEquity: totalEquity,
      netIncome: totalIncome - totalExpenses,
      incomeByCategory: incomeByCategory,
      expensesByCategory: expensesByCategory,
    );
  }

  // ─── INVENTORY ──────────────────────────────────────────

  InventorySummary _computeInventory(List<QueryDocumentSnapshot> docs) {
    int totalProducts = docs.length;
    int totalStockValue = 0;
    int lowStock = 0, outOfStock = 0;
    final products = <TopItem>[];

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final name = d['name'] ?? 'Sin nombre';
      final stock = (d['stock'] as num?)?.toInt() ?? 0;
      final price = (d['price'] ?? 0.0).toDouble();
      final cost = (d['purchaseCost'] ?? price * 0.6).toDouble();
      final minStock = (d['minStock'] as num?)?.toInt() ?? 5;
      final value = (stock * cost).toInt();
      totalStockValue += value;

      if (stock <= 0) {
        outOfStock++;
      } else if (stock <= minStock) {
        lowStock++;
      }

      products.add(TopItem(id: doc.id, name: name, quantity: stock, revenue: price, margin: price > 0 ? ((price - cost) / price) * 100 : 0));
    }

    final topSelling = List<TopItem>.from(products)..sort((a, b) => b.revenue.compareTo(a.revenue));
    final slowMoving = List<TopItem>.from(products.where((p) => p.quantity > 5))..sort((a, b) => a.revenue.compareTo(b.revenue));

    return InventorySummary(
      totalProducts: totalProducts,
      totalStockValue: totalStockValue,
      lowStockCount: lowStock,
      outOfStockCount: outOfStock,
      topSelling: topSelling.take(5).toList(),
      slowMoving: slowMoving.take(5).toList(),
    );
  }

  // ─── ALERTS ─────────────────────────────────────────────

  List<BusinessAlert> _generateAlerts(
    BusinessKPIs kpis,
    ReceivablesSummary receivables,
    PayablesSummary payables,
    InventorySummary inventory,
    List<QueryDocumentSnapshot> reservations,
  ) {
    final alerts = <BusinessAlert>[];
    final now = DateTime.now();

    if (inventory.outOfStockCount > 0) {
      alerts.add(BusinessAlert(
        type: AlertType.outOfStock,
        severity: AlertSeverity.critical,
        title: 'Sin Stock',
        message: '${inventory.outOfStockCount} productos sin stock disponible',
        timestamp: now,
      ));
    }

    if (inventory.lowStockCount > 0) {
      alerts.add(BusinessAlert(
        type: AlertType.lowStock,
        severity: AlertSeverity.warning,
        title: 'Stock Bajo',
        message: '${inventory.lowStockCount} productos por debajo del mínimo',
        timestamp: now,
      ));
    }

    if (receivables.overdueCount > 0) {
      alerts.add(BusinessAlert(
        type: AlertType.overdueReceivable,
        severity: AlertSeverity.warning,
        title: 'CxC Vencidas',
        message: '${receivables.overdueCount} cuentas por cobrar vencidas (\$${receivables.overdueAmount.toStringAsFixed(2)})',
        timestamp: now,
      ));
    }

    if (payables.overdueCount > 0) {
      alerts.add(BusinessAlert(
        type: AlertType.overduePayable,
        severity: AlertSeverity.warning,
        title: 'CxP Vencidas',
        message: '${payables.overdueCount} cuentas por pagar vencidas (\$${payables.overdueAmount.toStringAsFixed(2)})',
        timestamp: now,
      ));
    }

    int pendingServices = 0;
    for (final doc in reservations) {
      final s = (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
      if (!(s == 'completado' || s == 'completed' || s == 'cancelado' || s == 'cancelled')) {
        pendingServices++;
      }
    }
    if (pendingServices > 5) {
      alerts.add(BusinessAlert(
        type: AlertType.pendingServices,
        severity: AlertSeverity.info,
        title: 'Servicios Pendientes',
        message: '$pendingServices servicios requieren atención',
        timestamp: now,
      ));
    }

    if (kpis.cancelledCount > 0 && kpis.completedCount > 0) {
      final cancelRate = (kpis.cancelledCount / (kpis.completedCount + kpis.cancelledCount)) * 100;
      if (cancelRate > 20) {
        alerts.add(BusinessAlert(
          type: AlertType.highCancellation,
          severity: AlertSeverity.warning,
          title: 'Alta Tasa de Cancelación',
          message: '${cancelRate.toStringAsFixed(1)}% de cancelaciones — revisar procesos',
          timestamp: now,
        ));
      }
    }

    return alerts;
  }
}

class _TechAccumulator {
  final String name;
  int completedServices = 0;
  int totalServices = 0;
  double totalRevenue = 0;
  final Set<String> specialties = {};

  _TechAccumulator({required this.name});
}