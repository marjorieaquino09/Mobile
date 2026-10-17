class Product {
  final String id;
  final String name;
  final String size;
  final String category;
  final String sku;
  final double price;
  final int stock;
  final String imageUrl;
  final String barcode;
  final bool hidden;

  final bool isCatalogOnly;

  final String catalogProductId;

  Product({
    required this.id,
    required this.name,
    this.size = '',
    required this.category,
    required this.sku,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.barcode,
    this.hidden = false,
    this.isCatalogOnly = false,
    this.catalogProductId = '',
  });

  bool get isLowStock => stock > 0 && stock <= 5;
  bool get isOutOfStock => stock == 0;

  bool get isCustom => !isCatalogOnly && catalogProductId.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (size.isNotEmpty) 'size': size,
      'category': category,
      'sku': sku,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'barcode': barcode,
      if (hidden) 'hidden': true,
      if (catalogProductId.isNotEmpty) 'catalogProductId': catalogProductId,
    };
  }

  factory Product.fromMap(
    String id,
    Map<String, dynamic> map, {
    bool isCatalogOnly = false,
  }) {
    final barcode = _asString(map['barcode']).trim();
    final imageUrl = _asString(map['imageUrl']).isNotEmpty
        ? _asString(map['imageUrl'])
        : _asString(map['image']);
    final catalogId = _asString(map['catalogProductId']).trim();

    return Product(
      id: id,
      name: _asString(map['name']),
      size: _asString(map['size']),
      category: _asString(map['category']),
      sku: _asString(map['sku']),
      price: _asDouble(map['price']),
      stock: _asInt(map['stock']),
      imageUrl: imageUrl,
      barcode: barcode,
      hidden: map['hidden'] == true,
      isCatalogOnly: isCatalogOnly,
      catalogProductId: catalogId,
    );
  }

  /// Prefer Firestore document id as [id].
  factory Product.fromFirestore(
    String docId,
    Map<String, dynamic>? data, {
    bool isCatalogOnly = false,
  }) {
    return Product.fromMap(
      docId,
      data ?? const <String, dynamic>{},
      isCatalogOnly: isCatalogOnly,
    );
  }

  String get key => barcode.isNotEmpty ? barcode : id;

  Product copyWith({
    String? id,
    String? name,
    String? size,
    String? category,
    String? sku,
    double? price,
    int? stock,
    String? imageUrl,
    String? barcode,
    bool? hidden,
    bool? isCatalogOnly,
    String? catalogProductId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      hidden: hidden ?? this.hidden,
      isCatalogOnly: isCatalogOnly ?? this.isCatalogOnly,
      catalogProductId: catalogProductId ?? this.catalogProductId,
    );
  }

  Product copyWithBarcode(String newBarcode) {
    final code = newBarcode.trim();
    return copyWith(
      id: code.isNotEmpty ? code : id,
      barcode: code.isNotEmpty ? code : barcode,
    );
  }

  /// Catalog base with user inventory fields overriding price/stock/etc.
  static Product mergeCatalogWithUser(Product catalog, Product user) {
    return Product(
      id: user.id.isNotEmpty ? user.id : catalog.id,
      name: user.name.isNotEmpty ? user.name : catalog.name,
      size: user.size.isNotEmpty ? user.size : catalog.size,
      category: user.category.isNotEmpty ? user.category : catalog.category,
      sku: user.sku.isNotEmpty ? user.sku : catalog.sku,
      price: user.price,
      stock: user.stock,
      imageUrl: user.imageUrl.isNotEmpty ? user.imageUrl : catalog.imageUrl,
      barcode: user.barcode.isNotEmpty ? user.barcode : catalog.barcode,
      hidden: user.hidden,
      isCatalogOnly: false,
      catalogProductId:
          user.catalogProductId.isNotEmpty ? user.catalogProductId : catalog.id,
    );
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value.toString().trim()) ??
        double.tryParse(value.toString().trim())?.round() ??
        0;
  }
}
