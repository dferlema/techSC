import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/orders/models/order_model.dart';
import 'package:techsc/features/orders/services/order_service.dart';

/// Provider for OrderService singleton
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService();
});

/// StreamProvider for a specific user's orders
final userOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  uid,
) {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getUserOrders(uid);
});

/// StreamProvider for all orders (Admin/Seller view)
final allOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getAllOrders();
});

/// FutureProvider for a specific order
final orderProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  orderId,
) {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getOrder(orderId);
});
