import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';

/// Resultado de rentabilidad calculado para un producto.
class ProductProfitability {
  final String productId;
  final String name;
  final String categoryId;
  final String categoryName;
  final int unitsSold;
  final double revenue; // Ingreso por ventas (subtotal sin IVA)
  final double cogs; // Costo de ventas (con IVA capitalizado, RIMPE)
  final double profit; // Utilidad bruta = revenue - cogs
  final double marginPct; // profit / revenue * 100
  final double unitCost;
  final int stock;
  final int orderCount;

  ProductProfitability({
    required this.productId,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unitsSold,
    required this.revenue,
    required this.cogs,
    required this.profit,
    required this.marginPct,
    required this.unitCost,
    required this.stock,
    required this.orderCount,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'unitsSold': unitsSold,
        'revenue': revenue,
        'cogs': cogs,
        'profit': profit,
        'marginPct': marginPct,
        'unitCost': unitCost,
        'stock': stock,
        'orderCount': orderCount,
      };
}

/// Resultado agregado del análisis de rentabilidad.
class ProfitabilityReport {
  final List<ProductProfitability> products;
  final int totalUnitsSold;
  final double totalRevenue;
  final double totalCogs;
  final double totalProfit;
  final double avgMarginPct;

  ProfitabilityReport({
    required this.products,
    required this.totalUnitsSold,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalProfit,
    required this.avgMarginPct,
  });
}

/// Servicio de rentabilidad por producto.
///
/// El cálculo se basa en las ÓRDENES REALES completadas (ingresos) y el costo de
/// compra del producto (COGS con IVA capitalizado, según decisión RIMPE):
///   revenue = Σ (precio_item * cantidad) de órdenes completadas
///   cogs    = Σ cantidad vendida * costo unitario con IVA
///   profit  = revenue - cogs
///   margin  = profit / revenue * 100
class ProfitabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _ordersCollection = 'orders';
  static const _productsCollection = 'products';
  static const _categoriesCollection = 'categories';
  static const _reservationsCollection = 'reservations';

  static const _completedStatuses = ['entregado', 'completado', 'completed', 'delivered'];

