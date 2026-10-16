import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'firebase_service.dart';
import 'notification_store.dart';
import 'settings_store.dart';

/// Sales / checkout. Primary write goes to Firestore `orders/{orderId}`
/// (shared with the PHP web app). Credits are written to Firestore first
/// (reliable on release APKs), then optionally mirrored to Realtime Database.
class SalesService {
  SalesService({
    FirebaseService? firebase,
    DatabaseReference? dbRef,
  })  : _firebase = firebase ?? FirebaseService(),
        _dbRef = dbRef ?? FirebaseDatabase.instance.ref();

  final FirebaseService _firebase;
  final DatabaseReference _dbRef;

  void _log(String message, [Object? error]) {
    if (error != null) {
      debugPrint('[SalesService] $message → $error');
    } else {
      debugPrint('[SalesService] $message');
    }
  }

  /// Completes checkout: validates stock, writes Firestore order, decrements
  /// inventory, records credit when needed, and mirrors to RTDB when possible.
  Future<String> recordSale({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String customerName = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Walang naka-login na user. Mag-login muna.');
    }

    _log(
      'recordSale items=${items.length} total=$totalAmount method=$paymentMethod',
    );

    final isCredit =
        paymentMethod == 'Credit / Utang' && customerName.trim().isNotEmpty;
    final creditDate = DateFormat(
      'MMM d, yyyy',
      SettingsStore.instance.languageCode,
    ).format(DateTime.now());

    final creditItems = items
        .map((item) {
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final productId = (item['inventoryId'] ??
                  item['catalogProductId'] ??
                  item['id'] ??
                  item['barcode'] ??
                  '')
              .toString();
          return <String, dynamic>{
            'id': productId,
            'productId': productId,
            'name': (item['name'] ?? '').toString(),
            'quantity': qty,
            'price': price,
            'subtotal': price * qty,
          };
        })
        .toList();

    // Order, stock, and credit (when applicable) commit in one Firestore txn.
    final orderId = await _firebase.checkoutOrder(
      items: items,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      customerName: customerName,
      userId: user.uid,
      credit: isCredit
          ? {
              'userId': user.uid,
              'customerName': customerName.trim(),
              'amount': totalAmount,
              'date': creditDate,
              'items': creditItems,
            }
          : null,
    );

    // Best-effort RTDB mirror for older sales history screens.
    try {
      final saleRef = _dbRef.child('sales').child(user.uid).child(orderId);
      await saleRef.set({
        'transactionId': orderId,
        'orderId': orderId,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'customerName': customerName,
        'timestamp': ServerValue.timestamp,
        'items': items
            .map((item) => {
                  'id': item['id'] ?? item['barcode'],
                  'barcode': item['barcode'] ?? item['id'],
                  'name': item['name'],
                  'price': item['price'],
                  'quantity': item['quantity'],
                  'subtotal':
                      (item['price'] as num) * (item['quantity'] as num),
                })
            .toList(),
      });

      if (isCredit) {
        final creditRef = _dbRef.child('credits').child(user.uid).push();
        await creditRef.set({
          'customerName': customerName.trim(),
          'amount': totalAmount,
          'date': creditDate,
          'isPaid': false,
          'saleId': orderId,
          'items': creditItems,
        });
      }
      _log('RTDB mirror OK for order $orderId');
    } catch (e) {
      // Firestore order + credit already committed — do not fail the sale.
      _log('RTDB mirror skipped/failed (check database.rules.json)', e);
    }

    // In-app "Thank you" notification after successful checkout.
    try {
      await NotificationStore.instance.addCheckoutThankYou(
        orderId: orderId,
        total: totalAmount,
        paymentMethod: paymentMethod,
        customerName: customerName,
      );
      await NotificationStore.instance.addTransactionRecorded(
        paymentMethod: paymentMethod,
        total: totalAmount,
        customerName: customerName,
      );
    } catch (e) {
      _log('Notification add failed', e);
    }

    // Low-stock alerts for items that crossed the threshold after sale.
    try {
      await _notifyLowStock(items);
    } catch (e) {
      _log('Low-stock check failed', e);
    }

    return orderId;
  }

  Future<void> _notifyLowStock(List<Map<String, dynamic>> items) async {
    for (final raw in items) {
      final barcode = (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
      if (barcode.isEmpty) continue;
      try {
        final product = await _firebase.getProductByBarcode(barcode);
        if (product == null) continue;
        if (product.isLowStock || product.isOutOfStock) {
          await NotificationStore.instance.addLowStockAlert(
            productName: product.name,
            stock: product.stock,
          );
        }
      } catch (e) {
        _log('Low-stock lookup failed for $barcode', e);
      }
    }
  }

  Stream<DatabaseEvent> getSalesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _dbRef.child('sales').child(user.uid).onValue;
  }

  /// Prefer Firestore credits (works in release APK).
  Stream<QuerySnapshot<Map<String, dynamic>>> getCreditsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firebase.getCreditsStream(user.uid);
  }

  Future<void> setCreditPaid(String creditId, bool isPaid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firebase.setCreditPaid(creditId, isPaid);
    } catch (e) {
      _log('Firestore setCreditPaid failed, trying RTDB', e);
    }

    // Also update RTDB mirror if present.
    try {
      await _dbRef
          .child('credits')
          .child(user.uid)
          .child(creditId)
          .update({'isPaid': isPaid});
    } catch (_) {}
  }
}
