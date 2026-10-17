import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartStore extends ChangeNotifier {
  CartStore._();
  static final CartStore instance = CartStore._();

  final List<CartItem> _items = [];

  VoidCallback? onOpenCartRequested;

  void requestOpenCart() => onOpenCartRequested?.call();

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => _items.isEmpty;

  int quantityOf(String productId) {
    for (final item in _items) {
      final key = item.product.barcode.isNotEmpty
          ? item.product.barcode
          : item.product.id;
      if (key == productId || item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  /// One-time cart line (no inventory document); checkout skips stock deduction.
  void addOneTime({
    required String barcode,
    required String name,
    required double price,
    int quantity = 1,
  }) {
    if (quantity <= 0 || price <= 0) {
      throw StateError('Price and quantity are required');
    }
    final product = Product(
      id: barcode,
      name: name,
      category: 'One-time',
      sku: barcode,
      price: price,
      stock: 999999,
      imageUrl: '',
      barcode: barcode,
    );
    add(product, quantity: quantity, skipInventory: true);
  }

  void add(Product product, {int quantity = 1, bool skipInventory = false}) {
    if (quantity <= 0) return;
    final key = product.barcode.isNotEmpty ? product.barcode : product.id;
    final index = _items.indexWhere((item) {
      final itemKey = item.product.barcode.isNotEmpty
          ? item.product.barcode
          : item.product.id;
      return itemKey == key;
    });
    final already = index >= 0 ? _items[index].quantity : 0;
    if (!skipInventory && already + quantity > product.stock) {
      throw StateError(
        'Not enough stock for ${product.name} '
        '(have ${product.stock}, cart would need ${already + quantity})',
      );
    }
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + quantity,
      );
    } else {
      _items.add(CartItem(
        product: product,
        quantity: quantity,
        skipInventory: skipInventory,
      ));
    }
    notifyListeners();
  }

  int _indexOf(String productId) {
    return _items.indexWhere((item) {
      final key = item.product.barcode.isNotEmpty
          ? item.product.barcode
          : item.product.id;
      return key == productId || item.product.id == productId;
    });
  }

  void setQuantity(String productId, int quantity) {
    final index = _indexOf(productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
      notifyListeners();
      return;
    }
    final item = _items[index];
    if (!item.skipInventory && quantity > item.product.stock) {
      throw StateError(
        'Not enough stock for ${item.product.name} '
        '(have ${item.product.stock}, cart would need $quantity)',
      );
    }
    _items[index] = item.copyWith(quantity: quantity);
    notifyListeners();
  }

  void increment(String productId) {
    final index = _indexOf(productId);
    if (index < 0) return;
    setQuantity(productId, _items[index].quantity + 1);
  }

  void decrement(String productId) {
    final index = _indexOf(productId);
    if (index < 0) return;
    setQuantity(productId, _items[index].quantity - 1);
  }

  void remove(String productId) {
    final before = _items.length;
    _items.removeWhere((item) {
      final key = item.product.barcode.isNotEmpty
          ? item.product.barcode
          : item.product.id;
      return key == productId || item.product.id == productId;
    });
    if (_items.length != before) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
