import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;

  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get total => _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

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

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  Future<void> createOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para realizar un pedido.');
    }

    if (_items.isEmpty) {
      throw Exception('El carrito está vacío.');
    }

    // Calcular total final
    final orderTotal = total;

    // Crear objeto de orden
    final orderData = {
      'userId': user.uid,
      'userEmail': user.email,
      'items': _items.map((item) => item.toMap()).toList(),
      'total': orderTotal,
      'status': 'pendiente', // pendiente, confirmado, entregado, cancelado
      'createdAt': Timestamp.now(),
    };

    // Guardar en Firestore
    await FirebaseFirestore.instance.collection('orders').add(orderData);

    // Limpiar carrito
    clearCart();
  }
}
