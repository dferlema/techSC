class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String? image;
  final String type; // 'product' or 'service'

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.image,
    this.type = 'product',
  });

  double get totalPrice => price * quantity;

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id, // ID del producto/servicio para lookup
      'productId': id, // Mantener por compatibilidad
      'name': name,
      'price': price,
      'quantity': quantity,
      'image': image,
      'type': type,
      'subtotal': totalPrice,
    };
  }
}
