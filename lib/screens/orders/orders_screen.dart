import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrderLine {
  final String name;
  final int quantity;
  final double? lineTotal;

  const _OrderLine({
    required this.name,
    required this.quantity,
    this.lineTotal,
  });
}

class _OrderRow {
  final StoreOrder order;
  final List<_OrderLine> lines;

  const _OrderRow({required this.order, required this.lines});
}

class _OrdersScreenState extends State<OrdersScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  static const int _maxVisibleLines = 5;

  final FirebaseService _firebase = FirebaseService();
  OrderStatus? _filter;

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return sari.warning;
      case OrderStatus.ready:
        return sari.info;
      case OrderStatus.done:
        return sari.success;
    }
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return context.l10n.text('statusPending');
      case OrderStatus.ready:
        return context.l10n.text('statusReady');
      case OrderStatus.done:
        return context.l10n.text('statusDone');
    }
  }

  List<_OrderLine> _parseLines(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List) return const [];

    final lines = <_OrderLine>[];
    for (final r in raw) {
      if (r is! Map) continue;
      final item = Map<String, dynamic>.from(r);

      final name = (item['name'] ??
              item['productName'] ??
              item['title'] ??
              item['barcode'] ??
              item['id'] ??
              'Item')
          .toString()
          .trim();

      final quantity = (item['quantity'] as num?)?.toInt() ??
          (item['qty'] as num?)?.toInt() ??
          1;

      final price = (item['price'] as num?)?.toDouble() ??
          (item['unitPrice'] as num?)?.toDouble();

      lines.add(_OrderLine(
        name: name.isEmpty ? 'Item' : name,
        quantity: quantity,
        lineTotal: price == null ? null : price * quantity,
      ));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.text('orders'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: scheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _filterChip(context.l10n.text('filterAll'), null),
                    const SizedBox(width: 8),
                    _filterChip(_statusLabel(OrderStatus.pending), OrderStatus.pending),
                    const SizedBox(width: 8),
                    _filterChip(_statusLabel(OrderStatus.ready), OrderStatus.ready),
                    const SizedBox(width: 8),
                    _filterChip(_statusLabel(OrderStatus.done), OrderStatus.done),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    return StreamBuilder<QuerySnapshot>(
                      stream: uid == null
                          ? const Stream.empty()
                          : _firebase.getOrdersStream(userId: uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(color: scheme.primary),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              context.l10n.text(
                                'couldNotLoadOrders',
                                values: {'error': '${snapshot.error}'},
                              ),
                              style: GoogleFonts.outfit(color: sari.mutedText),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final rows = (snapshot.data?.docs ?? []).map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _OrderRow(
                            order: StoreOrder.fromFirestore(doc.id, data),
                            lines: _parseLines(data),
                          );
                        }).where((r) {
                          return _filter == null || r.order.status == _filter;
                        }).toList()
                          ..sort((a, b) {
                            final aTime = a.order.createdAt ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            final bTime = b.order.createdAt ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            return bTime.compareTo(aTime);
                          });

                        if (rows.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 52,
                                  color: sari.mutedText.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.l10n.text('noOrdersFound'),
                                  style: GoogleFonts.outfit(
                                    color: sari.mutedText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _orderCard(rows[index], settings),
                        );
                      },
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

  Widget _orderCard(_OrderRow row, SettingsStore settings) {
    final o = row.order;
    final statusColor = _statusColor(o.status);
    final visibleLines = row.lines.take(_maxVisibleLines).toList();
    final hiddenCount = row.lines.length - visibleLines.length;

    final meta = <String>[
      if (o.paymentMethod.isNotEmpty) o.paymentMethod,
      if (o.createdAt != null) DateFormat('MMM d, h:mm a').format(o.createdAt!),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sari.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sari.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: sari.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(o.status),
                  style: GoogleFonts.outfit(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: sari.faintText,
                fontSize: 12,
              ),
            ),
          ],
          if (visibleLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: sari.cardBorder, height: 1, thickness: 0.8),
            const SizedBox(height: 10),
            for (var i = 0; i < visibleLines.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _lineRow(visibleLines[i], settings),
            ],
            if (hiddenCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '+$hiddenCount more item${hiddenCount == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                  color: sari.faintText,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Divider(color: sari.cardBorder, height: 1, thickness: 0.8),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                  color: sari.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                settings.formatMoney(o.total),
                style: GoogleFonts.outfit(
                  color: sari.accentAmber,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineRow(_OrderLine line, SettingsStore settings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '${line.quantity}×',
            style: GoogleFonts.outfit(
              color: sari.accentAmber,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            line.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: scheme.onSurface,
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ),
        if (line.lineTotal != null) ...[
          const SizedBox(width: 8),
          Text(
            settings.formatMoney(line.lineTotal!),
            style: GoogleFonts.outfit(
              color: sari.mutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _filterChip(String label, OrderStatus? status) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
      selectedColor: sari.accentAmber,
      backgroundColor: sari.fieldFill,
      visualDensity: VisualDensity.compact,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? sari.accentAmber : sari.cardBorder,
          width: 1,
        ),
      ),
      labelStyle: GoogleFonts.outfit(
        color: selected ? sari.onAccentAmber : scheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
    );
  }
}