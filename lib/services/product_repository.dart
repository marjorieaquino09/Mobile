import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';

class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final ProductRepository instance = ProductRepository();

  final FirebaseFirestore _db;

  static const String catalogPath = 'products';
  static const String userInventorySubcollection = 'inventory';

  CollectionReference<Map<String, dynamic>> get _catalog =>
      _db.collection(catalogPath);

  CollectionReference<Map<String, dynamic>>? _userInventory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection(userInventorySubcollection);
  }

  void _log(String message, [Object? error, StackTrace? stack]) {
    if (error != null) {
      debugPrint('[ProductRepo] $message → $error');
      if (stack != null) debugPrint('$stack');
    } else {
      debugPrint('[ProductRepo] $message');
    }
  }

  static String inventoryDocId({
    required String barcode,
    String? catalogProductId,
    String name = '',
    String size = '',
  }) {
    final code = barcode.trim();
    if (code.isNotEmpty) return _sanitizeDocId(code);

    final slug = _normalizeProductName('$name $size').replaceAll(' ', '-');
    if (slug.isNotEmpty) return _sanitizeDocId(slug);

    final catalogId = catalogProductId?.trim() ?? '';
    if (catalogId.isNotEmpty) return _sanitizeDocId(catalogId);
    throw ArgumentError('Barcode or product name is required');
  }

  static String _sanitizeDocId(String id) {
    return id.replaceAll('/', '_').trim();
  }

  Future<String> inventoryDocumentIdForBarcode(
    String barcode, {
    String? catalogProductId,
  }) async {
    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to resolve inventory product');
    }
    final code = barcode.trim();
    if (code.isEmpty) throw ArgumentError('Barcode is required');
    final deterministicId = inventoryDocId(
      barcode: code,
      catalogProductId: catalogProductId,
    );
    return await _existingInventoryId(
          inv,
          barcode: code,
          preferredId: catalogProductId ?? deterministicId,
        ) ??
        deterministicId;
  }

  Map<String, dynamic> _withTimestamps(
    Map<String, dynamic> data, {
    bool isCreate = false,
  }) {
    final now = FieldValue.serverTimestamp();
    final out = Map<String, dynamic>.from(data)..['updatedAt'] = now;
    if (isCreate) out['createdAt'] = now;
    return out;
  }

  Map<String, dynamic> _normalizeProductFields(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      out['userId'] = uid;
    }
    final imageUrl = (out['imageUrl'] ?? out['image'] ?? '').toString();
    if (imageUrl.isNotEmpty) {
      out['imageUrl'] = imageUrl;
      out['image'] = imageUrl;
    }
    return out;
  }

  List<Product> _docsToProducts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    bool isCatalogOnly = false,
  }) {
    final products = <Product>[];
    for (final doc in docs) {
      final data = doc.data();
      final barcode = (data['barcode'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      try {
        products.add(
          Product.fromFirestore(
            doc.id,
            {
              ...data,
              'barcode': barcode,
            },
            isCatalogOnly: isCatalogOnly,
          ),
        );
      } catch (e, st) {
        _log('Skipping bad doc ${doc.id}', e, st);
      }
    }
    products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return products;
  }

  static List<Product> mergeCatalogAndInventory({
    required List<Product> catalog,
    required List<Product> inventory,
  }) {
    final uniqueInventory = <String, Product>{};
    for (final user in inventory) {
      final key = productKey(user);
      if (key.isEmpty) continue;

      final existing = uniqueInventory[key];
      if (existing == null || _prefersUser(user, existing)) {
        uniqueInventory[key] = user;
      }
    }

    final byId = <String, Product>{};
    final byBarcode = <String, Product>{};
    final usedInventoryIds = <String>{};

    for (final user in uniqueInventory.values) {
      byId[user.id] = user;
      if (user.barcode.isNotEmpty) {
        byBarcode[user.barcode.toLowerCase()] = user;
      }
    }

    final merged = <Product>[];

    for (final cat in catalog) {
      final matchingUsers = uniqueInventory.values.where((user) =>
          user.id == cat.id ||
          user.catalogProductId == cat.id ||
          (cat.barcode.isNotEmpty &&
              user.barcode.toLowerCase() == cat.barcode.toLowerCase()));
      final matches = matchingUsers.toList(growable: false);
      usedInventoryIds.addAll(matches.map((user) => user.id));
      Product? user = byId[cat.id];
      user ??= matches
          .where((entry) => entry.catalogProductId == cat.id)
          .firstOrNull;
      user ??= byBarcode[cat.barcode.toLowerCase()];
      if (user == null && cat.barcode.isNotEmpty) {
        user = byId[inventoryDocId(barcode: cat.barcode)];
      }

      if (user != null) {
        usedInventoryIds.add(user.id);
        if (user.hidden) continue;
        merged.add(Product.mergeCatalogWithUser(cat, user));
      } else {
        merged.add(cat.copyWith(
          isCatalogOnly: true,
          catalogProductId: cat.id,
          stock: 0,
        ));
      }
    }

    for (final user in uniqueInventory.values) {
      if (usedInventoryIds.contains(user.id)) continue;
      if (user.hidden) continue;
      merged.add(user.copyWith(isCatalogOnly: false));
    }

    final uniqueProducts = <String, Product>{};
    for (final product in merged) {
      final key = productKey(product);
      if (key.isEmpty) continue;

      final existing = uniqueProducts[key];
      if (existing == null || _prefersProduct(product, existing)) {
        uniqueProducts[key] = product;
      }
    }

    final products = uniqueProducts.values.toList();
    products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return products;
  }

  static String _normalizeProductName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static String productKey(Product product) {
    final barcode = product.barcode.trim().toLowerCase();
    if (barcode.isNotEmpty) return 'barcode:$barcode';

    final name = _normalizeProductName(product.name);
    if (name.isEmpty) return '';
    final size = _normalizeProductName(product.size);
    return 'name:$name|size:$size';
  }

  static bool _prefersProduct(Product candidate, Product existing) {
    final candidateScore = (candidate.isCatalogOnly ? 0 : 4) +
        (candidate.catalogProductId.isNotEmpty ? 2 : 0) +
        (candidate.barcode.isNotEmpty ? 1 : 0);
    final existingScore = (existing.isCatalogOnly ? 0 : 4) +
        (existing.catalogProductId.isNotEmpty ? 2 : 0) +
        (existing.barcode.isNotEmpty ? 1 : 0);
    if (candidateScore != existingScore) {
      return candidateScore > existingScore;
    }
    return candidate.id.compareTo(existing.id) < 0;
  }

  static bool _prefersUser(Product candidate, Product existing) {
    final candidateScore = (candidate.catalogProductId.isNotEmpty ? 4 : 0) +
        (candidate.barcode.isNotEmpty ? 2 : 0) +
        (candidate.size.isNotEmpty ? 1 : 0) +
        (candidate.name.isNotEmpty ? 1 : 0) +
        (candidate.hidden ? 0 : 3);
    final existingScore = (existing.catalogProductId.isNotEmpty ? 4 : 0) +
        (existing.barcode.isNotEmpty ? 2 : 0) +
        (existing.size.isNotEmpty ? 1 : 0) +
        (existing.name.isNotEmpty ? 1 : 0) +
        (existing.hidden ? 0 : 3);
    return candidateScore > existingScore ||
        (candidateScore == existingScore &&
            candidate.id.compareTo(existing.id) < 0);
  }

  Future<String?> _existingInventoryId(
    CollectionReference<Map<String, dynamic>> inventory, {
    required String barcode,
    String? preferredId,
  }) async {
    final candidates = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (barcode.isNotEmpty) {
      final query = await inventory.where('barcode', isEqualTo: barcode).get();
      candidates.addAll(query.docs);
    }

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        final scoreA = _productDataCompleteness(a.data());
        final scoreB = _productDataCompleteness(b.data());
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return a.id.compareTo(b.id);
      });
      return candidates.first.id;
    }

    final preferred = (preferredId ?? '').trim();
    if (preferred.isEmpty) return null;
    final doc = await inventory.doc(_sanitizeDocId(preferred)).get();
    if (!doc.exists) return null;
    final existingBarcode = (doc.data()?['barcode'] ?? '').toString().trim();
    return existingBarcode.isEmpty || existingBarcode == barcode
        ? doc.id
        : null;
  }

  Future<String?> _existingInventoryIdByIdentity(
    CollectionReference<Map<String, dynamic>> inventory,
    Product product,
  ) async {
    final key = productKey(product);
    if (key.isEmpty) return null;

    final snapshot = await inventory.get();
    final candidates = snapshot.docs.where((doc) {
      return productKey(Product.fromFirestore(doc.id, doc.data())) == key;
    }).toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final scoreDifference = _productDataCompleteness(b.data()) -
          _productDataCompleteness(a.data());
      if (scoreDifference != 0) return scoreDifference;
      return a.id.compareTo(b.id);
    });
    return candidates.first.id;
  }

  static int _productDataCompleteness(Map<String, dynamic> data) {
    const fields = [
      'name',
      'size',
      'category',
      'barcode',
      'price',
      'stock',
      'imageUrl',
    ];
    return fields.where((field) {
      final value = data[field];
      return value != null && value.toString().trim().isNotEmpty;
    }).length;
  }

  Stream<List<Product>> _watchCatalog() {
    return _catalog.snapshots().map((snap) {
      try {
        return _docsToProducts(snap.docs, isCatalogOnly: true);
      } catch (e, st) {
        _log('catalog parse failed', e, st);
        rethrow;
      }
    }).handleError((Object e, StackTrace st) {
      _log('catalog stream error', e, st);
      throw e;
    });
  }

  Stream<List<Product>> _watchUserInventory() {
    final inv = _userInventory();
    if (inv == null) return Stream.value(const <Product>[]);

    return inv.snapshots().map((snap) {
      try {
        return _docsToProducts(snap.docs);
      } catch (e, st) {
        _log('inventory parse failed', e, st);
        rethrow;
      }
    }).handleError((Object e, StackTrace st) {
      _log('inventory stream error', e, st);
      throw e;
    });
  }

  StreamController<List<Product>>? _sharedProductsController;
  StreamSubscription<List<Product>>? _sharedCatalogSub;
  StreamSubscription<List<Product>>? _sharedInventorySub;
  List<Product>? _sharedCatalog;
  List<Product>? _sharedInventory;
  List<Product>? _lastSharedProducts;
  String? _sharedWatchUid;

  final ValueNotifier<int> productsWatchGeneration = ValueNotifier<int>(0);

  void _emitSharedProducts() {
    final controller = _sharedProductsController;
    if (controller == null || controller.isClosed) return;
    if (_sharedCatalog == null || _sharedInventory == null) return;
    final merged = mergeCatalogAndInventory(
      catalog: _sharedCatalog!,
      inventory: _sharedInventory!,
    );
    _lastSharedProducts = merged;
    controller.add(merged);
  }

  void _tearDownSharedProductsWatch() {
    final catalogSub = _sharedCatalogSub;
    final inventorySub = _sharedInventorySub;
    final controller = _sharedProductsController;
    _sharedCatalogSub = null;
    _sharedInventorySub = null;
    _sharedCatalog = null;
    _sharedInventory = null;
    _lastSharedProducts = null;
    _sharedWatchUid = null;
    _sharedProductsController = null;
    // ignore: discarded_futures
    catalogSub?.cancel();
    // ignore: discarded_futures
    inventorySub?.cancel();
    if (controller != null && !controller.isClosed) {
      // ignore: discarded_futures
      controller.close();
    }
  }

  void stopWatching() => _tearDownSharedProductsWatch();

  Stream<List<Product>> refreshProducts() {
    _tearDownSharedProductsWatch();
    return watchProducts();
  }

  Stream<List<Product>> watchProducts() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_sharedProductsController != null &&
        !_sharedProductsController!.isClosed &&
        _sharedWatchUid == uid) {
      return _sharedProductsController!.stream;
    }

    _tearDownSharedProductsWatch();

    late final StreamController<List<Product>> controller;
    controller = StreamController<List<Product>>.broadcast(
      onListen: () {
        final cached = _lastSharedProducts;
        if (cached != null && !controller.isClosed) {
          controller.add(cached);
        }
      },
    );
    _sharedProductsController = controller;
    _sharedWatchUid = uid;
    _sharedCatalog = null;
    _sharedInventory = null;
    _lastSharedProducts = null;
    productsWatchGeneration.value++;

    void onError(Object e, StackTrace st) {
      _log('watchProducts error', e, st);
      if (!controller.isClosed) controller.addError(e, st);
    }

    _sharedCatalogSub = _watchCatalog().listen((value) {
      _sharedCatalog = value;
      _emitSharedProducts();
    }, onError: onError);

    final invStream = _userInventory() == null
        ? Stream.value(const <Product>[])
        : _watchUserInventory();
    _sharedInventorySub = invStream.listen((value) {
      _sharedInventory = value;
      _emitSharedProducts();
    }, onError: onError);

    return controller.stream;
  }

  Future<Product?> getCatalogProductByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    try {
      final doc = await _catalog.doc(_sanitizeDocId(code)).get();
      if (doc.exists && doc.data() != null) {
        return Product.fromFirestore(
          doc.id,
          {
            ...doc.data()!,
            'barcode': doc.data()!['barcode'] ?? code,
          },
          isCatalogOnly: true,
        );
      }

      final query =
          await _catalog.where('barcode', isEqualTo: code).limit(1).get();
      if (query.docs.isNotEmpty) {
        final found = query.docs.first;
        return Product.fromFirestore(
            found.id,
            {
              ...found.data(),
              'barcode': code,
            },
            isCatalogOnly: true);
      }
      return null;
    } catch (e, st) {
      _log('getCatalogProductByBarcode failed for $code', e, st);
      rethrow;
    }
  }

  Future<List<String>> fetchCategorySuggestions() async {
    final names = <String>{};
    try {
      final catalogSnap = await _catalog.limit(500).get();
      for (final doc in catalogSnap.docs) {
        final c = (doc.data()['category'] ?? '').toString().trim();
        if (c.isNotEmpty) names.add(c);
      }
    } catch (e) {
      _log('fetchCategorySuggestions catalog failed', e);
    }

    final inv = _userInventory();
    if (inv != null) {
      try {
        final invSnap = await inv.limit(500).get();
        for (final doc in invSnap.docs) {
          final data = doc.data();
          if (data['hidden'] == true) continue;
          final c = (data['category'] ?? '').toString().trim();
          if (c.isNotEmpty) names.add(c);
        }
      } catch (e) {
        _log('fetchCategorySuggestions inventory failed', e);
      }
    }

    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    try {
      final inv = _userInventory();
      if (inv != null) {
        final docId = _sanitizeDocId(code);
        final doc = await inv.doc(docId).get();
        if (doc.exists && doc.data() != null) {
          final user = Product.fromFirestore(doc.id, {
            ...doc.data()!,
            'barcode': doc.data()!['barcode'] ?? code,
          });
          if (user.hidden) return null;

          final catalog = await getCatalogProductByBarcode(code);
          if (catalog != null) {
            return Product.mergeCatalogWithUser(catalog, user);
          }
          return user;
        }

        final query =
            await inv.where('barcode', isEqualTo: code).limit(1).get();
        if (query.docs.isNotEmpty) {
          final found = query.docs.first;
          final user = Product.fromFirestore(found.id, {
            ...found.data(),
            'barcode': code,
          });
          if (user.hidden) return null;
          final catalog = await getCatalogProductByBarcode(code);
          if (catalog != null) {
            return Product.mergeCatalogWithUser(catalog, user);
          }
          return user;
        }
      }

      return await getCatalogProductByBarcode(code);
    } catch (e, st) {
      _log('getProductByBarcode failed for $code', e, st);
      rethrow;
    }
  }

  Future<void> registerProduct(Product product) async {
    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to register a product');
    }

    final code = product.barcode.trim();
    final catalog =
        code.isEmpty ? null : await getCatalogProductByBarcode(code);
    final catalogProductId = catalog?.id ?? product.catalogProductId;
    final docId = inventoryDocId(
      barcode: code,
      catalogProductId: catalogProductId,
      name: product.name,
      size: product.size,
    );
    final existingId = code.isEmpty
        ? await _existingInventoryIdByIdentity(inv, product)
        : await _existingInventoryId(
            inv,
            barcode: code,
            preferredId: docId,
          );
    final targetId = existingId ?? docId;
    final data = _withTimestamps(
      _normalizeProductFields({
        ...product.toMap(),
        'barcode': code,
        'hidden': false,
        if (catalogProductId.isNotEmpty) 'catalogProductId': catalogProductId,
      }),
      isCreate: existingId == null,
    );
    _log('registerProduct users/.../inventory/$targetId');
    await _db.runTransaction((transaction) async {
      final ref = inv.doc(targetId);
      final snapshot = await transaction.get(ref);
      final existing = snapshot.data();
      final payload = existing == null
          ? data
          : {
              ...data,
              'stock':
                  Product.fromMap(targetId, existing).stock + product.stock,
            };
      transaction.set(ref, payload, SetOptions(merge: true));
    });
  }

  Future<void> updateProduct(
    String oldBarcode,
    Product updated, {
    String? oldInventoryId,
  }) async {
    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to update a product');
    }

    final catalog = updated.catalogProductId.isNotEmpty
        ? null
        : await getCatalogProductByBarcode(oldBarcode);
    final catalogProductId = updated.catalogProductId.isNotEmpty
        ? updated.catalogProductId
        : (catalog?.id ?? (updated.isCatalogOnly ? updated.id : ''));
    final data = _withTimestamps(
      _normalizeProductFields({
        ...updated.toMap(),
        'barcode': updated.barcode.trim(),
        'hidden': false,
        if (catalogProductId.isNotEmpty) 'catalogProductId': catalogProductId,
      }),
    );

    final oldId = (oldInventoryId ?? '').trim().isNotEmpty
        ? _sanitizeDocId(oldInventoryId!.trim())
        : inventoryDocId(
            barcode: oldBarcode.trim(),
            catalogProductId: catalogProductId,
            name: updated.name,
            size: updated.size,
          );
    final newId = inventoryDocId(
      barcode: updated.barcode.trim(),
      catalogProductId: catalogProductId,
      name: updated.name,
      size: updated.size,
    );

    if (oldId == newId) {
      await inv.doc(oldId).set(data, SetOptions(merge: true));
    } else {
      final batch = _db.batch();
      batch.set(inv.doc(newId), data);
      batch.delete(inv.doc(oldId));
      await batch.commit();
    }
    _log('updateProduct ${updated.barcode} (copy-on-write OK)');
  }

  Future<void> deleteProduct(Product product) async {
    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to delete a product');
    }

    final code = product.barcode.trim();
    final displayCode = code.isNotEmpty ? code : product.id.trim();
    final isCatalogBacked = product.isCatalogOnly ||
        product.catalogProductId.isNotEmpty ||
        await _catalogExists(product);

    final catalogId = product.catalogProductId.isNotEmpty
        ? product.catalogProductId
        : product.id;
    final docId = isCatalogBacked && code.isNotEmpty
        ? await inventoryDocumentIdForBarcode(
            code,
            catalogProductId: catalogId,
          )
        : isCatalogBacked
            ? inventoryDocId(
                barcode: '',
                catalogProductId: catalogId,
                name: product.name,
                size: product.size,
              )
            : _sanitizeDocId(product.id);

    if (isCatalogBacked) {
      final data = _withTimestamps(
        _normalizeProductFields({
          ...product.toMap(),
          'barcode': code,
          'hidden': true,
          'catalogProductId': catalogId,
        }),
      );
      await inv.doc(docId).set(data, SetOptions(merge: true));
      _log('deleteProduct soft-hide catalog-backed $displayCode');
      return;
    }

    await inv.doc(docId).delete();
    _log('deleteProduct hard-delete custom $displayCode');
  }

  Future<bool> _catalogExists(Product product) async {
    try {
      final byId = await _catalog.doc(product.id).get();
      if (byId.exists) return true;
      final code = product.barcode.trim();
      if (code.isEmpty) return false;
      final byCode = await _catalog.doc(_sanitizeDocId(code)).get();
      if (byCode.exists) return true;
      final q = await _catalog.where('barcode', isEqualTo: code).limit(1).get();
      return q.docs.isNotEmpty;
    } catch (e) {
      _log('_catalogExists failed', e);
      return false;
    }
  }

  Future<void> addStock(String productId, int quantityToAdd) async {
    if (quantityToAdd <= 0) {
      throw ArgumentError('quantityToAdd must be > 0');
    }

    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to add stock');
    }

    final code = productId.trim();
    final catalogSeed = await getCatalogProductByBarcode(code);
    final docId = await inventoryDocumentIdForBarcode(
      code,
      catalogProductId: catalogSeed?.id,
    );

    final existing = await inv.doc(docId).get();
    if (!existing.exists && catalogSeed == null) {
      throw StateError('Product $code not found — cannot add stock');
    }

    await _db.runTransaction((tx) async {
      final ref = inv.doc(docId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final catalog = catalogSeed;
        if (catalog == null) {
          throw StateError('Product $code not found — cannot add stock');
        }
        final owned = _normalizeProductFields({
          ...catalog.toMap(),
          'stock': catalog.stock + quantityToAdd,
          'barcode': code,
          'catalogProductId': catalog.id,
          'hidden': false,
        });
        tx.set(
          ref,
          _withTimestamps(owned, isCreate: true),
          SetOptions(merge: true),
        );
        return;
      }

      final patch = {
        ...?snap.data(),
        'stock': FieldValue.increment(quantityToAdd),
        'barcode': code,
        'hidden': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.set(ref, patch, SetOptions(merge: true));
    });
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
  }) async {
    final inv = _userInventory();
    if (inv == null) {
      throw StateError('Sign in required to save inventory');
    }

    final code = barcode.trim();
    if (code.isEmpty) throw ArgumentError('Barcode required');
    if (name.trim().isEmpty) throw ArgumentError('Product name required');
    if (price < 0) throw ArgumentError('Price cannot be negative');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative');

    final docId = inventoryDocId(
      barcode: code,
      catalogProductId: catalogProductId,
      name: name,
      size: '',
    );
    final existingId = await _existingInventoryId(
      inv,
      barcode: code,
      preferredId: catalogProductId ?? docId,
    );
    final targetId = existingId ?? docId;

    return _db.runTransaction((tx) async {
      final ref = inv.doc(targetId);
      final snap = await tx.get(ref);
      final existing = snap.exists ? snap.data() : null;

      final currentStock = Product.fromMap(docId, existing ?? {}).stock;
      final nextStock = addToExistingStock ? currentStock + quantity : quantity;

      final owned = _normalizeProductFields({
        'name': name.trim(),
        'category': category.trim(),
        'sku': (sku ?? code).trim(),
        'price': price,
        'stock': nextStock,
        'imageUrl': imageUrl,
        'barcode': code,
        'hidden': false,
        if (catalogProductId != null && catalogProductId.isNotEmpty)
          'catalogProductId': catalogProductId.trim(),
      });

      final data = _withTimestamps(owned, isCreate: existing == null);
      tx.set(ref, data, SetOptions(merge: true));

      return Product.fromFirestore(targetId, {
        ...data,
        'stock': nextStock,
        'createdAt': null,
        'updatedAt': null,
      });
    });
  }

  Future<Product> copyCatalogToInventory({
    required Product catalogProduct,
    required double price,
    required int stock,
  }) async {
    final barcode = catalogProduct.barcode.trim();
    final id = barcode.isNotEmpty ? barcode : catalogProduct.id.trim();
    return upsertInventoryItem(
      barcode: id,
      name: catalogProduct.name,
      category: catalogProduct.category,
      price: price,
      quantity: stock,
      imageUrl: catalogProduct.imageUrl,
      sku: catalogProduct.sku,
      addToExistingStock: false,
      catalogProductId: catalogProduct.id,
    );
  }
}
