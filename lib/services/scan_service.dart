import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import 'firebase_service.dart';
import 'notification_store.dart';
import 'settings_store.dart';

class ScanService {
  ScanService({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService();

  final FirebaseService _firebase;

  AppLocalizations get _l10n => AppLocalizations(
        Locale(SettingsStore.instance.languageCode),
      );

  void _log(String message, [Object? error]) {
    if (error != null) {
      debugPrint('[ScanService] $message → $error');
    } else {
      debugPrint('[ScanService] $message');
    }
  }

  Future<String?> _requireUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log('No authenticated user');
      return null;
    }
    return user.uid;
  }

  Future<ScanResult> lookupBarcode(String barcode) async {
    final code = barcode.trim();
    _log('lookupBarcode code=$code');

    if (code.isEmpty) {
      return ScanResult(
        success: false,
        message: _l10n.text('emptyBarcode'),
      );
    }

    try {
      final product = await _firebase.getProductByBarcode(code);
      if (product == null) {
        final catalog = await _firebase.getCatalogProductByBarcode(code);
        _log('Barcode not in user inventory: $code catalog=${catalog?.name}');
        return ScanResult(
          success: true,
          message: _l10n.text('scanNoInventoryRecord'),
          barcode: code,
          found: false,
          catalogSuggestion: catalog,
        );
      }

      _log('Barcode found: ${product.name} stock=${product.stock}');
      return ScanResult(
        success: true,
        message: _l10n.text(
          'scanFoundProduct',
          values: {'name': product.name},
        ),
        barcode: code,
        found: true,
        itemName: product.name,
        newStockCount: product.stock,
        product: product,
      );
    } catch (e) {
      _log('lookupBarcode failed', e);
      return ScanResult(
        success: false,
        message: _l10n.text(
          'firebaseConnectionFailed',
          values: {'error': '$e'},
        ),
        barcode: code,
      );
    }
  }

  Future<ScanResult> addToInventory({
    required String barcode,
    required String name,
    required String category,
    required double price,
    required int quantity,
    String imageUrl = '',
    bool addToExistingStock = true,
    String? catalogProductId,
  }) async {
    final uid = await _requireUser();
    if (uid == null) {
      return ScanResult(
        success: false,
        message: _l10n.text('signInBeforeSaving'),
        barcode: barcode,
      );
    }

    _log(
      'addToInventory barcode=$barcode qty=$quantity price=$price user=$uid',
    );

    try {
      final product = await _firebase.upsertInventoryItem(
        barcode: barcode,
        name: name,
        category: category,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        addToExistingStock: addToExistingStock,
        catalogProductId: catalogProductId,
      );

      await NotificationStore.instance.addInventoryEvent(
        action: addToExistingStock ? 'added/updated' : 'registered',
        productName: product.name,
        stock: product.stock,
      );

      if (product.isLowStock || product.isOutOfStock) {
        await NotificationStore.instance.addLowStockAlert(
          productName: product.name,
          stock: product.stock,
        );
      }

      _log('addToInventory OK stock=${product.stock}');
      return ScanResult(
        success: true,
        message: _l10n.text(
          'inventorySaved',
          values: {'name': product.name, 'stock': '${product.stock}'},
        ),
        barcode: barcode,
        found: true,
        itemName: product.name,
        newStockCount: product.stock,
        product: product,
      );
    } catch (e) {
      _log('addToInventory failed', e);
      return ScanResult(
        success: false,
        message: _l10n.text(
          'inventorySaveFailed',
          values: {'error': '$e'},
        ),
        barcode: barcode,
      );
    }
  }

  Future<ScanResult> addStock({
    required String barcode,
    required int quantity,
  }) async {
    final uid = await _requireUser();
    if (uid == null) {
      return ScanResult(
        success: false,
        message: _l10n.text('signInBeforeSaving'),
        barcode: barcode,
      );
    }

    _log('addStock barcode=$barcode qty=$quantity');

    try {
      await _firebase.addStock(barcode, quantity);
      final updated = await _firebase.getProductByBarcode(barcode);
      final total = updated == null
          ? ''
          : _l10n.text(
              'stockTotalMessage',
              values: {'stock': '${updated.stock}'},
            );
      return ScanResult(
        success: true,
        message: _l10n.text(
          'stockAddedMessage',
          values: {'quantity': '$quantity', 'total': total},
        ),
        barcode: barcode,
        found: true,
        itemName: updated?.name,
        newStockCount: updated?.stock,
        product: updated,
      );
    } catch (e) {
      _log('addStock failed', e);
      return ScanResult(
        success: false,
        message: _l10n.text(
          'stockUpdateFailed',
          values: {'error': '$e'},
        ),
        barcode: barcode,
      );
    }
  }
}

class ScanResult {
  final bool success;
  final String message;
  final String? barcode;
  final bool found;
  final String? itemName;
  final int? newStockCount;
  final double? checkoutTotal;
  final Product? product;
  final Product? catalogSuggestion;

  ScanResult({
    required this.success,
    required this.message,
    this.barcode,
    this.found = false,
    this.itemName,
    this.newStockCount,
    this.checkoutTotal,
    this.product,
    this.catalogSuggestion,
  });
}
