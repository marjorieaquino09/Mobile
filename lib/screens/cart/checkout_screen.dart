import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';
import '../../services/cart_store.dart';
import '../../services/sales_service.dart';
import '../../services/settings_store.dart';
import '../credit/credit_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalAmount;
  final int itemCount;

  const CheckoutScreen({
    super.key,
    required this.totalAmount,
    required this.itemCount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final SalesService _salesService = SalesService();
  final _customerController = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _confirmOrder() async {
    final isCredit = _selectedPaymentMethod == 'Credit / Utang';
    final customerName =
        isCredit ? _customerController.text.trim() : _selectedPaymentMethod;

    if (isCredit && _customerController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = context.l10n.text('checkoutCustomerRequired');
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _saving = true;
    });

    try {
      for (final item in CartStore.instance.items) {
        if (item.skipInventory) continue;
        if (item.quantity > item.product.stock) {
          throw StateError(context.l10n.text(
            'checkoutInsufficientStock',
            values: {
              'name': item.product.name,
              'need': '${item.quantity}',
              'have': '${item.product.stock}',
            },
          ));
        }
      }

      final itemsMap = CartStore.instance.items
          .map((item) => {
                'id': item.product.barcode.isNotEmpty
                    ? item.product.barcode
                    : item.product.id,
                'inventoryId': item.product.catalogProductId.isNotEmpty
                    ? item.product.catalogProductId
                    : item.product.id,
                if (item.product.catalogProductId.isNotEmpty)
                  'catalogProductId': item.product.catalogProductId,
                'name': item.product.name,
                'barcode': item.product.barcode.isNotEmpty
                    ? item.product.barcode
                    : item.product.id,
                'price': item.product.price,
                'quantity': item.quantity,
                if (item.skipInventory) 'skipInventory': true,
              })
          .toList();

      final orderId = await _salesService.recordSale(
        items: itemsMap,
        totalAmount: widget.totalAmount,
        paymentMethod: _selectedPaymentMethod,
        customerName: customerName,
      );

      CartStore.instance.clear();

      if (!mounted) return;

      AppSnackbar.showSuccess(context, context.l10n.text('checkoutThankYou'));

      if (isCredit) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final dialogTheme = Theme.of(dialogContext);
            final dialogScheme = dialogTheme.colorScheme;
            final dialogSari = dialogContext.sari;

            return AlertDialog(
              backgroundColor: dialogSari.cardSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: dialogSari.cardBorder),
              ),
              title: Icon(
                Icons.assignment_turned_in_outlined,
                color: dialogSari.accentAmber,
                size: 52,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Utang Recorded!',
                    style: GoogleFonts.outfit(
                      color: dialogScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Na-save ang utang ni $customerName '
                    '(${SettingsStore.instance.formatMoney(widget.totalAmount)}).',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: dialogSari.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                PrimaryButton(
                  label: 'View Credit / Utang',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreditScreen()),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final dialogTheme = Theme.of(dialogContext);
          final dialogScheme = dialogTheme.colorScheme;
          final dialogSari = dialogContext.sari;

          return AlertDialog(
            backgroundColor: dialogSari.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: dialogSari.cardBorder),
            ),
            title: Icon(
              Icons.check_circle_outline_rounded,
              color: dialogScheme.primary,
              size: 52,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Order Confirmed!',
                  style: GoogleFonts.outfit(
                    color: dialogScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order $orderId saved. Stock updated for ${customerName.isEmpty ? 'Walk-in' : customerName} via $_selectedPaymentMethod.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: dialogSari.mutedText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              PrimaryButton(
                label: context.l10n.text('backToStore'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      );
    } catch (e, st) {
      debugPrint('[Checkout] error: $e');
      debugPrint('[Checkout] stack: $st');
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Bad state: ', '');
      AppSnackbar.showError(
        context,
        context.l10n.text('checkoutFailed', values: {'error': msg}),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _paymentOption(String method, IconData icon) {
    final sari = context.sari;
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedPaymentMethod == method;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: sari.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? sari.accentAmber : sari.cardBorder,
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method;
              _errorMessage = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? sari.accentAmber : scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    method,
                    style: GoogleFonts.outfit(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected ? sari.accentAmber : sari.faintText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;
    final isCredit = _selectedPaymentMethod == 'Credit / Utang';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: scheme.onSurface,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    context.l10n.text('checkoutTitle'),
                    style: GoogleFonts.outfit(
                      color: scheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.text('orderSummary').toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: sari.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.text('totalItemsColon'),
                                style: GoogleFonts.outfit(
                                  color: sari.bodyText,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                context.l10n.text(
                                  'pcs',
                                  values: {'count': '${widget.itemCount}'},
                                ),
                                style: GoogleFonts.outfit(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.text('totalPayable'),
                                style: GoogleFonts.outfit(
                                  color: sari.bodyText,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                SettingsStore.instance
                                    .formatMoney(widget.totalAmount),
                                style: GoogleFonts.outfit(
                                  color: sari.accentAmber,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (isCredit) ...[
                      Row(
                        children: [
                          Text(
                            context.l10n.text('customerName'),
                            style: GoogleFonts.outfit(
                              color: scheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            context.l10n.text('customerRequired'),
                            style: GoogleFonts.outfit(
                              color: sari.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _customerController,
                        hintText: context.l10n.text('borrowerNameHint'),
                        prefixIcon: Icons.person_outline_rounded,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.outfit(
                              color: sari.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                    Text(
                      context.l10n.text('paymentMethod'),
                      style: GoogleFonts.outfit(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _paymentOption('Cash', Icons.payments_outlined),
                    _paymentOption('Credit / Utang', Icons.assignment_outlined),
                  ],
                ),
              ),
              PrimaryButton(
                label: isCredit ? 'Save Utang & View List' : 'Complete Order',
                isLoading: _saving,
                onPressed: _confirmOrder,
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}