  /// Calcula el reporte de rentabilidad para todas las órdenes completadas.
  Future<ProfitabilityReport> getReport({DateTime? since}) async {
    final productsSnap = await _firestore.collection(_productsCollection).get();
    final categoriesSnap = await _firestore.collection(_categoriesCollection).get();

    final categoryNames = <String, String>{
      for (final d in categoriesSnap.docs) d.id: d.data()['name'] as String? ?? 'Sin categoría',
    };

    // ─── Productos → costo unitario con IVA ───
    final productMap = <String, ProductModel>{};
    for (final doc in productsSnap.docs) {
      productMap[doc.id] = ProductModel.fromFirestoreMap(doc.data(), doc.id);
    }

    // ─── Órdenes completadas ───
    Query query = _firestore.collection(_ordersCollection);
    if (since != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    final ordersSnap = await query.get();

    // Agregar ingresos y unidades por producto
    final unitsByProduct = <String, int>{};
    final revenueByProduct = <String, double>{};
    final ordersByProduct = <String, int>{};

    for (final doc in ordersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String? ?? '').toLowerCase();
      if (!_completedStatuses.contains(status)) continue;

      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      final items = data['items'] as List<dynamic>? ?? originalQuote?['items'] as List<dynamic>? ?? [];

      // Subtotal reconocido contablemente (con descuento aplicado)
      final qSubtotal = (originalQuote?['subtotal'] as num?)?.toDouble() ?? 0.0;
      final qDiscountPct = (originalQuote?['discountPercentage'] as num?)?.toDouble() ?? 0.0;
      final taxable = qSubtotal - qSubtotal * (qDiscountPct / 100);

      // Base bruta de items para prorratear el descuento
      double itemsGross = 0;
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final price = (map['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (map['quantity'] as num?)?.toInt() ?? 0;
        itemsGross += price * qty;
      }
      final scale = itemsGross > 0 ? taxable / itemsGross : 1.0;

      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final type = map['type'] as String? ?? '';
        if (type != 'product') continue;
        final pid = (map['id'] as String?)?.trim() ?? '';
        if (pid.isEmpty || !productMap.containsKey(pid)) continue;
        final price = (map['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (map['quantity'] as num?)?.toInt() ?? 0;
        if (qty <= 0) continue;

        unitsByProduct[pid] = (unitsByProduct[pid] ?? 0) + qty;
        revenueByProduct[pid] = (revenueByProduct[pid] ?? 0) + price * qty * scale;
        ordersByProduct[pid] = (ordersByProduct[pid] ?? 0) + 1;
      }
    }

    // ─── Servicios técnicos: repuestos vendidos en reservaciones completadas ───
    // Las partes usadas se guardan en `partsData` con {productId, name, price}.
    Query resQuery = _firestore.collection(_reservationsCollection);
    if (since != null) {
      resQuery = resQuery.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    final reservationsSnap = await resQuery.get();

    for (final doc in reservationsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String? ?? '').toLowerCase();
      if (!_completedStatuses.contains(status)) continue;

      final parts = data['partsData'] as List<dynamic>? ?? [];
      for (final part in parts) {
        final map = part as Map<String, dynamic>;
        final pid = (map['productId'] as String?)?.trim() ?? '';
        if (pid.isEmpty || !productMap.containsKey(pid)) continue;
        final price = (map['price'] as num?)?.toDouble() ?? 0.0;
        if (price <= 0) continue;

        unitsByProduct[pid] = (unitsByProduct[pid] ?? 0) + 1;
        revenueByProduct[pid] = (revenueByProduct[pid] ?? 0) + price;
        ordersByProduct[pid] = (ordersByProduct[pid] ?? 0) + 1;
      }
    }

    // ─── Calcular rentabilidad por producto ───
    final results = <ProductProfitability>[];
    for (final entry in productMap.entries) {
      final pid = entry.key;
      final product = entry.value;
      final unitsSold = unitsByProduct[pid] ?? 0;
      final revenue = revenueByProduct[pid] ?? 0.0;

      final unitCost = _unitCostWithVat(product);
      final cogs = unitCost * unitsSold;
      final profit = revenue - cogs;
      final marginPct = revenue > 0 ? profit / revenue * 100 : 0.0;

      results.add(ProductProfitability(
        productId: pid,
        name: product.name,
        categoryId: product.categoryId,
        categoryName: categoryNames[product.categoryId] ?? 'Sin categoría',
        unitsSold: unitsSold,
        revenue: revenue,
        cogs: cogs,
        profit: profit,
        marginPct: marginPct,
        unitCost: unitCost,
        stock: product.stock,
        orderCount: ordersByProduct[pid] ?? 0,
      ));
    }

    // Solo productos con ventas
    final sold = results.where((r) => r.unitsSold > 0).toList();
    final totalUnits = sold.fold(0, (a, b) => a + b.unitsSold);
    final totalRevenue = sold.fold(0.0, (a, b) => a + b.revenue);
    final totalCogs = sold.fold(0.0, (a, b) => a + b.cogs);
    final totalProfit = sold.fold(0.0, (a, b) => a + b.profit);
    final avgMargin = totalRevenue > 0 ? totalProfit / totalRevenue * 100 : 0.0;

    return ProfitabilityReport(
      products: sold,
      totalUnitsSold: totalUnits,
      totalRevenue: totalRevenue,
      totalCogs: totalCogs,
      totalProfit: totalProfit,
      avgMarginPct: avgMargin,
    );
  }

  /// Costo unitario con IVA del producto (decisión RIMPE: IVA no acreditable).
  double _unitCostWithVat(ProductModel p) {
    if (p.purchaseCostWithTax != null && p.purchaseCostWithTax! > 0) {
      return p.purchaseCostWithTax!;
    }
    if (p.purchaseCost != null && p.purchaseCost! > 0) {
      return p.purchaseCost! * 1.15; // IVA 15% cuando solo se conoce el costo base
    }
    return 0.0;
  }
}
