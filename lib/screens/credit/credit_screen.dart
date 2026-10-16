import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notification_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';

class CreditLineItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final double subtotal;

  const CreditLineItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory CreditLineItem.fromMap(Map<String, dynamic> raw) {
    final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
    final price = (raw['price'] as num?)?.toDouble() ?? 0.0;
    final subtotal =
        (raw['subtotal'] as num?)?.toDouble() ?? (price * qty);
    return CreditLineItem(
      id: (raw['id'] ?? raw['productId'] ?? raw['barcode'] ?? '').toString(),
      name: (raw['name'] ?? '').toString(),
      quantity: qty,
      price: price,
      subtotal: subtotal,
    );
  }
}

class CreditItemModel {
  final String id;
  final String customerName;
  final double amount;
  final String date;
  final bool isPaid;
  final DateTime? createdAt;
  final List<CreditLineItem> items;

  CreditItemModel({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.date,
    this.isPaid = false,
    this.createdAt,
    this.items = const [],
  });

  factory CreditItemModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final created = data['createdAt'];
    final rawItems = data['items'];
    final items = <CreditLineItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          items.add(
            CreditLineItem.fromMap(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return CreditItemModel(
      id: doc.id,
      customerName: (data['customerName'] ?? 'Customer').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: (data['date'] ?? '').toString(),
      isPaid: data['isPaid'] == true,
      createdAt: created is Timestamp ? created.toDate() : null,
      items: items,
    );
  }
}

class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _overdueChecked = false;

  /// Unpaid credits older than this many days trigger an overdue alert.
  static const int _overdueDays = 7;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkOverdue(List<CreditItemModel> credits) async {
    if (_overdueChecked) return;
    _overdueChecked = true;
    final now = DateTime.now();
    for (final c in credits) {
      if (c.isPaid) continue;
      final created = c.createdAt;
      if (created == null) continue;
      final days = now.difference(created).inDays;
      if (days < _overdueDays) continue;
      await NotificationStore.instance.addCreditOverdueAlert(
        creditId: c.id,
        customerName: c.customerName,
        amount: c.amount,
        daysOverdue: days,
      );
    }
  }

  // Mark Paid — guarded so already-paid rows cannot double-count transactions.
  Future<void> _markPaid(CreditItemModel credit) async {
    if (credit.isPaid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sari.cardSurfaceStrong,
        title: Text(
          context.l10n.text('markAsPaidTitle'),
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          context.l10n.text(
            'recordPaymentPrompt',
            values: {
              'amount': SettingsStore.instance.formatMoney(credit.amount),
              'customer': credit.customerName,
            },
          ),
          style: TextStyle(color: sari.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.text('cancel'),
                style: TextStyle(color: sari.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.text('markPaid')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _db.collection('credits').doc(credit.id).update({
        'isPaid': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Optional analytics row — not covered by firestore.rules; never fail
      // the mark-paid flow if this write is denied.
      try {
        await _db.collection('transactions').add({
          'userId': user.uid,
          'payment_method': 'Cash',
          'customer_name': credit.customerName,
          'total_amount': credit.amount,
          'created_at': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('creditPaidSuccess'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.text(
                'failed',
                values: {'error': '$e'},
              )),
              backgroundColor: sari.danger),
        );
      }
    }
  }

  Widget _creditCard(
    CreditItemModel credit,
    ColorScheme scheme,
    SariColors sari,
  ) {
    final settings = SettingsStore.instance;
    return Container(
      decoration: BoxDecoration(
        color: sari.fieldFill.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sari.success.withValues(alpha: 0.2),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sari.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_outline,
              color: sari.success,
              size: 20,
            ),
          ),
          title: Text(
            credit.customerName,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              credit.date.isEmpty ? credit.id : credit.date,
              style: TextStyle(
                color: sari.mutedText,
                fontSize: 12,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                settings.formatMoney(credit.amount),
                style: TextStyle(
                  color: credit.isPaid ? sari.success : sari.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: credit.isPaid ? null : () => _markPaid(credit),
                child: Text(
                  credit.isPaid ? 'PAID' : 'MARK PAID',
                  style: TextStyle(
                    color: credit.isPaid ? sari.success : sari.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.text('creditItemsTitle'),
                style: TextStyle(
                  color: sari.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (credit.items.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.text('noItemDetailsRecorded'),
                  style: TextStyle(
                    color: sari.faintText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...credit.items.map((line) => _creditLineRow(line, sari, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _creditLineRow(
    CreditLineItem line,
    SariColors sari,
    ColorScheme scheme,
  ) {
    final settings = SettingsStore.instance;
    final name = line.name.trim().isEmpty ? '—' : line.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.quantity} × ${settings.formatMoney(line.price)}',
                  style: TextStyle(
                    color: sari.faintText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            settings.formatMoney(line.subtotal),
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: sari.screenGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: user == null
                ? Center(
                    child: Text(
                      context.l10n.text('creditViewLogin'),
                      style: TextStyle(color: sari.mutedText),
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Nakatutok na ngayon sa 'credits' collection para magtugma sa web at database
                    stream: _db
                        .collection('credits')
                        .where('userId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            context.l10n.text(
                              'creditLoadFailed',
                              values: {'error': '${snapshot.error}'},
                            ),
                            style: TextStyle(color: sari.mutedText),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: sari.success),
                        );
                      }

                      final credits = (snapshot.data?.docs ?? [])
                          .map(CreditItemModel.fromFirestore)
                          .toList()
                        ..sort((a, b) => (b.createdAt ?? DateTime(1970))
                            .compareTo(a.createdAt ?? DateTime(1970)));

                      // Filter gamit ang search query
                      final filtered = credits.where((c) {
                        return _searchQuery.isEmpty ||
                            c.customerName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase());
                      }).toList();

                      final totalUnpaid = credits
                          .where((c) => !c.isPaid)
                          .fold(0.0, (total, item) => total + item.amount);

                      // Fire once per screen visit for long-unpaid credits.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _checkOverdue(credits);
                      });

                      return ListenableBuilder(
                        listenable: SettingsStore.instance,
                        builder: (context, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.arrow_back,
                                        color: scheme.onSurface),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                  Expanded(
                                    child: Text(
                                      context.l10n.text('creditListTitle'),
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
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val.trim()),
                                style: TextStyle(
                                    color: scheme.onSurface, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText:
                                      context.l10n.text('creditSearchHint'),
                                  hintStyle: TextStyle(
                                      color: sari.faintText, fontSize: 12),
                                  prefixIcon: Icon(Icons.search,
                                      color: sari.faintText, size: 18),
                                  filled: true,
                                  fillColor: sari.fieldFill,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: sari.cardBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: sari.cardBorder,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: sari.warning,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: sari.cardSurface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: sari.warning.withValues(alpha: 0.45),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: sari.shadow,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n.text('totalUnpaid'),
                                          style: TextStyle(
                                            color: sari.faintText,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.l10n
                                              .text('uncollectedCredits'),
                                          style: TextStyle(
                                            color: sari.mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      SettingsStore.instance
                                          .formatMoney(totalUnpaid),
                                      style: TextStyle(
                                        color: sari.warning,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .assignment_turned_in_outlined,
                                              size: 48,
                                              color: sari.success
                                                  .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _searchQuery.isEmpty
                                                  ? context.l10n
                                                      .text('noCreditsRecorded')
                                                  : context.l10n.text(
                                                      'noMatchingCustomers'),
                                              style: TextStyle(
                                                color: sari.mutedText,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          return _creditCard(
                                            filtered[index],
                                            scheme,
                                            sari,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
