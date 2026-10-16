import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'product_repository.dart';

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

  /// Seed removed — products must come from Firestore only.
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

  Future<String> checkoutOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String customerName = '',
    String? userId,
    /// When set, credit is written in the same transaction as the order/stock.
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

    // Resolve inventory doc ids outside the transaction. Catalog templates are
    // not sellable until the user has an inventory row with their own stock.
    final inventoryIdsByBarcode = <String, String>{};
    for (final raw in items) {
      if (raw['skipInventory'] == true) continue;
      final barcode = (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
      if (barcode.isEmpty) continue;
      final requestedCatalogId =
          (raw['catalogProductId'] ?? '').toString().trim();
      String? catalogProductId = requestedCatalogId;
      if (catalogProductId.isEmpty) {
        try {
          catalogProductId =
              (await _products.getCatalogProductByBarcode(barcode))?.id;
        } catch (e) {
          _log('catalog id resolve failed for $barcode', e);
        }
      }
      final docId = await _products.inventoryDocumentIdForBarcode(
        barcode,
        catalogProductId: catalogProductId,
      );
      inventoryIdsByBarcode[barcode] = docId;
    }

    try {
      final orderId = await _db.runTransaction<String>((tx) async {
        final stockDecrements = <String, int>{};
        final resolvedItems = <Map<String, dynamic>>[];

        for (final raw in items) {
          final barcode = (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
          final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
          if (barcode.isEmpty || qty <= 0) {
            throw StateError('Invalid cart line: barcode/qty missing');
          }

          final skipInventory = raw['skipInventory'] == true;
          final name = (raw['name'] ?? barcode).toString();
          final unitPrice = (raw['price'] as num?)?.toDouble() ?? 0;

          if (skipInventory) {
            resolvedItems.add({
              'barcode': barcode,
              'id': barcode,
              'name': name,
              'price': unitPrice,
              'quantity': qty,
              'subtotal': unitPrice * qty,
              'skipInventory': true,
            });
            continue;
          }

          final docId = inventoryIdsByBarcode[barcode] ??
              ProductRepository.inventoryDocId(
                barcode: barcode,
                catalogProductId:
                    (raw['catalogProductId'] ?? '').toString().trim(),
              );
          final invRef = inv.doc(docId);
          final invSnap = await tx.get(invRef);

          if (!invSnap.exists) {
            throw StateError(
              'Add "${name.isNotEmpty ? name : barcode}" to your inventory '
              'and set stock before selling.',
            );
          }

          final data = invSnap.data();
          if (data == null || data['hidden'] == true) {
            throw StateError('Item "$barcode" is not available');
          }

          final parsed = Product.fromMap(docId, data);
          if (qty > parsed.stock) {
            throw StateError(
              'Not enough stock for ${parsed.name} (have ${parsed.stock}, need $qty)',
            );
          }

          stockDecrements[docId] = (stockDecrements[docId] ?? 0) + qty;
          final resolvedPrice = Product.fromMap(docId, {
            'price': raw['price'] ?? data['price'],
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

        // Re-check aggregated qty against stock (duplicate barcodes in one cart).
        for (final entry in stockDecrements.entries) {
          final invSnap = await tx.get(inv.doc(entry.key));
          final data = invSnap.data();
          if (data == null) {
            throw StateError('Item missing from inventory during checkout');
          }
          final have = Product.fromMap(entry.key, data).stock;
          if (entry.value > have) {
            throw StateError(
              'Not enough stock for ${Product.fromMap(entry.key, data).name} '
              '(have $have, need ${entry.value})',
            );
          }
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

        for (final entry in stockDecrements.entries) {
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
            if (credit['items'] is List && (credit['items'] as List).isNotEmpty)
              'items': credit['items'],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return orderRef.id;
      });

      _log('Checkout OK orderId=$orderId');
      return orderId;
    } catch (e, st) {
      _log('checkoutOrder failed', e, st);
      rethrow;
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
    _log('Credit saved ${ref.id} for$customerName');
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

  /// Orders for [userId] (defaults to the signed-in user).
  /// Queries by userId without composite index so it works out-of-the-box.
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
