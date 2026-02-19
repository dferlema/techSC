import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/orders/models/order_model.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'orders';

  /// Stream of orders for a specific user
  Stream<List<OrderModel>> getUserOrders(String uid) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream of all orders (for Admin/Seller)
  Stream<List<OrderModel>> getAllOrders() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get a single order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _db.collection(_collection).doc(orderId).get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection(_collection).doc(orderId).update({'status': status});
  }

  /// Delete an order
  Future<void> deleteOrder(String orderId) async {
    await _db.collection(_collection).doc(orderId).delete();
  }
}
