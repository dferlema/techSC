import 'package:flutter/material.dart';

/// KPI principal del dashboard
class BusinessKPIs {
  final double totalSales;
  final double totalServices;
  final int totalOrders;
  final int completedCount;
  final int pendingCount;
  final int cancelledCount;
  final double cashTotal;
  final double cardTotal;
  final double transferTotal;
  final double pendingReceivables;
  final double pendingPayables;
  final int lowStockItems;
  final int outOfStockItems;
  final double avgTicket;
  final double conversionRate;

  BusinessKPIs({
    required this.totalSales,
    required this.totalServices,
    required this.totalOrders,
    required this.completedCount,
    required this.pendingCount,
    required this.cancelledCount,
    required this.cashTotal,
    required this.cardTotal,
    required this.transferTotal,
    required this.pendingReceivables,
    required this.pendingPayables,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.avgTicket,
    required this.conversionRate,
  });

  factory BusinessKPIs.empty() => BusinessKPIs(
    totalSales: 0, totalServices: 0, totalOrders: 0,
    completedCount: 0, pendingCount: 0, cancelledCount: 0,
    cashTotal: 0, cardTotal: 0, transferTotal: 0,
    pendingReceivables: 0, pendingPayables: 0,
    lowStockItems: 0, outOfStockItems: 0,
    avgTicket: 0, conversionRate: 0,
  );
}

/// Punto de datos para series temporales (gráficos)
class TimeSeriesPoint {
  final DateTime date;
  final double value;
  final String? label;

  TimeSeriesPoint({required this.date, required this.value, this.label});
}

/// Análisis de tendencias
class TrendAnalysis {
  final List<TimeSeriesPoint> dailySales;
  final List<TimeSeriesPoint> dailyServices;
  final List<TimeSeriesPoint> dailyOrders;
  final double salesGrowthPct;
  final double servicesGrowthPct;
  final String trendDirection;
  final String insight;

  TrendAnalysis({
    required this.dailySales,
    required this.dailyServices,
    required this.dailyOrders,
    required this.salesGrowthPct,
    required this.servicesGrowthPct,
    required this.trendDirection,
    required this.insight,
  });
}

/// Top items (productos/servicios más vendidos)
class TopItem {
  final String id;
  final String name;
  final int quantity;
  final double revenue;
  final double margin;

  TopItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.margin,
  });
}

/// Rendimiento por técnico
class TechnicianPerformance {
  final String technicianId;
  final String technicianName;
  final int completedServices;
  final int totalServices;
  final double totalRevenue;
  final double avgServiceValue;
  final double completionRate;
  final List<String> specialties;

  TechnicianPerformance({
    required this.technicianId,
    required this.technicianName,
    required this.completedServices,
    required this.totalServices,
    required this.totalRevenue,
    required this.avgServiceValue,
    required this.completionRate,
    required this.specialties,
  });
}

/// Alertas de negocio
class BusinessAlert {
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DateTime timestamp;

  BusinessAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.timestamp,
  });
}

enum AlertType {
  lowStock,
  outOfStock,
  overdueReceivable,
  overduePayable,
  pendingServices,
  cancelledServices,
  lowMargin,
  highCancellation,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

/// Resumen de CxC
class ReceivablesSummary {
  final double totalReceivables;
  final double overdueAmount;
  final int overdueCount;
  final double paidThisPeriod;
  final List<ReceivableAging> aging;

  ReceivablesSummary({
    required this.totalReceivables,
    required this.overdueAmount,
    required this.overdueCount,
    required this.paidThisPeriod,
    required this.aging,
  });
}

class ReceivableAging {
  final String period;
  final double amount;
  final int count;

  ReceivableAging({required this.period, required this.amount, required this.count});
}

/// Resumen de CxP
class PayablesSummary {
  final double totalPayables;
  final double overdueAmount;
  final int overdueCount;
  final double paidThisPeriod;

  PayablesSummary({
    required this.totalPayables,
    required this.overdueAmount,
    required this.overdueCount,
    required this.paidThisPeriod,
  });
}

/// Resumen contable
class AccountingSummary {
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final double netIncome;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expensesByCategory;

  AccountingSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.netIncome,
    required this.incomeByCategory,
    required this.expensesByCategory,
  });
}

/// Resumen de inventario
class InventorySummary {
  final int totalProducts;
  final int totalStockValue;
  final int lowStockCount;
  final int outOfStockCount;
  final List<TopItem> topSelling;
  final List<TopItem> slowMoving;

  InventorySummary({
    required this.totalProducts,
    required this.totalStockValue,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.topSelling,
    required this.slowMoving,
  });
}

/// Datos completos del reporte validado
class ValidatedReportData {
  final BusinessKPIs kpis;
  final TrendAnalysis trends;
  final List<TopItem> topProducts;
  final List<TopItem> topServices;
  final List<TechnicianPerformance> technicians;
  final List<BusinessAlert> alerts;
  final ReceivablesSummary receivables;
  final PayablesSummary payables;
  final AccountingSummary accounting;
  final InventorySummary inventory;
  final DateTime generatedAt;
  final DateTimeRange period;

  ValidatedReportData({
    required this.kpis,
    required this.trends,
    required this.topProducts,
    required this.topServices,
    required this.technicians,
    required this.alerts,
    required this.receivables,
    required this.payables,
    required this.accounting,
    required this.inventory,
    required this.generatedAt,
    required this.period,
  });
}

typedef VoidCallback = void Function();