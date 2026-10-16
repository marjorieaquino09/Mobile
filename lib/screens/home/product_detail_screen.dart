import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/product_categories.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../services/notification_store.dart';
import '../../services/product_repository.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';
import '../scan/barcode_scan_page.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? product;

  const ProductDetailScreen({super.key, this.product});

  static Future<void> show(BuildContext context, {Product? product}) {
    final sari = context.sari;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sari.shadow,
      builder: (_) => ProductDetailScreen(product: product),
    );
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  final ProductRepository _products = ProductRepository.instance;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;

  late String _category;
  String _imageUrl = '';
  bool _saving = false;
  String? _barcodeError;
  String? _priceError;
  String? _stockError;

  bool get _isEditing => widget.product != null;

  List<String> get _categories {
    final values = ProductCategories.forPicker.toList();
    if (_category.isNotEmpty && !values.contains(_category)) {
      values.insert(0, _category);
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockController =
        TextEditingController(text: p != null ? p.stock.toString() : '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _imageUrl = p?.imageUrl ?? '';
    final existing = p?.category.trim() ?? '';
    _category = existing.isEmpty ? 'Snacks' : existing;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    if (_isEditing) return;
    final code = await BarcodeScanPage.scan(context);
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _barcodeController.text = code);
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 60,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Str = base64Encode(bytes);
    setState(() {
      _imageUrl = 'data:image/jpeg;base64,$base64Str';
    });
  }

  Future<void> _pasteImageLink() async {
    final controller = TextEditingController(
      text: _imageUrl.startsWith('data:image') ? '' : _imageUrl,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sari.cardSurfaceStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(context.l10n.text('pasteImageLink'),
            style: TextStyle(color: scheme.onSurface)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: sari.faintText),
            filled: true,
            fillColor: sari.fieldFill.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.text('cancel'),
                style: TextStyle(color: sari.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.text('save')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _imageUrl = result);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: sari.cardSurfaceStrong,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: sari.success.withValues(alpha: 0.18),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sari.success.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.text('productPhoto'),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: sari.fieldFill,
                  child:
                      Icon(Icons.photo_library_outlined, color: sari.success),
                ),
                title: Text(context.l10n.text('chooseGallery'),
                    style: TextStyle(color: scheme.onSurface)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: sari.fieldFill,
                  child: Icon(Icons.link, color: sari.success),
                ),
                title: Text(context.l10n.text('pasteImageLink'),
                    style: TextStyle(color: scheme.onSurface)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pasteImageLink();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('productNameRequired'))),
      );
      return;
    }

    final barcode = _barcodeController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    final barcodeError =
        barcode.isEmpty ? context.l10n.text('barcodeRequired') : null;
    final priceError = (price == null || price < 0)
        ? context.l10n.text('invalidPrice')
        : null;
    final stockError = (stock == null || stock < 1)
        ? context.l10n.text('quantityMinimum')
        : null;

    if (barcodeError != null || priceError != null || stockError != null) {
      setState(() {
        _barcodeError = barcodeError;
        _priceError = priceError;
        _stockError = stockError;
      });
      return;
    }

    setState(() {
      _barcodeError = null;
      _priceError = null;
      _stockError = null;
      _saving = true;
    });

    final updatedProduct = Product(
      id: barcode,
      name: _nameController.text.trim(),
      size: widget.product?.size ?? '',
      category: _category,
      // SKU is kept internally as barcode — not shown on Home UI.
      sku: barcode,
      price: price!,
      stock: stock!,
      imageUrl: _imageUrl,
      barcode: barcode,
    );

    try {
      if (_isEditing) {
        final source = widget.product!;
        final withMeta = updatedProduct.copyWith(
          id: source.id,
          catalogProductId: source.catalogProductId.isNotEmpty
              ? source.catalogProductId
              : (source.isCatalogOnly ? source.id : ''),
          isCatalogOnly: false,
        );
        await _products.updateProduct(
          source.barcode,
          withMeta,
          oldInventoryId: source.id,
        );
        await NotificationStore.instance.addInventoryEvent(
          action: 'edited',
          productName: withMeta.name,
          stock: withMeta.stock,
        );
      } else {
        await _products.registerProduct(updatedProduct);
        await NotificationStore.instance.addInventoryEvent(
          action: 'added',
          productName: updatedProduct.name,
          stock: updatedProduct.stock,
        );
      }
      if (updatedProduct.isLowStock || updatedProduct.isOutOfStock) {
        await NotificationStore.instance.addLowStockAlert(
          productName: updatedProduct.name,
          stock: updatedProduct.stock,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text(
            _isEditing ? 'productUpdated' : 'productAdded',
          )),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = '$e'.toLowerCase().contains('not found')
          ? context.l10n.text('productNotFound')
          : context.l10n.text('failed', values: {'error': '$e'});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if ('$e'.toLowerCase().contains('not found')) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sari.cardSurfaceStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          context.l10n.text('removeProductTitle'),
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          context.l10n.text(
            'removeProductConfirmMessage',
            values: {'name': widget.product!.name},
          ),
          style: TextStyle(color: sari.mutedText, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.text('keep'),
                style: TextStyle(color: sari.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: sari.danger,
              foregroundColor: scheme.onError,
              minimumSize: const Size(120, 44),
            ),
            child: Text(context.l10n.text('remove')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _products.deleteProduct(widget.product!);
      await NotificationStore.instance.addInventoryEvent(
        action: 'deleted',
        productName: widget.product!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('productRemoved'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = '$e'.toLowerCase().contains('not found')
          ? context.l10n.text('productNotFound')
          : context.l10n.text('failed', values: {'error': '$e'});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _saving = false);
      if ('$e'.toLowerCase().contains('not found')) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              gradient: sari.modalGradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: sari.success.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: sari.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sari.success.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: sari.mutedText),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              context.l10n.text(
                                _isEditing
                                    ? 'productEditTitle'
                                    : 'productNewTitle',
                              ),
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              context.l10n.text(
                                _isEditing
                                    ? 'productEditSubtitle'
                                    : 'productNewSubtitle',
                              ),
                              style: TextStyle(
                                color: sari.faintText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageOptions,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  color: sari.imagePlaceholder,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: sari.shadow,
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: ProductImage(
                                    imageUrl: _imageUrl,
                                    fit: BoxFit.cover,
                                    placeholderIcon: Icons.add_a_photo_outlined,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: sari.warning,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sari.onAccent,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(Icons.camera_alt_outlined,
                                    size: 14, color: sari.onAccent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _field(
                          label: context.l10n.text('itemName'),
                          controller: _nameController,
                          icon: Icons.inventory_2_outlined,
                        ),
                        _categoryField(),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: context.l10n.text(
                                  'priceLabel',
                                  values: {
                                    'symbol':
                                        SettingsStore.instance.currencySymbol,
                                  },
                                ),
                                controller: _priceController,
                                icon: Icons.payments_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                errorText: _priceError,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                label: context.l10n.text('stock'),
                                controller: _stockController,
                                icon: Icons.layers_outlined,
                                keyboardType: TextInputType.number,
                                errorText: _stockError,
                              ),
                            ),
                          ],
                        ),
                        _field(
                          label: context.l10n.text('barcode'),
                          controller: _barcodeController,
                          icon: Icons.qr_code_2,
                          readOnly: _isEditing,
                          errorText: _barcodeError,
                          suffix: _isEditing
                              ? null
                              : IconButton(
                                  tooltip: context.l10n.text('navScan'),
                                  onPressed: _scanBarcode,
                                  icon: Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: sari.success,
                                    size: 22,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: sari.onAccent,
                                    ),
                                  )
                                : Text(_isEditing
                                    ? context.l10n.text('saveChanges')
                                    : context.l10n.text('addProduct')),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: Text(context.l10n.text('removeProduct')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: sari.danger,
                                side: BorderSide(color: sari.danger),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _categories.contains(_category) ? _category : null,
        items: _categories
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(c, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _category = value);
        },
        dropdownColor: sari.cardSurfaceStrong,
        icon: Icon(Icons.keyboard_arrow_down, color: sari.success),
        style: TextStyle(color: scheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          labelText: context.l10n.text('category'),
          prefixIcon:
              Icon(Icons.category_outlined, color: sari.success, size: 20),
          labelStyle: TextStyle(color: sari.mutedText),
          filled: true,
          fillColor: sari.fieldFill.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    Widget? suffix,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(color: scheme.onSurface),
        onChanged: (_) {
          if (_barcodeError != null ||
              _priceError != null ||
              _stockError != null) {
            setState(() {
              _barcodeError = null;
              _priceError = null;
              _stockError = null;
            });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: sari.success, size: 20),
          suffixIcon: suffix,
          errorText: errorText,
          labelStyle: TextStyle(color: sari.mutedText),
          filled: true,
          fillColor: sari.fieldFill.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
