import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final bool skipInventory;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.skipInventory = false,
  });

  double get totalPrice => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity, bool? skipInventory}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      skipInventory: skipInventory ?? this.skipInventory,
    );
  }
}
