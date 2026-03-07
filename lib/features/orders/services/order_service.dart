import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:techsc/features/orders/models/order_model.dart';
import 'package:techsc/features/accounting/models/transaction_model.dart';
import 'package:techsc/features/accounting/services/accounting_service.dart';

/// Servicio para gestionar pedidos.
///
/// Integrado con el módulo contable: al marcar un pedido como entregado/completado,
/// se registra automáticamente un ingreso contable.
class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AccountingService _accountingService = AccountingService();
  static const String _collection = 'orders';

  /// Stream de pedidos de un usuario específico.
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

  /// Stream de todos los pedidos (para Admin/Vendedor).
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

  /// Obtiene un pedido por su ID.
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _db.collection(_collection).doc(orderId).get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  /// Actualiza el estado de un pedido.
  /// Si el estado cambia a 'entregado' o 'completado', se registra
  /// automáticamente un ingreso contable con el total del pedido.
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection(_collection).doc(orderId).update({'status': status});

    // --- Integración Contable ---
    // Registrar ingreso automático al entregar/completar un pedido
    final estadosCompletados = [
      'entregado',
      'completado',
      'completed',
      'delivered',
    ];
    if (estadosCompletados.contains(status.toLowerCase())) {
      await _registerOrderIncome(orderId);
    }
  }

  /// Registra el ingreso contable correspondiente a un pedido completado.
  Future<void> _registerOrderIncome(String orderId) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) return;

      final total = order.originalQuote.total;
      // Cálculo inverso del IVA: total incluye IVA al 15%
      final subtotal = total / 1.15;
      final vatAmount = total - subtotal;

      final transaction = TransactionModel(
        id: '',
        type: TransactionType.ingreso,
        category: 'Venta',
        amount: subtotal,
        vatAmount: vatAmount,
        vatRate: 0.15,
        total: total,
        date: DateTime.now(),
        description: 'Pedido #${orderId.substring(0, 6)} completado',
        clientIdentification: order.originalQuote.customerUid,
        referenceId: orderId,
      );

      await _accountingService.saveTransaction(transaction);
      debugPrint('✅ Ingreso contable registrado para pedido $orderId');
    } catch (e) {
      debugPrint('⚠️ Error al registrar ingreso contable del pedido: $e');
      // No lanzamos el error para no bloquear la actualización del pedido
    }
  }

  /// Elimina un pedido.
  Future<void> deleteOrder(String orderId) async {
    await _db.collection(_collection).doc(orderId).delete();
  }
}
