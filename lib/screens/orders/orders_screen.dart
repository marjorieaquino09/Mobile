import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

class _OrdersScreenState extends State<OrdersScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

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

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: sari.screenGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.text('orders'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip(context.l10n.text('filterAll'), null),
                      const SizedBox(width: 8),
                      _filterChip(_statusLabel(OrderStatus.pending),
                          OrderStatus.pending),
                      const SizedBox(width: 8),
                      _filterChip(
                          _statusLabel(OrderStatus.ready), OrderStatus.ready),
                      const SizedBox(width: 8),
                      _filterChip(
                          _statusLabel(OrderStatus.done), OrderStatus.done),
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
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return Center(
                              child: CircularProgressIndicator(
                                  color: sari.success),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                context.l10n.text(
                                  'couldNotLoadOrders',
                                  values: {'error': '${snapshot.error}'},
                                ),
                                style: TextStyle(color: sari.mutedText),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final orders = (snapshot.data?.docs ?? [])
                              .map((doc) => StoreOrder.fromFirestore(
                                    doc.id,
                                    doc.data() as Map<String, dynamic>,
                                  ))
                              .where(
                                  (o) => _filter == null || o.status == _filter)
                              .toList()
                            ..sort((a, b) {
                              final aTime = a.createdAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              final bTime = b.createdAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              return bTime.compareTo(aTime);
                            });

                          if (orders.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: sari.success.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.l10n.text('noOrdersFound'),
                                    style: TextStyle(
                                      color: sari.mutedText,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final o = orders[index];
                              final statusColor = _statusColor(o.status);

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: sari.cardSurface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: sari.cardBorder,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: sari.shadow,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            o.id,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: sari.faintText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                              alpha: 0.25,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _statusLabel(o.status),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      o.customerName,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (o.paymentMethod.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        o.paymentMethod,
                                        style: TextStyle(
                                          color: sari.faintText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            color: sari.mutedText,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          settings.formatMoney(o.total),
                                          style: TextStyle(
                                            color: sari.warning,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
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
      ),
    );
  }

  Widget _filterChip(String label, OrderStatus? status) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
      selectedColor: sari.warning,
      backgroundColor: sari.fieldFill.withValues(alpha: 0.35),
      shape: StadiumBorder(
        side: BorderSide(
          color: sari.success.withValues(alpha: 0.4),
        ),
      ),
      labelStyle: TextStyle(
        color: selected ? sari.onAccentAmber : sari.mutedText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
