import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../services/cart_store.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';
import '../cart/cart_screen.dart';

enum _ScanAction { choose, addInventory, checkout }

/// Mga pagpipiliang category sa dropdown. Palitan kung may sariling listahan.
const List<String> kProductCategories = [
  'Beverages',
  'Snacks',
  'Candy & Sweets',
  'Canned Goods',
  'Instant Noodles',
  'Condiments & Sauces',
  'Rice & Grains',
  'Dairy & Eggs',
  'Bread & Bakery',
  'Frozen',
  'Personal Care',
  'Household & Cleaning',
  'Cigarettes',
  'Others',
];

class ScanScreen extends StatefulWidget {
  final String? scannedBarcode;
  final bool showBackButton;
  final VoidCallback? onOpenCart;
  final bool isActive;

  const ScanScreen({
    super.key,
    this.scannedBarcode,
    this.showBackButton = false,
    this.onOpenCart,
    this.isActive = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  late final MobileScannerController _controller;
  final ScanService _scanService = ScanService();

  String? _lastCode;
  Product? _matchedProduct;
  Product? _catalogSuggestion;
  bool _loading = false;
  bool _torchOn = false;
  bool _busy = false;
  bool _sheetOpen = false;
  bool _scanPaused = false;
  DateTime? _debounceUntil;
  _ScanAction _action = _ScanAction.choose;
  Timer? _cartToastTimer;
  String? _cartToastMessage;

  bool _permissionDenied = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: false,
    );
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureCamera());
      });
    }
    if (widget.scannedBarcode != null && widget.scannedBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCode(widget.scannedBarcode!);
      });
    }
  }

  Future<void> _ensureCamera() async {
    if (!mounted || !widget.isActive) return;

    // Match BarcodeScanPage: Android needs an explicit runtime request.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!mounted) return;
      if (!status.isGranted) {
        setState(() {
          _permissionDenied = true;
          _permanentlyDenied =
              status.isPermanentlyDenied || status.isRestricted;
        });
        return;
      }
    }

    try {
      await _controller.start();
      if (!mounted) return;
      setState(() {
        _permissionDenied = false;
        _permanentlyDenied = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
      });
      debugPrint('[ScanScreen] camera start failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      unawaited(_ensureCamera());
    } else {
      unawaited(_controller.stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_ensureCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cartToastTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    if (_sheetOpen || _busy) return;
    if (_debounceUntil != null &&
        now.isBefore(_debounceUntil!) &&
        trimmed == _lastCode) {
      return;
    }

    HapticFeedback.mediumImpact();
    debugPrint('[ScanScreen] Scanned barcode=$trimmed — querying Firebase…');

    setState(() {
      _busy = true;
      _lastCode = trimmed;
      _loading = true;
      _matchedProduct = null;
      _catalogSuggestion = null;
      _action = _ScanAction.choose;
      _scanPaused = true;
    });

    final result = await _scanService.lookupBarcode(trimmed);
    if (!mounted) return;

    if (!result.success) {
      debugPrint('[ScanScreen] Lookup failed: ${result.message}');
      setState(() {
        _loading = false;
        _busy = false;
        _scanPaused = false;
        _lastCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: sari.danger,
        ),
      );
      return;
    }

    setState(() {
      _loading = false;
      _matchedProduct = result.product;
      _catalogSuggestion = result.catalogSuggestion;
      _busy = false;
    });

    _debounceUntil = now.add(const Duration(seconds: 2));
    await _openResultSheet(trimmed);
  }

  Future<void> _openResultSheet(String code) async {
    if (!mounted || _sheetOpen) return;
    _sheetOpen = true;
    final bottomNavPad = 88.0 + MediaQuery.paddingOf(context).bottom;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + bottomNavPad,
          ),
          child: _ScanResultCard(
            product: _matchedProduct,
            catalogSuggestion: _catalogSuggestion,
            scannedCode: code,
            action: _action,
            onActionChanged: (a) => setState(() => _action = a),
            onDismiss: () => Navigator.pop(ctx),
            onRegistered: () {
              Navigator.pop(ctx);
              _clearResult();
            },
            onOpenCart: _openCart,
            onCartAdded: _showCartAddedToast,
          ),
        );
      },
    );

    if (mounted) _clearResult();
  }

  void _openCart() {
    if (widget.onOpenCart != null) {
      widget.onOpenCart!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  void _showCartAddedToast(String message) {
    _cartToastTimer?.cancel();
    setState(() => _cartToastMessage = message);
    _cartToastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _cartToastMessage = null);
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _scanPaused || _sheetOpen) return;
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;
    _handleCode(rawValue);
  }

  void _clearResult() {
    setState(() {
      _lastCode = null;
      _matchedProduct = null;
      _catalogSuggestion = null;
      _loading = false;
      _busy = false;
      _sheetOpen = false;
      _scanPaused = false;
      _action = _ScanAction.choose;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final cartItemCount = CartStore.instance.itemCount;
        final sheetLift = _sheetOpen ? 120.0 : 0.0;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              if (_permissionDenied)
                _CameraErrorView(
                  message: context.l10n.text('cameraPermissionNeeded'),
                  onRetry: () {
                    setState(() => _permissionDenied = false);
                    unawaited(_ensureCamera());
                  },
                  showSettings: _permanentlyDenied || _permissionDenied,
                )
              else
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return _CameraErrorView(
                      message:
                          error.errorDetails?.message ?? error.errorCode.name,
                      onRetry: () => unawaited(_ensureCamera()),
                      showSettings: true,
                    );
                  },
                ),
              if (!_permissionDenied) _ScannerOverlay(bottomInset: sheetLift),
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      widget.showBackButton
                          ? _circleIconButton(
                              icon: Icons.arrow_back,
                              onTap: () => Navigator.of(context).pop(),
                            )
                          : const SizedBox(width: 42),
                      Text(
                        context.l10n.text('scanTitle'),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: scheme.shadow.withValues(alpha: 0.55),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _circleIconButton(
                            icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                            iconColor:
                                _torchOn ? sari.warning : scheme.onSurface,
                            onTap: () async {
                              await _controller.toggleTorch();
                              setState(() => _torchOn = !_torchOn);
                            },
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            children: [
                              _circleIconButton(
                                icon: Icons.shopping_cart_outlined,
                                onTap: _openCart,
                              ),
                              if (cartItemCount > 0)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: sari.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$cartItemCount',
                                      style: TextStyle(
                                        color: scheme.onError,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 110,
                  child: Center(
                    child: CircularProgressIndicator(color: sari.success),
                  ),
                ),
              if (_cartToastMessage != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) => Opacity(
                      opacity: progress,
                      child: Transform.translate(
                        offset: Offset(0, (1 - progress) * 10),
                        child: child,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: sari.cardSurfaceStrong,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sari.success.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: sari.shadow,
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: sari.success.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: sari.success,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _cartToastMessage!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: context.l10n.text('viewCart'),
                              onPressed: _openCart,
                              style: IconButton.styleFrom(
                                backgroundColor: sari.warning,
                                foregroundColor: sari.onAccent,
                                fixedSize: const Size(40, 40),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sari.shadow,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? scheme.onSurface, size: 20),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool showSettings;

  const _CameraErrorView({
    required this.message,
    required this.onRetry,
    this.showSettings = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkGreenTop,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 48),
          const SizedBox(height: 12),
          Text(
            context.l10n.text('cameraPermissionNeeded'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(context.l10n.text('tryAgain')),
          ),
          if (showSettings) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: Text(
                context.l10n.text('openAppSettings'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({this.bottomInset = 0});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    // Camera chrome stays dark in both light and dark app themes.
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = constraints.maxWidth * 0.7;
          final centerY = (constraints.maxHeight - bottomInset) / 2;
          return Stack(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.55),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth - frameSize) / 2,
                      top: centerY - frameSize / 2,
                      child: Container(
                        width: frameSize,
                        height: frameSize,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - frameSize) / 2,
                top: centerY - frameSize / 2,
                child: Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanResultCard extends StatefulWidget {
  final Product? product;
  final Product? catalogSuggestion;
  final String scannedCode;
  final _ScanAction action;
  final ValueChanged<_ScanAction> onActionChanged;
  final VoidCallback onDismiss;
  final VoidCallback onRegistered;
  final VoidCallback onOpenCart;
  final ValueChanged<String> onCartAdded;

  const _ScanResultCard({
    required this.product,
    this.catalogSuggestion,
    required this.scannedCode,
    required this.action,
    required this.onActionChanged,
    required this.onDismiss,
    required this.onRegistered,
    required this.onOpenCart,
    required this.onCartAdded,
  });

  @override
  State<_ScanResultCard> createState() => _ScanResultCardState();
}

class _ScanResultCardState extends State<_ScanResultCard> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  final ScanService _scanService = ScanService();
  final ImagePicker _picker = ImagePicker();

  // Sariling state ng card. Hindi na umaasa sa parent para mag-rebuild ang
  // bottom sheet, kaya gumagana na ang "Add to Inventory" button.
  late _ScanAction _action;

  int _quantity = 1;
  bool _saving = false;
  String _imageUrl = '';

  // Napiling category mula sa dropdown (null = wala pang napili).
  String? _category;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _action = widget.action;
    _hydrateFromProduct();
  }

  @override
  void didUpdateWidget(covariant _ScanResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product?.barcode != widget.product?.barcode ||
        oldWidget.scannedCode != widget.scannedCode) {
      _hydrateFromProduct();
    }
  }

  void _setAction(_ScanAction a) {
    setState(() => _action = a);
    widget.onActionChanged(a);
  }

  void _hydrateFromProduct() {
    final p = widget.product ?? widget.catalogSuggestion;
    _nameController.text = p?.name ?? '';
    _category = (p != null && p.category.isNotEmpty) ? p.category : null;
    _priceController.text = p != null ? p.price.toStringAsFixed(2) : '';
    _stockController.text = '1';
    _imageUrl = p?.imageUrl ?? '';
    _quantity = 1;
  }

  String? get _catalogProductId => widget.catalogSuggestion?.id;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 60,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _onCheckoutAdd() async {
    final product = widget.product;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.text('scanAddToInventoryFirst'),
          ),
        ),
      );
      return;
    }

    final alreadyInCart = CartStore.instance.quantityOf(
      product.barcode.isNotEmpty ? product.barcode : product.id,
    );
    final needed = alreadyInCart + _quantity;
    if (needed > product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.text(
              'scanInsufficientStock',
              values: {
                'stock': '${product.stock}',
                'cart': '$alreadyInCart',
                'quantity': '$_quantity',
              },
            ),
          ),
          backgroundColor: sari.danger,
        ),
      );
      return;
    }

    try {
      CartStore.instance.add(product, quantity: _quantity);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text(
            'failed',
            values: {'error': '$e'},
          )),
          backgroundColor: sari.danger,
        ),
      );
      return;
    }
    debugPrint(
      '[ScanScreen] Added to cart: ${product.barcode} x$_quantity '
      '(cart total items: ${CartStore.instance.itemCount})',
    );

    if (!mounted) return;
    widget.onCartAdded(context.l10n.text(
      'addedToCartMessage',
      values: {'quantity': '$_quantity', 'name': product.name},
    ));
    widget.onDismiss();
  }

  Future<void> _onSubmitInventory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('productNameRequired'))),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('invalidPrice'))),
      );
      return;
    }

    final qty = int.tryParse(_stockController.text.trim()) ?? _quantity;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('quantityMinimum'))),
      );
      return;
    }

    setState(() => _saving = true);
    debugPrint(
      '[ScanScreen] Saving inventory barcode=${widget.scannedCode} qty=$qty',
    );

    final result = await _scanService.addToInventory(
      barcode: widget.scannedCode,
      name: name,
      category: _category ?? 'Uncategorized',
      price: price,
      quantity: qty,
      imageUrl: _imageUrl,
      addToExistingStock: widget.product != null,
      catalogProductId: _catalogProductId,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : sari.danger,
      ),
    );

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text('itemRegistered')),
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onRegistered();
    }
  }

  Future<void> _showQuickCartEntry() async {
    final suffix = widget.scannedCode.length >= 4
        ? widget.scannedCode.substring(widget.scannedCode.length - 4)
        : widget.scannedCode;
    final priceController = TextEditingController();
    final fallbackItemName = context.l10n.text(
      'genericItemName',
      values: {'suffix': suffix},
    );
    final nameController = TextEditingController(text: fallbackItemName);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: sari.cardSurfaceStrong,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('quickAddToCart'),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    labelText: context.l10n.text('priceRequired'),
                    prefixText: '₱ ',
                    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    labelText: context.l10n.text('nameOptional'),
                    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(context.l10n.text('addToCart')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true || !mounted) return;

    final price = double.tryParse(priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('enterValidPrice'))),
      );
      return;
    }

    try {
      CartStore.instance.addOneTime(
        barcode: widget.scannedCode,
        name: nameController.text.trim().isEmpty
            ? fallbackItemName
            : nameController.text.trim(),
        price: price,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text(
            'failed',
            values: {'error': '$e'},
          )),
          backgroundColor: sari.danger,
        ),
      );
      return;
    }

    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final maxHeight = MediaQuery.of(context).size.height *
        (_action == _ScanAction.choose ? 0.30 : 0.78);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        gradient: sari.screenGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: sari.cardBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sari.faintText,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: sari.faintText, size: 20),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            _buildHeader(product),
            const SizedBox(height: 14),
            if (_action == _ScanAction.choose) ...[
              Text(
                context.l10n.text('newItemChoicePrompt'),
                style: TextStyle(
                  color: sari.mutedText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _setAction(_ScanAction.addInventory),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text(
                        context.l10n.text('addToInventory'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sari.success,
                        side: BorderSide(color: sari.success, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: product == null
                          ? _showQuickCartEntry
                          : () => _setAction(_ScanAction.checkout),
                      icon: Icon(Icons.shopping_cart,
                          size: 18, color: sari.onAccent),
                      label: Text(
                        context.l10n.text('addToCart'),
                        style: TextStyle(
                          color: sari.onAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sari.warning,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_action == _ScanAction.addInventory) ...[
              _buildInventoryForm(product),
            ] else ...[
              _buildCheckoutForm(product!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Product? product) {
    if (product != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ProductImage(
              imageUrl: product.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.category,
                    style: TextStyle(
                        color: sari.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text(product.name,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '₱${product.price.toStringAsFixed(2)} · '
                  '${context.l10n.text('inStock', values: {
                        'stock': '${product.stock}'
                      })}',
                  style: TextStyle(color: sari.mutedText, fontSize: 13),
                ),
                Text(
                  context.l10n.text(
                    'barcodePrefix',
                    values: {'barcode': widget.scannedCode},
                  ),
                  style: TextStyle(color: sari.faintText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: sari.danger.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.error_outline, color: sari.danger),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.text('newItem'),
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(
                context.l10n.text(
                  'newItemBarcode',
                  values: {'barcode': widget.scannedCode},
                ),
                style: TextStyle(color: sari.mutedText, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Inventory form helpers
  // ---------------------------------------------------------------------------

  InputDecoration _fieldDecoration({
    required String label,
    IconData? icon,
    String? prefixText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: sari.cardBorder),
    );
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixStyle: TextStyle(color: scheme.onSurface),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: sari.mutedText) : null,
      filled: true,
      fillColor: sari.fieldFill.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: TextStyle(color: sari.mutedText, fontSize: 14),
      floatingLabelStyle:
          TextStyle(color: sari.success, fontWeight: FontWeight.w600),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: sari.success, width: 1.6),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: sari.faintText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    // Kung ang category ng existing product ay wala sa listahan, isama pa rin
    // para hindi mag-crash ang dropdown.
    final options = <String>[
      ...kProductCategories,
      if (_category != null && !kProductCategories.contains(_category))
        _category!,
    ];

    return DropdownButtonFormField<String>(
      value: _category,
      isExpanded: true,
      dropdownColor: sari.cardSurfaceStrong,
      borderRadius: BorderRadius.circular(14),
      menuMaxHeight: 320,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: sari.mutedText),
      style: TextStyle(color: scheme.onSurface, fontSize: 16),
      decoration: _fieldDecoration(
        label: context.l10n.text('category'),
        icon: Icons.category_outlined,
      ),
      items: options
          .map(
            (c) => DropdownMenuItem<String>(
              value: c,
              child: Text(c, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _saving ? null : (v) => setState(() => _category = v),
    );
  }

  Widget _buildInventoryForm(Product? product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back + barcode chip
        Row(
          children: [
            InkWell(
              onTap: () => _setAction(_ScanAction.choose),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sari.fieldFill.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.arrow_back, size: 18, color: scheme.onSurface),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sari.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: sari.success.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded,
                        size: 18, color: sari.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.scannedCode,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: sari.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            context.l10n.text('autoFilledFromScan'),
            style: TextStyle(color: sari.faintText, fontSize: 11),
          ),
        ),
        const SizedBox(height: 16),

        // Product photo
        _sectionLabel('Photo'),
        Row(
          children: [
            InkWell(
              onTap: _saving ? null : _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: sari.fieldFill.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sari.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageUrl.isEmpty
                    ? Icon(Icons.add_a_photo_outlined,
                        color: sari.mutedText, size: 26)
                    : ProductImage(
                        imageUrl: _imageUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  context.l10n.text(
                    _imageUrl.isEmpty ? 'attachPicture' : 'changePicture',
                  ),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: sari.success,
                  side: BorderSide(color: sari.success.withValues(alpha: 0.6)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Details
        _sectionLabel('Details'),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: scheme.onSurface),
          decoration: _fieldDecoration(
            label: context.l10n.text('productName'),
            icon: Icons.sell_outlined,
          ),
        ),
        const SizedBox(height: 12),
        _buildCategoryDropdown(),
        const SizedBox(height: 16),

        // Price & stock
        _sectionLabel('Price & Stock'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _priceController,
                style: TextStyle(color: scheme.onSurface),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                  label: context.l10n.text('price'),
                  prefixText: '₱ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _stockController,
                style: TextStyle(color: scheme.onSurface),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: _fieldDecoration(
                  label: product != null
                      ? context.l10n.text('qtyToAdd')
                      : context.l10n.text('initialStock'),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Submit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _onSubmitInventory,
            icon: _saving
                ? const SizedBox.shrink()
                : Icon(Icons.check_circle_outline,
                    size: 20, color: sari.onAccent),
            label: _saving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: sari.onAccent,
                    ),
                  )
                : Text(
                    context.l10n.text(
                      product != null
                          ? 'saveToInventoryButton'
                          : 'registerItem',
                    ),
                    style: TextStyle(
                      color: sari.onAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: sari.warning,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutForm(Product product) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _setAction(_ScanAction.choose),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(context.l10n.text('back')),
            style: TextButton.styleFrom(foregroundColor: sari.success),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.l10n.text('quantityLabel'),
                style: TextStyle(color: sari.mutedText, fontSize: 13)),
            const SizedBox(width: 16),
            _stepperButton(Icons.remove, () {
              if (_quantity > 1) setState(() => _quantity--);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$_quantity',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            _stepperButton(Icons.add, () {
              if (_quantity < product.stock) {
                setState(() => _quantity++);
              }
            }),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.text(
            'availableLineTotal',
            values: {
              'stock': '${product.stock}',
              'total': (product.price * _quantity).toStringAsFixed(2),
            },
          ),
          style: TextStyle(color: sari.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: product.stock <= 0 || _saving ? null : _onCheckoutAdd,
            icon: Icon(Icons.add_shopping_cart, size: 18, color: sari.onAccent),
            label: Text(
              product.stock <= 0 ? 'Out of stock' : 'Add to Cart',
              style: TextStyle(
                color: sari.onAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: sari.warning,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        TextButton(
          onPressed: widget.onOpenCart,
          child: Text(
            'View cart (${CartStore.instance.itemCount}) · ₱${CartStore.instance.subtotal.toStringAsFixed(2)}',
            style: TextStyle(color: sari.success),
          ),
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: sari.fieldFill.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: scheme.onSurface),
      ),
    );
  }
}