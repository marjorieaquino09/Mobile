import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../services/user_profile_store.dart';
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
  final UserProfileStore _profile = UserProfileStore.instance;
  final FirebaseService _firebase = FirebaseService();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profile.ensureLoaded();
  }

  void _retryProducts() {
    _products.refreshProducts();
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
                final parsedPrice =
                    double.tryParse(priceController.text.trim());
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

  Widget _productActions(
    Product product,
    ColorScheme scheme,
    SariColors sari, {
    required double tap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: () => _showQuickEditDialog(product),
          tooltip: context.l10n.text('edit'),
          icon: Icon(Icons.edit_outlined, size: 18, color: scheme.primary),
          constraints: BoxConstraints(minWidth: tap, minHeight: tap),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => _deleteProduct(product),
          tooltip: context.l10n.text('remove'),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: sari.danger.withValues(alpha: 0.85),
          ),
          constraints: BoxConstraints(minWidth: tap, minHeight: tap),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _stockChip(int stock, Color stockColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

  Widget _tableRow({
    required bool compact,
    required Widget item,
    required Widget code,
    required Widget price,
    required Widget stock,
    required Widget actions,
  }) {
    final priceW = compact ? 58.0 : 84.0;
    final stockW = compact ? 40.0 : 60.0;
    final actionsW = compact ? 64.0 : 88.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: compact ? 5 : 4, child: item),
        const SizedBox(width: 6),
        Expanded(flex: compact ? 4 : 3, child: code),
        const SizedBox(width: 6),
        SizedBox(width: priceW, child: price),
        SizedBox(width: stockW, child: stock),
        SizedBox(width: actionsW, child: actions),
      ],
    );
  }

  Widget _headerCell(
    String text,
    TextStyle style, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }

  Widget _productListRow({
    required Product product,
    required bool compact,
    required ColorScheme scheme,
    required SariColors sari,
  }) {
    final stockColor = _getStockColor(product.stock);
    final nameStyle = GoogleFonts.outfit(
      color: scheme.onSurface,
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );

    final barcodeLength = product.barcode.length;
    final double barcodeFontSize =
        compact ? (barcodeLength > 10 ? 9.0 : 10.5) : 11.0;

    final metaStyle = GoogleFonts.outfit(
      color: sari.mutedText,
      fontSize: barcodeFontSize,
      letterSpacing: -0.2,
      height: 1.2,
    );
    final priceStyle = GoogleFonts.outfit(
      color: scheme.onSurface,
      fontSize: compact ? 11.5 : 12,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10, horizontal: 2),
      child: _tableRow(
        compact: compact,
        item: Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        code: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            product.barcode.isNotEmpty ? product.barcode : '—',
            maxLines: 1,
            style: metaStyle,
          ),
        ),
        price: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            SettingsStore.instance.formatMoney(product.price),
            style: priceStyle,
          ),
        ),
        stock: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _stockChip(product.stock, stockColor),
          ),
        ),
        actions: _productActions(
          product,
          scheme,
          sari,
          tap: compact ? 30 : 40,
        ),
      ),
    );
  }

  Widget _inventoryTable(
    List<Product> items,
    ColorScheme scheme,
    SariColors sari,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          final headerStyle = GoogleFonts.outfit(
            color: scheme.onSurface.withValues(alpha: 0.75),
            fontSize: compact ? 10 : 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? 0.4 : 0.6,
          );

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: _tableRow(
                  compact: compact,
                  item: _headerCell(context.l10n.text('colItem'), headerStyle),
                  code: _headerCell(context.l10n.text('colCode'), headerStyle),
                  price:
                      _headerCell(context.l10n.text('colPrice'), headerStyle),
                  stock:
                      _headerCell(context.l10n.text('colStock'), headerStyle),
                  actions: _headerCell(
                    context.l10n.text('colActions'),
                    headerStyle,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
              Divider(color: sari.cardBorder, thickness: 1, height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.text('noProducts'),
                          style: GoogleFonts.outfit(
                            color: sari.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          color: sari.cardBorder,
                          height: 1,
                          thickness: 0.5,
                        ),
                        itemBuilder: (context, index) => _productListRow(
                          product: items[index],
                          compact: compact,
                          scheme: scheme,
                          sari: sari,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
        ),
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _profile,
              _products.productsWatchGeneration,
            ]),
            builder: (context, _) {
              final storeName = _profile.headerStoreName;
              final productStream = _products.watchProducts();

              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: sari.fieldFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sari.cardBorder,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: scheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: scheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.text('manageStore'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                          fontSize: 13.5,
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: sari.cardBorder,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: sari.cardBorder,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: scheme.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: StreamBuilder<List<Product>>(
                        stream: productStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return EmptyState(
                              icon: Icons.error_outline_rounded,
                              title: context.l10n.text('inventoryLoadFailed'),
                              message: '${snapshot.error}',
                              actionLabel: context.l10n.text('tryAgain'),
                              onAction: _retryProducts,
                            );
                          }

                          if (!snapshot.hasData) {
                            return const LoadingIndicator();
                          }

                          final products = snapshot.data!;

                          final filteredProducts = products.where((p) {
                            final query = _searchController.text.toLowerCase();
                            return p.name.toLowerCase().contains(query) ||
                                p.barcode.toLowerCase().contains(query) ||
                                p.category.toLowerCase().contains(query);
                          }).toList();

                          final totalItems = products.length;
                          
                          // Dynamic at totoong kalkulasyon ng low stock at out of stock batay sa mga produkto
                          final lowStock = products.where((p) => p.isLowStock).length;
                          final outOfStock = products.where((p) => p.isOutOfStock).length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: StatCard(
                                      label:
                                          context.l10n.text('totalItemsStat'),
                                      value: '$totalItems',
                                      icon: Icons.inventory_2_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: StatCard(
                                      label: context.l10n.text('lowStockStat'),
                                      value: '$lowStock',
                                      valueColor: lowStock > 0 ? sari.accentAmber : null,
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
                                      stream:
                                          _firebase.getOrdersStream(limit: 200),
                                      builder: (context, ordersSnapshot) {
                                        final value = ordersSnapshot.hasError
                                            ? '—'
                                            : '${_bestSellerQuantity(
                                                products,
                                                ordersSnapshot.data,
                                              )}';
                                        return StatCard(
                                          label: context.l10n
                                              .text('bestSellersStat'),
                                          value: value,
                                          icon: Icons.trending_up_rounded,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: StatCard(
                                      label:
                                          context.l10n.text('outOfStockStat'),
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
                                child: _inventoryTable(
                                  filteredProducts,
                                  scheme,
                                  sari,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}