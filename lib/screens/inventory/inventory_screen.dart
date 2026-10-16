import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_store.dart';
import '../../services/product_repository.dart';
import '../../services/settings_store.dart';
import '../../widgets/stat_card.dart';
import '../home/product_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? userName;

  const InventoryScreen({
    super.key,
    this.userName,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductRepository _products = ProductRepository.instance;
  final FirebaseService _firebase = FirebaseService();
  late Stream<List<Product>> _productStream;
  final _searchController = TextEditingController();
  String _storeName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _productStream = _products.watchProducts();
    _fetchStoreName();
  }

  void _retryProducts() {
    setState(() {
      _productStream = _products.watchProducts();
    });
  }

  int _bestSellerQuantity(
    List<Product> products,
    QuerySnapshot? orders,
  ) {
    final productKeys = <String, String>{};
    for (final product in products) {
      final key = product.id;
      if (product.barcode.isNotEmpty) {
        productKeys[product.barcode.toLowerCase()] = key;
      }
      productKeys[key.toLowerCase()] = key;
    }

    final quantities = <String, int>{};
    for (final order in orders?.docs ?? const []) {
      final data = order.data();
      if (data is! Map<String, dynamic>) continue;
      final items = data['items'];
      if (items is! List) continue;
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final barcode =
            (item['barcode'] ?? item['id'] ?? '').toString().toLowerCase();
        final productKey = productKeys[barcode];
        if (productKey == null) continue;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        quantities.update(
          productKey,
          (previous) => previous + quantity,
          ifAbsent: () => quantity,
        );
      }
    }
    return quantities.values
        .fold<int>(0, (best, quantity) => quantity > best ? quantity : best);
  }

  Future<void> _fetchStoreName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          if (!mounted) return;
          setState(() {
            _storeName = doc.data()!['storeName'] ?? 'Sari-Sari Store';
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _storeName = widget.userName ?? 'Sari-Sari Store';
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _storeName = widget.userName ?? 'Sari-Sari Store';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStockColor(int stock) {
    final sari = context.sari;
    if (stock == 0) {
      return sari.danger;
    } else if (stock <= 5) {
      return sari.accentAmber;
    } else {
      return sari.success;
    }
  }

  void _openAddProduct() {
    ProductDetailScreen.show(context);
  }

  void _openFullEdit(Product product) {
    ProductDetailScreen.show(context, product: product);
  }

  void _showQuickEditDialog(Product product) {
    final priceController =
        TextEditingController(text: product.price.toStringAsFixed(2));
    final stockController =
        TextEditingController(text: product.stock.toString());
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: sari.cardSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: GoogleFonts.outfit(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.text('quickUpdatePriceStock'),
                style: GoogleFonts.outfit(
                  color: sari.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                hintText: context.l10n.text(
                  'priceLabel',
                  values: {'symbol': SettingsStore.instance.currencySymbol},
                ),
                prefixIcon: Icons.payments_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                hintText: context.l10n.text('stockQuantity'),
                prefixIcon: Icons.layers_outlined,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _openFullEdit(product);
                  },
                  child: Text(
                    context.l10n.text('editAllDetails'),
                    style: GoogleFonts.outfit(
                      color: sari.accentAmber,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                context.l10n.text('cancel'),
                style: GoogleFonts.outfit(color: sari.mutedText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final parsedPrice = double.tryParse(priceController.text.trim());
                final parsedStock = int.tryParse(stockController.text.trim());
                if (parsedPrice == null || parsedPrice < 0) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.text('invalidPrice')),
                        backgroundColor: sari.danger,
                      ),
                    );
                  }
                  return;
                }
                if (parsedStock == null || parsedStock < 0) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.text('quantityMinimum')),
                        backgroundColor: sari.danger,
                      ),
                    );
                  }
                  return;
                }

                final updated = Product(
                  id: product.id,
                  name: product.name,
                  size: product.size,
                  category: product.category,
                  sku: product.sku,
                  price: parsedPrice,
                  stock: parsedStock,
                  imageUrl: product.imageUrl,
                  barcode: product.barcode,
                  catalogProductId: product.catalogProductId.isNotEmpty
                      ? product.catalogProductId
                      : (product.isCatalogOnly ? product.id : ''),
                );

                try {
                  await _products.updateProduct(
                    product.barcode,
                    updated,
                    oldInventoryId: product.id,
                  );
                  await NotificationStore.instance.addInventoryEvent(
                    action: 'edited',
                    productName: updated.name,
                    stock: updated.stock,
                  );
                  if (updated.isLowStock || updated.isOutOfStock) {
                    await NotificationStore.instance.addLowStockAlert(
                      productName: updated.name,
                      stock: updated.stock,
                    );
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                } catch (e) {
                  if (!dialogCtx.mounted) return;
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.text(
                        'failed',
                        values: {'error': '$e'},
                      )),
                      backgroundColor: sari.danger,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(context.l10n.text('save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: context.l10n.text('removeProductTitle'),
      message: context.l10n
          .text('removeProductMessage', values: {'name': product.name}),
      confirmLabel: context.l10n.text('remove'),
      cancelLabel: context.l10n.text('keep'),
      isDestructive: true,
    );

    if (confirm != true) return;
    try {
      await _products.deleteProduct(product);
      await NotificationStore.instance.addInventoryEvent(
        action: 'deleted',
        productName: product.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('productRemoved'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text(
            'failed',
            values: {'error': '$e'},
          )),
          backgroundColor: context.sari.danger,
        ),
      );
    }
  }

  /// Fixed-width edit + delete so both stay visible on narrow phones.
  Widget _productActions(Product product, ColorScheme scheme, SariColors sari) {
    const tap = 40.0;
    return SizedBox(
      width: tap * 2 + 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => _showQuickEditDialog(product),
            tooltip: context.l10n.text('edit'),
            icon: Icon(Icons.edit_outlined, size: 20, color: scheme.primary),
            constraints: const BoxConstraints(minWidth: tap, minHeight: tap),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _deleteProduct(product),
            tooltip: context.l10n.text('remove'),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: sari.danger,
            ),
            constraints: const BoxConstraints(minWidth: tap, minHeight: tap),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _stockChip(int stock, Color stockColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: stockColor.withValues(alpha: 0.18),
        border: Border.all(
          color: stockColor.withValues(alpha: 0.6),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$stock',
        style: GoogleFonts.outfit(
          color: stockColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _productListRow({
    required Product product,
    required bool narrow,
    required ColorScheme scheme,
    required SariColors sari,
  }) {
    final stockColor = _getStockColor(product.stock);
    final actions = _productActions(product, scheme, sari);
    final nameStyle = GoogleFonts.outfit(
      color: scheme.onSurface,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    final metaStyle = GoogleFonts.outfit(
      color: sari.faintText,
      fontSize: 11,
    );
    final priceStyle = GoogleFonts.outfit(
      color: scheme.onSurface,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );

    if (narrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                ),
                actions,
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.barcode.isNotEmpty ? product.barcode : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                ),
                Text(
                  SettingsStore.instance.formatMoney(product.price),
                  style: priceStyle,
                ),
                const SizedBox(width: 10),
                _stockChip(product.stock, stockColor),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              product.barcode.isNotEmpty ? product.barcode : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              SettingsStore.instance.formatMoney(product.price),
              style: priceStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _stockChip(product.stock, stockColor),
            ),
          ),
          actions,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: sari.fieldFill,
                    child: Icon(
                      Icons.storefront_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: scheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.l10n.text('manageStore'),
                          style: GoogleFonts.outfit(
                            color: sari.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: sari.accentAmber,
                      size: 24,
                    ),
                    tooltip: context.l10n.text('addItem'),
                    onPressed: _openAddProduct,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search input
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.outfit(
                  color: scheme.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.text('searchItems'),
                  hintStyle: GoogleFonts.outfit(
                    color: sari.faintText,
                    fontSize: 13,
                  ),
                  prefixIcon:
                      Icon(Icons.search, color: sari.mutedText, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: sari.mutedText, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: sari.fieldFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: _productStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData &&
                        !snapshot.hasError) {
                      return const LoadingIndicator();
                    }

                    if (snapshot.hasError) {
                      return EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: context.l10n.text('inventoryLoadFailed'),
                        message: '${snapshot.error}',
                        actionLabel: context.l10n.text('tryAgain'),
                        onAction: _retryProducts,
                      );
                    }

                    final products = snapshot.data ?? const <Product>[];

                    final filteredProducts = products.where((p) {
                      final query = _searchController.text.toLowerCase();
                      return p.name.toLowerCase().contains(query) ||
                          p.barcode.toLowerCase().contains(query) ||
                          p.category.toLowerCase().contains(query);
                    }).toList();

                    final totalItems = products.length;
                    final lowStock = products.where((p) => p.isLowStock).length;
                    final outOfStock =
                        products.where((p) => p.isOutOfStock).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: context.l10n.text('totalItemsStat'),
                                value: '$totalItems',
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatCard(
                                label: context.l10n.text('lowStockStat'),
                                value: '$lowStock',
                                valueColor:
                                    lowStock > 0 ? sari.accentAmber : null,
                                icon: Icons.warning_amber_rounded,
                                iconColor: sari.accentAmber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _firebase.getOrdersStream(limit: 200),
                                builder: (context, ordersSnapshot) {
                                  final value = ordersSnapshot.hasError
                                      ? '—'
                                      : '${_bestSellerQuantity(
                                          products,
                                          ordersSnapshot.data,
                                        )}';
                                  return StatCard(
                                    label: context.l10n.text('bestSellersStat'),
                                    value: value,
                                    icon: Icons.trending_up_rounded,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatCard(
                                label: context.l10n.text('outOfStockStat'),
                                value: '$outOfStock',
                                valueColor: outOfStock > 0 ? sari.danger : null,
                                icon: Icons.remove_circle_outline_rounded,
                                iconColor: sari.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(10),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Card-style rows below ~400 logical px so
                                // edit+delete never clip at 320/360/411 dp.
                                final narrow = constraints.maxWidth < 400;
                                final headerStyle = GoogleFonts.outfit(
                                  color: sari.mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                );

                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      child: narrow
                                          ? Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    context.l10n
                                                        .text('colItem'),
                                                    style: headerStyle,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 88,
                                                  child: Text(
                                                    context.l10n
                                                        .text('colActions'),
                                                    textAlign: TextAlign.end,
                                                    style: headerStyle,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    context.l10n
                                                        .text('colItem'),
                                                    style: headerStyle,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    context.l10n
                                                        .text('colCode'),
                                                    style: headerStyle,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    context.l10n
                                                        .text('colPrice'),
                                                    style: headerStyle,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    context.l10n
                                                        .text('colStock'),
                                                    style: headerStyle,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 88,
                                                  child: Text(
                                                    context.l10n
                                                        .text('colActions'),
                                                    textAlign: TextAlign.end,
                                                    style: headerStyle,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                    Divider(
                                      color: sari.cardBorder,
                                      thickness: 1,
                                      height: 8,
                                    ),
                                    Expanded(
                                      child: filteredProducts.isEmpty
                                          ? Center(
                                              child: Text(
                                                context.l10n
                                                    .text('noProducts'),
                                                style: GoogleFonts.outfit(
                                                  color: sari.mutedText,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              itemCount:
                                                  filteredProducts.length,
                                              separatorBuilder: (_, __) =>
                                                  Divider(
                                                color: sari.cardBorder,
                                                height: 1,
                                                thickness: 0.5,
                                              ),
                                              itemBuilder: (context, index) {
                                                return _productListRow(
                                                  product:
                                                      filteredProducts[index],
                                                  narrow: narrow,
                                                  scheme: scheme,
                                                  sari: sari,
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
