import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'product_repository.dart';

class _InventoryDocMissing implements Exception {
  _InventoryDocMissing(this.message);
  final String message;

  @override
  String toString() => message;
}

class FirebaseService {
  FirebaseService({FirebaseFirestore? firestore, ProductRepository? products})
      : _db = firestore ?? FirebaseFirestore.instance,
        _products = products ?? ProductRepository.instance;

  final FirebaseFirestore _db;
  final ProductRepository _products;

  static const String ordersPath = 'orders';
  static const String creditsPath = 'credits';

  CollectionReference<Map<String, dynamic>>? _userInventory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection(ProductRepository.userInventorySubcollection);
  }

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(ordersPath);

  CollectionReference<Map<String, dynamic>> get _credits =>
      _db.collection(creditsPath);

  void _log(String message, [Object? error, StackTrace? stack]) {
    if (error != null) {
      debugPrint('[FirebaseService] $message → $error');
      if (stack != null) debugPrint('$stack');
    } else {
      debugPrint('[FirebaseService] $message');
    }
  }

  Object _unwrapError(Object e) {
    try {
      final inner = (e as dynamic).error;
      if (inner != null) return inner as Object;
    } catch (_) {}
    return e;
  }

  Future<Product?> getProductByBarcode(String barcode) {
    return _products.getProductByBarcode(barcode);
  }

  Future<Product?> getCatalogProductByBarcode(String barcode) {
    return _products.getCatalogProductByBarcode(barcode);
  }

  Future<void> registerProduct(Product product) {
    return _products.registerProduct(product);
  }

  Future<void> addStock(String productId, int quantityToAdd) {
    return _products.addStock(productId, quantityToAdd);
  }

  Future<Product> upsertInventoryItem({
    required String barcode,
    required String name,
    required String category,
    required double price,
    required int quantity,
    String imageUrl = '',
    String? sku,
    bool addToExistingStock = true,
    String? catalogProductId,
  }) {
    return _products.upsertInventoryItem(
      barcode: barcode,
      name: name,
      category: category,
      price: price,
      quantity: quantity,
      imageUrl: imageUrl,
      sku: sku,
      addToExistingStock: addToExistingStock,
      catalogProductId: catalogProductId,
    );
  }

  Stream<List<Product>> watchProducts() => _products.watchProducts();

  Future<void> initializeDefaultProducts(String userId) async {
    _log('initializeDefaultProducts skipped (seed disabled) for $userId');
  }

  Stream<QuerySnapshot> getAllProducts() {
    final inv = _userInventory();
    if (inv == null) return const Stream.empty();
    return inv.orderBy('name').snapshots();
  }

  Stream<QuerySnapshot> getInventoryStream() {
    final inv = _userInventory();
    if (inv == null) return const Stream.empty();
    return inv.orderBy('name').snapshots();
  }

  Future<void> updateProduct(
    String oldBarcode,
    Product updated, {
    String? oldInventoryId,
  }) {
    return _products.updateProduct(
      oldBarcode,
      updated,
      oldInventoryId: oldInventoryId,
    );
  }

  Future<void> deleteProduct(Product product) {
    return _products.deleteProduct(product);
  }

  Future<Map<String, String>> _resolveInventoryIds(
    List<Map<String, dynamic>> items,
  ) async {
    final ids = <String, String>{};
    for (final raw in items) {
      if (raw['skipInventory'] == true) continue;
      final barcode = (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
      if (barcode.isEmpty) continue;
      String? catalogProductId =
          (raw['catalogProductId'] ?? '').toString().trim();
      if (catalogProductId.isEmpty) {
        try {
          catalogProductId =
              (await _products.getCatalogProductByBarcode(barcode))?.id;
        } catch (e) {
          _log('catalog id resolve failed for $barcode', e);
        }
      }
      ids[barcode] = await _products.inventoryDocumentIdForBarcode(
        barcode,
        catalogProductId: catalogProductId,
      );
    }
    return ids;
  }

  Future<String> checkoutOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String customerName = '',
    String? userId,
    Map<String, dynamic>? credit,
  }) async {
    if (items.isEmpty) {
      throw StateError('Cart is empty — nothing to checkout');
    }

    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to checkout');
    }

    _log('Starting checkout: ${items.length} lines, total=$totalAmount');

    final fastIds = <String, String>{};
    for (final raw in items) {
      if (raw['skipInventory'] == true) continue;
      final barcode = (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
      if (barcode.isEmpty) continue;
      fastIds[barcode] = ProductRepository.inventoryDocId(barcode: barcode);
    }

    try {
      final orderId = await _commitCheckout(
        inv: inv,
        items: items,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        customerName: customerName,
        userId: userId,
        credit: credit,
        inventoryIds: fastIds,
      );
      _log('Checkout OK orderId=$orderId');
      return orderId;
    } on _InventoryDocMissing catch (e) {
      _log('fast path missed (${e.message}), resolving ids');
      final resolved = await _resolveInventoryIds(items);
      try {
        final orderId = await _commitCheckout(
          inv: inv,
          items: items,
          totalAmount: totalAmount,
          paymentMethod: paymentMethod,
          customerName: customerName,
          userId: userId,
          credit: credit,
          inventoryIds: resolved,
        );
        _log('Checkout OK orderId=$orderId');
        return orderId;
      } on _InventoryDocMissing catch (second) {
        throw StateError(second.message);
      }
    }
  }

  Future<String> _commitCheckout({
    required CollectionReference<Map<String, dynamic>> inv,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    required String customerName,
    required String? userId,
    required Map<String, dynamic>? credit,
    required Map<String, String> inventoryIds,
  }) async {
    Object? innerError;
    StackTrace? innerStack;

    try {
      return await _db.runTransaction<String>((tx) async {
        try {
          final qtyByDoc = <String, int>{};
          final nameByDoc = <String, String>{};
          final lines = <Map<String, dynamic>>[];

          for (final raw in items) {
            final barcode =
                (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
            final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
            if (barcode.isEmpty || qty <= 0) {
              throw StateError('Invalid cart line: barcode/qty missing');
            }

            final skipInventory = raw['skipInventory'] == true;
            final name = (raw['name'] ?? barcode).toString();
            final unitPrice = (raw['price'] as num?)?.toDouble() ?? 0;

            if (skipInventory) {
              lines.add({
                'skip': true,
                'barcode': barcode,
                'name': name,
                'price': unitPrice,
                'quantity': qty,
              });
              continue;
            }

            final docId = inventoryIds[barcode] ??
                ProductRepository.inventoryDocId(barcode: barcode);
            qtyByDoc[docId] = (qtyByDoc[docId] ?? 0) + qty;
            nameByDoc.putIfAbsent(docId, () => name);
            lines.add({
              'skip': false,
              'docId': docId,
              'barcode': barcode,
              'name': name,
              'price': raw['price'],
              'quantity': qty,
            });
          }

          final dataByDoc = <String, Map<String, dynamic>>{};
          for (final docId in qtyByDoc.keys) {
            final snap = await tx.get(inv.doc(docId));
            if (!snap.exists) {
              final label = nameByDoc[docId] ?? docId;
              throw _InventoryDocMissing(
                'Add "$label" to your inventory and set stock before selling.',
              );
            }
            final data = snap.data();
            if (data == null || data['hidden'] == true) {
              throw StateError('Item "$docId" is not available');
            }
            final parsed = Product.fromMap(docId, data);
            final need = qtyByDoc[docId]!;
            if (need > parsed.stock) {
              throw StateError(
                'Not enough stock for ${parsed.name} (have ${parsed.stock}, need $need)',
              );
            }
            dataByDoc[docId] = data;
          }

          final resolvedItems = <Map<String, dynamic>>[];
          for (final line in lines) {
            final barcode = line['barcode'] as String;
            final qty = line['quantity'] as int;

            if (line['skip'] == true) {
              final price = (line['price'] as double);
              resolvedItems.add({
                'barcode': barcode,
                'id': barcode,
                'name': line['name'],
                'price': price,
                'quantity': qty,
                'subtotal': price * qty,
                'skipInventory': true,
              });
              continue;
            }

            final docId = line['docId'] as String;
            final data = dataByDoc[docId]!;
            final parsed = Product.fromMap(docId, data);
            final resolvedPrice = Product.fromMap(docId, {
              'price': line['price'] ?? data['price'],
            }).price;
            resolvedItems.add({
              'barcode': barcode,
              'id': barcode,
              'name': parsed.name.isNotEmpty ? parsed.name : barcode,
              'price': resolvedPrice,
              'quantity': qty,
              'subtotal': resolvedPrice * qty,
            });
          }

          final orderRef = _orders.doc();
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final resolvedUserId =
              userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
          tx.set(orderRef, {
            'orderId': orderRef.id,
            'items': resolvedItems,
            'totalAmount': totalAmount,
            'paymentMethod': paymentMethod,
            'customerName': customerName,
            'userId': resolvedUserId,
            'status': 'completed',
            'source': 'mobile_app',
            'createdAtMs': nowMs,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          for (final entry in qtyByDoc.entries) {
            tx.set(
              inv.doc(entry.key),
              {
                'stock': FieldValue.increment(-entry.value),
                'hidden': false,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }

          if (credit != null) {
            final creditRef = _credits.doc();
            tx.set(creditRef, {
              'creditId': creditRef.id,
              'userId': credit['userId'] ?? resolvedUserId,
              'customerName': credit['customerName'] ?? customerName,
              'amount': credit['amount'] ?? totalAmount,
              'date': credit['date'] ?? '',
              'isPaid': false,
              'saleId': orderRef.id,
              if (credit['items'] is List &&
                  (credit['items'] as List).isNotEmpty)
                'items': credit['items'],
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          return orderRef.id;
        } catch (e, st) {
          innerError = e;
          innerStack = st;
          rethrow;
        }
      });
    } catch (e, st) {
      final real = innerError ?? _unwrapError(e);
      if (real is! _InventoryDocMissing) {
        _log('checkoutOrder failed', real, innerStack ?? st);
      }
      Error.throwWithStackTrace(real, innerStack ?? st);
    }
  }

  Future<String> addCredit({
    required String userId,
    required String customerName,
    required double amount,
    required String saleId,
    String date = '',
    List<Map<String, dynamic>> items = const [],
  }) async {
    final ref = _credits.doc();
    await ref.set({
      'creditId': ref.id,
      'userId': userId,
      'customerName': customerName,
      'amount': amount,
      'date': date,
      'isPaid': false,
      'saleId': saleId,
      if (items.isNotEmpty) 'items': items,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log('Credit saved ${ref.id} for $customerName');
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCreditsStream(String userId) {
    return _credits.where('userId', isEqualTo: userId).snapshots();
  }

  Future<void> setCreditPaid(String creditId, bool isPaid) async {
    await _credits.doc(creditId).update({
      'isPaid': isPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getOrdersStream({
    String? userId,
    int limit = 50,
  }) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    final capped = limit <= 0 ? 50 : limit;
    return _orders
        .where('userId', isEqualTo: uid)
        .limit(capped)
        .snapshots();
  }
}