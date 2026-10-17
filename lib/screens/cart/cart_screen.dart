import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';
import '../../services/cart_store.dart';
import '../../services/settings_store.dart';
import '../../widgets/product_image.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final bool embedded;

  const CartScreen({super.key, this.embedded = false});

  void _goToCheckout(BuildContext context) {
    final cart = CartStore.instance;
    if (cart.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          totalAmount: cart.subtotal,
          itemCount: cart.itemCount,
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, CartStore cart) async {
    final shouldClear = await ConfirmDialog.show(
      context,
      title: context.l10n.text('clearCartTitle'),
      message: context.l10n.text('clearCartMessage'),
      confirmLabel: context.l10n.text('clear'),
      cancelLabel: context.l10n.text('cancel'),
      isDestructive: true,
    );
    if (shouldClear == true) cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            CartStore.instance,
            SettingsStore.instance,
          ]),
          builder: (context, _) {
            final cart = CartStore.instance;
            final items = cart.items;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!embedded)
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: scheme.onSurface,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      else
                        const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.text('cartTitle'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () => _confirmClear(context, cart),
                          child: Text(
                            context.l10n.text('clear'),
                            style: GoogleFonts.outfit(
                              color: sari.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: items.isEmpty
                        ? EmptyState(
                            icon: Icons.shopping_cart_outlined,
                            title: context.l10n.text('cartEmpty'),
                            message: context.l10n.text('cartEmptyHint'),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Dismissible(
                                key: ValueKey(item.product.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) =>
                                    cart.remove(item.product.id),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: sari.danger.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: sari.cardSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sari.cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Product image with pure white rounded backdrop
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: Container(
                                          width: 58,
                                          height: 58,
                                          color: Colors.white,
                                          padding: const EdgeInsets.all(4),
                                          child: ProductImage(
                                            imageUrl: item.product.imageUrl,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.product.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                color: scheme.onSurface,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              context.l10n.text(
                                                'priceEach',
                                                values: {
                                                  'price': SettingsStore
                                                      .instance
                                                      .formatMoney(
                                                          item.product.price),
                                                },
                                              ),
                                              style: GoogleFonts.outfit(
                                                color: sari.accentAmber,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.remove_circle_outline_rounded,
                                              color: sari.mutedText,
                                              size: 22,
                                            ),
                                            onPressed: () => cart
                                                .decrement(item.product.id),
                                          ),
                                          Text(
                                            '${item.quantity}',
                                            style: GoogleFonts.outfit(
                                              color: scheme.onSurface,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.add_circle_outline_rounded,
                                              color: scheme.primary,
                                              size: 22,
                                            ),
                                            onPressed: () => cart
                                                .increment(item.product.id),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (items.isNotEmpty) ...[
                    Divider(color: sari.cardBorder, thickness: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.text(
                            cart.itemCount == 1
                                ? 'itemCount'
                                : 'itemCountPlural',
                            values: {'count': '${cart.itemCount}'},
                          ),
                          style: GoogleFonts.outfit(
                            color: sari.mutedText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          SettingsStore.instance.formatMoney(cart.subtotal),
                          style: GoogleFonts.outfit(
                            color: scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _goToCheckout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sari.accentAmber,
                          foregroundColor: sari.onAccentAmber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          context.l10n.text('checkout'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
