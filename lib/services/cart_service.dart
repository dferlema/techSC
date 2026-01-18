import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item.dart';
import 'notification_service.dart';
import 'role_service.dart';

/// Service to manage the shopping cart state and order creation.
/// Uses the [ChangeNotifier] pattern for reactive UI updates.
class CartService extends ChangeNotifier {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;

  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get total => _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Adds a product to the cart or increases its quantity if already present.
  void addToCart(Map<String, dynamic> product) {
    // Si el producto no tiene ID, no podemos agregarlo correctamente
    final String productId = product['id'] ?? '';
    if (productId.isEmpty) return;

    final index = _items.indexWhere((item) => item.id == productId);

    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(
        CartItem(
          id: productId,
          name: product['name'] ?? 'Producto sin nombre',
          price: (product['price'] is int)
              ? (product['price'] as int).toDouble()
              : (product['price'] as double? ?? 0.0),
          image: product['image'],
        ),
      );
    }
    notifyListeners();
  }

  /// Removes all units of a specific product from the cart.
  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.id == productId);
    notifyListeners();
  }

  void increaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decreaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Clears all items from the cart and notifies listeners.
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Converts the current cart items into a Firestore order.
  /// Generates a [QuoteModel]-compatible snapshot within the order for history tracking.
  /// Sends notifications to the user and relevant staff (Admins/Sellers).
  Future<void> createOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para realizar un pedido.');
    }

    if (_items.isEmpty) {
      throw Exception('El carrito está vacío.');
    }

    // Obtener información del usuario desde Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    final clientName = userData?['name'] ?? user.email ?? 'Cliente';
    final clientPhone = userData?['phone'] ?? '';
    final clientEmail = user.email ?? '';

    // Calcular total final
    final orderTotal = total;

    // Convertir items del carrito al formato de QuoteItem
    final quoteItems = _items
        .map(
          (item) => {
            'id': item.id,
            'name': item.name,
            'type': 'product',
            'price': item.price,
            'quantity': item.quantity,
            'description': '',
          },
        )
        .toList();

    // Crear estructura originalQuote compatible con QuoteModel
    final originalQuote = {
      'clientId': user.uid,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'creatorId': user.uid,
      'items': quoteItems,
      'history': [
        {
          'date': Timestamp.now(),
          'userId': user.uid,
          'action': 'created',
          'description': 'Pedido creado desde carrito de compras',
        },
      ],
      'createdAt': Timestamp.now(),
      'expirationDate': null,
      'status': 'converted', // Ya convertido a orden
      'applyTax': false,
      'taxRate': 0.0,
      'total': orderTotal,
    };

    // Crear objeto de orden con estructura compatible con quote-based orders
    final orderData = {
      'userId': user.uid,
      'userEmail': clientEmail,
      'quoteId':
          'cart_${DateTime.now().millisecondsSinceEpoch}', // ID único para pedidos de carrito
      'originalQuote': originalQuote,
      'items': _items
          .map((item) => item.toMap())
          .toList(), // Mantener por compatibilidad
      'total': orderTotal,
      'status': 'pendiente', // pendiente, confirmado, entregado, cancelado
      'paymentStatus': 'unpaid',
      'createdAt': Timestamp.now(),
    };

    // Guardar en Firestore
    final docRef = await FirebaseFirestore.instance
        .collection('orders')
        .add(orderData);

    // Enviar notificación al usuario
    await NotificationService().sendNotification(
      title: 'Pedido Realizado',
      body:
          'Tu pedido por \$${orderTotal.toStringAsFixed(2)} ha sido recibido.',
      type: 'order',
      relatedId: docRef.id,
      receiverId: user.uid,
    );

    // Enviar notificación a administradores y vendedores
    await NotificationService().sendNotification(
      title: 'Nuevo Pedido',
      body:
          'Nuevo pedido de $clientName por \$${orderTotal.toStringAsFixed(2)}',
      type: 'order',
      relatedId: docRef.id,
      receiverRole: RoleService.ADMIN, // Broadcast to admins
    );
    await NotificationService().sendNotification(
      title: 'Nuevo Pedido',
      body:
          'Nuevo pedido de $clientName por \$${orderTotal.toStringAsFixed(2)}',
      type: 'order',
      relatedId: docRef.id,
      receiverRole: RoleService.SELLER, // Broadcast to sellers
    );

    // Limpiar carrito
    clearCart();
  }
}
