/// Rentabilidad calculada por tipo de servicio técnico.
class ServiceProfitability {
  final String serviceType;
  final String serviceTypeName;
  final int totalServices;
  final int completedServices;
  final double totalRevenue;
  final double totalPartsCost;
  final double totalLaborRevenue;
  final double avgRepairTime;
  final double avgRepairCost;
  final double marginPct;
  final double completionRate;
  final Map<String, int> deviceBreakdown;

  const ServiceProfitability({
    required this.serviceType,
    required this.serviceTypeName,
    required this.totalServices,
    required this.completedServices,
    required this.totalRevenue,
    required this.totalPartsCost,
    required this.totalLaborRevenue,
    required this.avgRepairTime,
    required this.avgRepairCost,
    required this.marginPct,
    required this.completionRate,
    required this.deviceBreakdown,
  });

  Map<String, dynamic> toMap() => {
        'serviceType': serviceType,
        'name': serviceTypeName,
        'totalServices': totalServices,
        'completedServices': completedServices,
        'revenue': totalRevenue,
        'partsCost': totalPartsCost,
        'laborRevenue': totalLaborRevenue,
        'avgRepairTime': avgRepairTime,
        'avgRepairCost': avgRepairCost,
        'marginPct': marginPct,
        'completionRate': completionRate,
        'deviceBreakdown': deviceBreakdown,
      };
}

/// Rendimiento individual de un técnico.
class TechnicianServiceStats {
  final String technicianId;
  final String technicianName;
  final int completedServices;
  final int totalServices;
  final double totalRevenue;
  final double totalPartsCost;
  final double avgRepairCost;
  final double avgRepairTime;
  final double completionRate;
  final Map<String, int> specialties;

  const TechnicianServiceStats({
    required this.technicianId,
    required this.technicianName,
    required this.completedServices,
    required this.totalServices,
    required this.totalRevenue,
    required this.totalPartsCost,
    required this.avgRepairCost,
    required this.avgRepairTime,
    required this.completionRate,
    required this.specialties,
  });

  double get marginPct =>
      totalRevenue > 0 ? (totalRevenue - totalPartsCost) / totalRevenue * 100 : 0;

  Map<String, dynamic> toMap() => {
        'technicianId': technicianId,
        'name': technicianName,
        'completedServices': completedServices,
        'totalServices': totalServices,
        'revenue': totalRevenue,
        'partsCost': totalPartsCost,
        'avgRepairCost': avgRepairCost,
        'avgRepairTime': avgRepairTime,
        'completionRate': completionRate,
        'marginPct': marginPct,
        'specialties': specialties,
      };
}

/// Análisis de tiempo de reparación por tipo de servicio.
class ServiceTimeAnalysis {
  final String serviceType;
  final String serviceTypeName;
  final double avgHours;
  final double medianHours;
  final double minHours;
  final double maxHours;
  final int sampleSize;

  const ServiceTimeAnalysis({
    required this.serviceType,
    required this.serviceTypeName,
    required this.avgHours,
    required this.medianHours,
    required this.minHours,
    required this.maxHours,
    required this.sampleSize,
  });
}

/// Problema recurrente detectado (dispositivo + tipo de falla).
class RecurringIssue {
  final String device;
  final String issue;
  final int count;
  final double totalRevenue;
  final List<String> solutions;

  const RecurringIssue({
    required this.device,
    required this.issue,
    required this.count,
    required this.totalRevenue,
    required this.solutions,
  });
}

/// Reporte completo de rentabilidad por servicio.
class ServiceProfitabilityReport {
  final List<ServiceProfitability> services;
  final List<TechnicianServiceStats> technicians;
  final List<ServiceTimeAnalysis> timeAnalysis;
  final List<RecurringIssue> recurringIssues;
  final double totalRevenue;
  final double totalPartsCost;
  final double totalProfit;
  final double avgMarginPct;
  final int totalCompleted;
  final int totalServices;

  const ServiceProfitabilityReport({
    required this.services,
    required this.technicians,
    required this.timeAnalysis,
    required this.recurringIssues,
    required this.totalRevenue,
    required this.totalPartsCost,
    required this.totalProfit,
    required this.avgMarginPct,
    required this.totalCompleted,
    required this.totalServices,
  });
}
