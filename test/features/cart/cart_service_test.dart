import 'package:flutter_test/flutter_test.dart';
import 'package:techsc/features/cart/services/cart_service.dart';

void main() {
  late CartService cartService;

  setUp(() {
    cartService = CartService();
  });

  group('CartService', () {
    final product1 = {
      'id': 'p1',
      'name': 'Product 1',
      'price': 10.0,
      'type': 'product',
    };

    test('Add item to cart', () {
      cartService.addToCart(product1);
      expect(cartService.itemCount, 1);
      expect(cartService.total, 10.0);
    });

    test('Increase quantity', () {
      cartService.addToCart(product1);
      cartService.increaseQuantity('p1');
      expect(cartService.items[0].quantity, 2);
      expect(cartService.total, 20.0);
    });

    test('Decrease quantity', () {
      cartService.addToCart(product1);
      cartService.increaseQuantity('p1');
      cartService.decreaseQuantity('p1');
      expect(cartService.items[0].quantity, 1);
      expect(cartService.total, 10.0);
    });

    test('Remove item', () {
      cartService.addToCart(product1);
      cartService.removeFromCart('p1');
      expect(cartService.itemCount, 0);
      expect(cartService.total, 0.0);
    });

    test('Clear cart', () {
      cartService.addToCart(product1);
      cartService.clearCart();
      expect(cartService.itemCount, 0);
    });
  });
}
