import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/inventory/models/inventory_movement_model.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';
import 'package:tscomputer/features/accounting/models/purchase_invoice_model.dart';
import 'package:tscomputer/features/accounting/services/account_mapper.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';
import 'package:tscomputer/core/utils/firestore_retry.dart';
import 'package:tscomputer/features/accounting/services/purchase_invoice_service.dart';

/// Servicio de gestión de inventario.
///
/// Integrado con el módulo contable: los movimientos de entrada (compras)
/// se registran automáticamente como egresos contables.
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'inventory_movements';
  static const String _productsCollection = 'products';

  Stream<List<InventoryMovementModel>> getMovementsForProduct(
    String productId,
  ) {
    return _db
        .collection(_collection)
        .where('productId', isEqualTo: productId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryMovementModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<InventoryMovementModel>> getAllMovements() {
    return _db
        .collection(_collection)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryMovementModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> registerMovement({
    required String productId,
    required MovementType type,
    required int quantity,
    required String reason,
    required String userId,
    double? unitCost,
    String? supplierId,
    String? supplierName,
    String? supplierPhone,
    String? documentType,
    String? documentNumber,
    double vatRate = 0.15,
    String inventoryAccountCode = '1.1.03',
    String paymentType = 'credito',
    DateTime? issueDate,
    DateTime? dueDate,
  }) async {
    String movementId = '';
    await _db.runTransaction((transaction) async {
      final productRef = _db.collection(_productsCollection).doc(productId);
      final snapshot = await transaction.get(productRef);

      if (!snapshot.exists) {
        throw Exception('Producto no encontrado');
      }

      final product = ProductModel.fromFirestore(snapshot);
      final int previousStock = product.stock;

      int newStock = previousStock;
      if (type == MovementType.inward) {
        newStock += quantity;
      } else if (type == MovementType.outward) {
        newStock -= quantity;
        if (newStock < 0) newStock = 0;
      } else if (type == MovementType.adjust) {
        newStock += quantity;
        if (newStock < 0) newStock = 0;
      }

      // Actualizar stock del producto
      transaction.update(productRef, {'stock': newStock});

      // Crear el movimiento de inventario
      final mid = await DocumentIdService().generateId(prefix: 'mov', useDate: true);
      final movementRef = _db.collection(_collection).doc(mid);
      movementId = mid;
      final movement = InventoryMovementModel(
        id: movementId,
        productId: productId,
        type: type,
        quantity: quantity,
        date: DateTime.now(),
        reason: reason,
        userId: userId,
        previousStock: previousStock,
        newStock: newStock,
      );

      final movementData = movement.toFirestore();
      if (unitCost != null) {
        movementData['unitCost'] = unitCost;
      }
      if (supplierId != null) movementData['supplierId'] = supplierId;
      if (supplierName != null) movementData['supplierName'] = supplierName;
      if (documentType != null) movementData['documentType'] = documentType;
      if (documentNumber != null) movementData['documentNumber'] = documentNumber;
      movementData['inventoryAccountCode'] = inventoryAccountCode;
      movementData['paymentType'] = paymentType;
      movementData['vatRate'] = vatRate;

      // Firestore rechaza mapas con valores null en transacciones; eliminar
      // las claves opcionales que quedaron sin valor antes del set.
      movementData.removeWhere((key, value) => value == null);

      transaction.set(movementRef, movementData);
    });

    // --- Integración Contable (unificada por factura de compra) ---
    double? totalCost;
    if (type == MovementType.inward) {
      // Las compras de inventario ahora generan una FACTURA como fuente de
      // verdad. El servicio de facturas crea de forma idempotente la
      // transacción contable, el asiento y la CxP (si queda a crédito).
      final purchase = await _computePurchaseCost(
        productId,
        quantity,
        unitCost: unitCost,
        vatRate: vatRate,
      );
      if (purchase != null) {
        totalCost = purchase.totalCost;
        final paySupplierName = (supplierName?.isNotEmpty ?? false)
            ? supplierName!
            : (reason.isNotEmpty ? reason : purchase.productName);
        await PurchaseInvoiceService().registerInvoiceFromMovement(
          movementId: movementId,
          supplierName: paySupplierName,
          supplierId: supplierId,
          supplierPhone: supplierPhone,
          documentType: documentType,
          documentNumber: documentNumber,
          date: issueDate ?? DateTime.now(),
          dueDate: dueDate,
          subtotal: purchase.subtotal,
          vatAmount: purchase.vatAmount,
          vatRate: vatRate,
          total: purchase.totalCost,
          paymentType: paymentType,
          inventoryAccountCode: inventoryAccountCode,
          items: [
            PurchaseInvoiceItem(
              productId: productId,
              productName: purchase.productName,
              quantity: quantity,
              unitCost: purchase.unitCost,
              totalCost: purchase.totalCost,
              inventoryAccountCode: inventoryAccountCode,
            ),
          ],
        );
      }
    } else if (type == MovementType.outward) {
      totalCost = await _registerSaleExpense(
        productId,
        quantity,
        reason,
        vatRate: vatRate,
      );
      if (totalCost != null && totalCost > 0) {
        // COGS sale por el costo TOTAL (con IVA capitalizado en la compra).
        final cogsAccount = AccountMapper.cogsAccountFor(inventoryAccountCode);
        await JournalEntryService().createEntryFromEvent(
          referenceType: 'inventory_out',
          referenceId: movementId,
          date: DateTime.now(),
          description: 'COGS - $reason',
          lines: [
            {'accountCode': cogsAccount, 'debit': totalCost, 'credit': 0.0},
            {'accountCode': inventoryAccountCode, 'debit': 0.0, 'credit': totalCost},
          ],
        );
      }
    }
  }

  /// Calcula el costo de compra de inventario (con IVA capitalizado, RIMPE).
  ///
  /// Retorna subtotal, IVA, total y costo unitario, o null si no se puede.
  /// El total (base + IVA) es el costo real que se capitaliza al inventario.
  Future<_PurchaseCost?> _computePurchaseCost(
    String productId,
    int quantity, {
    double? unitCost,
    double vatRate = 0.15,
  }) async {
    try {
      final doc = await retryFirestore(() => _db
          .collection(_productsCollection)
          .doc(productId)
          .get());
      if (!doc.exists) return null;

      final product = ProductModel.fromFirestore(doc);

      double totalCost = 0.0;
      double subtotal = 0.0;
      double vatAmount = 0.0;
      double unitCostUsed = 0.0;

      if (unitCost != null && unitCost > 0) {
        subtotal = unitCost * quantity;
        unitCostUsed = unitCost;
        if (vatRate > 0) {
          vatAmount = subtotal * vatRate;
          totalCost = subtotal + vatAmount;
        } else {
          vatAmount = 0.0;
          totalCost = subtotal;
        }
      } else if (product.purchaseCostWithTax != null && product.purchaseCostWithTax! > 0) {
        totalCost = product.purchaseCostWithTax! * quantity;
        unitCostUsed = product.purchaseCostWithTax!;
        if (vatRate > 0) {
          subtotal = totalCost / (1 + vatRate);
          vatAmount = totalCost - subtotal;
        } else {
          subtotal = totalCost;
          vatAmount = 0.0;
        }
      } else if (product.purchaseCost != null && product.purchaseCost! > 0) {
        subtotal = product.purchaseCost! * quantity;
        unitCostUsed = product.purchaseCost!;
        if (vatRate > 0) {
          vatAmount = subtotal * vatRate;
          totalCost = subtotal + vatAmount;
        } else {
          vatAmount = 0.0;
          totalCost = subtotal;
        }
      } else {
        totalCost = product.price * quantity;
        unitCostUsed = product.price;
        if (vatRate > 0) {
          subtotal = totalCost / (1 + vatRate);
          vatAmount = totalCost - subtotal;
        } else {
          subtotal = totalCost;
          vatAmount = 0.0;
        }
      }

      if (totalCost <= 0) return null;
      return _PurchaseCost(
        productName: product.name,
        unitCost: unitCostUsed,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCost: totalCost,
      );
    } catch (e) {
      debugPrint('⚠️ Error al calcular compra de inventario: $e');
      return null;
    }
  }

  /// Calcula el costo de venta (COGS).
  ///
  /// Solo calcula el costo para el asiento de COGS; NO crea una transacción
  /// de caja porque el dinero ya salió con la compra. Registrarlo como egreso
  /// duplicaba el valor de la compra en los reportes (libro de caja).
  /// Retorna el costo total o null.
  Future<double?> _registerSaleExpense(
    String productId,
    int quantity,
    String reason, {
    double vatRate = 0.15,
  }) async {
    try {
      final doc = await retryFirestore(() => _db.collection(_productsCollection).doc(productId).get());
      if (!doc.exists) return null;

      final product = ProductModel.fromFirestore(doc);

      double unitCost = 0.0;
      if (product.purchaseCostWithTax != null && product.purchaseCostWithTax! > 0) {
        unitCost = product.purchaseCostWithTax!;
      } else if (product.purchaseCost != null && product.purchaseCost! > 0) {
        unitCost = purchaseCostWithVat(product.purchaseCost!, vatRate);
      } else {
        unitCost = product.price;
      }

      final totalCost = unitCost * quantity;
      if (totalCost <= 0) return null;

      return totalCost;
    } catch (e) {
      debugPrint('⚠️ Error al calcular COGS: $e');
      return null;
    }
  }

  double purchaseCostWithVat(double? cost, double rate) {
    if (cost == null || cost <= 0) return 0.0;
    return rate > 0 ? cost * (1 + rate) : cost;
  }

  // Future structure for AI reports
  Future<Map<String, dynamic>> generateInventoryReportForAI() async {
    final movementsSnapshot = await retryFirestore(() => _db
        .collection(_collection)
        .orderBy('date', descending: true)
        .get());
    final movements = movementsSnapshot.docs
        .map((doc) => InventoryMovementModel.fromFirestore(doc))
        .toList();

    // Group movements by product
    final Map<String, List<InventoryMovementModel>> movementsByProduct = {};
    for (var m in movements) {
      if (!movementsByProduct.containsKey(m.productId)) {
        movementsByProduct[m.productId] = [];
      }
      movementsByProduct[m.productId]!.add(m);
    }

    final reportData = {
      'generatedAt': DateTime.now().toIso8601String(),
      'totalMovements': movements.length,
      'productData': movementsByProduct.map(
        (key, value) => MapEntry(key, value.map((m) => m.toJson()).toList()),
      ),
    };

    return reportData;
  }
}

/// Resultado del cálculo de costo de una compra de inventario.
class _PurchaseCost {
  final String productName;
  final double unitCost;
  final double subtotal;
  final double vatAmount;
  final double totalCost;

  const _PurchaseCost({
    required this.productName,
    required this.unitCost,
    required this.subtotal,
    required this.vatAmount,
    required this.totalCost,
  });
}
