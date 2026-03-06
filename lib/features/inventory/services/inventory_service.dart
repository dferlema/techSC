import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/inventory/models/inventory_movement_model.dart';
import 'package:techsc/features/catalog/models/product_model.dart';

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
        // Adjust quantity acts as a delta (positive or negative)
        newStock += quantity;
        if (newStock < 0) newStock = 0;
      }

      // Update product
      transaction.update(productRef, {'stock': newStock});

      // Create movement
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
