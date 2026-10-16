import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Lightweight camera scanner that returns a single barcode string.
/// Used by the add-product form — not the full Scan / checkout flow.
class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key});

  /// Opens the scanner and returns the scanned code, or null if cancelled.
  static Future<String?> scan(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BarcodeScanPage(),
      ),
    );
  }

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _permissionDenied = false;
  bool _permanentlyDenied = false;
  bool _starting = true;
  bool _handled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _ensureCamera();
      return;
    }
    final controller = _controller;
    if (controller == null || _permissionDenied) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureCamera() async {
    // permission_handler camera macros may be unset on iOS; Android needs an
    // explicit runtime request. Elsewhere, mobile_scanner prompts itself.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!mounted) return;
      if (!status.isGranted) {
        setState(() {
          _starting = false;
          _permissionDenied = true;
          _permanentlyDenied =
              status.isPermanentlyDenied || status.isRestricted;
          _errorMessage = context.l10n.text('cameraPermissionNeeded');
        });
        return;
      }
    }

    await _startScanner();
  }

  Future<void> _startScanner() async {
    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        autoStart: true,
      );
      setState(() {
        _controller = controller;
        _starting = false;
        _permissionDenied = false;
        _permanentlyDenied = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _permissionDenied = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;

    _handled = true;
    HapticFeedback.mediumImpact();
    _controller?.stop();
    if (mounted) Navigator.of(context).pop(code);
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.text('barcode')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_starting) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_permissionDenied || _controller == null) {
      return _PermissionDeniedView(
        message: _errorMessage ?? context.l10n.text('cameraPermissionNeeded'),
        showSettings: _permanentlyDenied || _permissionDenied,
        onRetry: () {
          setState(() {
            _starting = true;
            _permissionDenied = false;
            _errorMessage = null;
          });
          _ensureCamera();
        },
        onOpenSettings: _openSettings,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            return _PermissionDeniedView(
              message: error.errorDetails?.message ?? error.errorCode.name,
              showSettings: true,
              onRetry: () => _controller?.start(),
              onOpenSettings: _openSettings,
            );
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: MediaQuery.sizeOf(context).width * 0.72,
              height: MediaQuery.sizeOf(context).width * 0.45,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final String message;
  final bool showSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _PermissionDeniedView({
    required this.message,
    required this.showSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: AppColors.darkGreenTop,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            color: scheme.onSurfaceVariant,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.text('cameraPermissionNeeded'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
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
              onPressed: onOpenSettings,
              child: Text(
                context.l10n.text('openAppSettings'),
                style: TextStyle(
                  color: scheme.primary,
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
