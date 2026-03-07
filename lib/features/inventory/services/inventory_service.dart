import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:techsc/features/inventory/models/inventory_movement_model.dart';
import 'package:techsc/features/catalog/models/product_model.dart';
import 'package:techsc/features/accounting/models/transaction_model.dart';
import 'package:techsc/features/accounting/services/accounting_service.dart';

/// Servicio de gestión de inventario.
///
/// Integrado con el módulo contable: los movimientos de entrada (compras)
/// se registran automáticamente como egresos contables.
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AccountingService _accountingService = AccountingService();
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
  }) async {
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
      final movementRef = _db.collection(_collection).doc();
      final movement = InventoryMovementModel(
        id: movementRef.id,
        productId: productId,
        type: type,
        quantity: quantity,
        date: DateTime.now(),
        reason: reason,
        userId: userId,
        previousStock: previousStock,
        newStock: newStock,
      );

      transaction.set(movementRef, movement.toFirestore());
    });

    // --- Integración Contable ---
    // Registrar egreso automático cuando se hace una entrada (compra de inventario)
    if (type == MovementType.inward) {
      await _registerPurchaseExpense(productId, quantity, reason);
    }
  }

  /// Registra un egreso contable por una compra de inventario.
  Future<void> _registerPurchaseExpense(
    String productId,
    int quantity,
    String reason,
  ) async {
    try {
      final doc = await _db
          .collection(_productsCollection)
          .doc(productId)
          .get();
      if (!doc.exists) return;

      final product = ProductModel.fromFirestore(doc);
      // Usar el precio del producto como costo estimado
      final totalCost = product.price * quantity;
      if (totalCost <= 0) return;

      final subtotal = totalCost / 1.15;
      final vatAmount = totalCost - subtotal;

      final transaction = TransactionModel(
        id: '',
        type: TransactionType.egreso,
        category: 'Compra Inventario',
        amount: subtotal,
        vatAmount: vatAmount,
        vatRate: 0.15,
        total: totalCost,
        date: DateTime.now(),
        description: '${product.name} x$quantity - $reason',
        referenceId: productId,
      );

      await _accountingService.saveTransaction(transaction);
      debugPrint('✅ Egreso contable registrado: ${product.name} x$quantity');
    } catch (e) {
      debugPrint('⚠️ Error al registrar egreso contable de inventario: $e');
    }
  }

  // Future structure for AI reports
  Future<Map<String, dynamic>> generateInventoryReportForAI() async {
    final movementsSnapshot = await _db
        .collection(_collection)
        .orderBy('date', descending: true)
        .get();
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
