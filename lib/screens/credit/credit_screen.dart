import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
    final subtotal = (raw['subtotal'] as num?)?.toDouble() ?? (price * qty);
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
  final String phone;
  final double amount;
  final String date;
  final bool isPaid;
  final DateTime? createdAt;
  final List<CreditLineItem> items;
  final String description;

  CreditItemModel({
    required this.id,
    required this.customerName,
    this.phone = '',
    required this.amount,
    required this.date,
    this.isPaid = false,
    this.createdAt,
    this.items = const [],
    this.description = '',
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
      phone: (data['phone'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: (data['date'] ?? '').toString(),
      isPaid: data['isPaid'] == true,
      createdAt: created is Timestamp ? created.toDate() : null,
      items: items,
      description: (data['description'] ?? '').toString(),
    );
  }
}

enum _CreditFilter { all, unpaid, paid }

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
  _CreditFilter _filter = _CreditFilter.all;
  bool _overdueChecked = false;

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

  void _showAddCreditModal() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sari.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (dialogCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sari.mutedText.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Credit Record',
                      style: GoogleFonts.outfit(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: sari.mutedText, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Customer Name *',
                  style: GoogleFonts.outfit(
                    color: sari.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.outfit(color: scheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Maria Santos',
                    hintStyle: GoogleFonts.outfit(color: sari.faintText, fontSize: 13),
                    filled: true,
                    fillColor: sari.fieldFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: sari.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Phone Number (Optional)',
                  style: GoogleFonts.outfit(
                    color: sari.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.outfit(color: scheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. 09123456789',
                    hintStyle: GoogleFonts.outfit(color: sari.faintText, fontSize: 13),
                    filled: true,
                    fillColor: sari.fieldFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: sari.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Credit Amount (₱) *',
                  style: GoogleFonts.outfit(
                    color: sari.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(color: scheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.outfit(color: sari.faintText, fontSize: 13),
                    filled: true,
                    fillColor: sari.fieldFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: sari.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Items / Description (Optional)',
                  style: GoogleFonts.outfit(
                    color: sari.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: GoogleFonts.outfit(color: scheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. 2 Cans Tuna, 1 Rice',
                    hintStyle: GoogleFonts.outfit(color: sari.faintText, fontSize: 13),
                    filled: true,
                    fillColor: sari.fieldFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: sari.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final customerName = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                      final description = descController.text.trim();

                      if (customerName.isEmpty || amount <= 0) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(
                            content: const Text('Please enter valid customer name and credit amount'),
                            backgroundColor: sari.danger,
                          ),
                        );
                        return;
                      }

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      try {
                        final dateStr = DateFormat('MMM d, yyyy').format(DateTime.now());
                        await _db.collection('credits').add({
                          'userId': user.uid,
                          'customerName': customerName,
                          'phone': phone,
                          'amount': amount,
                          'description': description,
                          'date': dateStr,
                          'isPaid': false,
                          'createdAt': FieldValue.serverTimestamp(),
                          'items': description.isNotEmpty
                              ? [
                                  {
                                    'name': description,
                                    'quantity': 1,
                                    'price': amount,
                                    'subtotal': amount,
                                  }
                                ]
                              : [],
                        });

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Credit record saved successfully'),
                              backgroundColor: sari.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: sari.danger,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Save Credit Record',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markPaid(CreditItemModel credit) async {
    if (credit.isPaid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sari.cardSurface,
        title: Text(
          context.l10n.text('markAsPaidTitle'),
          style: GoogleFonts.outfit(color: scheme.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.l10n.text(
            'recordPaymentPrompt',
            values: {
              'amount': SettingsStore.instance.formatMoney(credit.amount),
              'customer': credit.customerName,
            },
          ),
          style: GoogleFonts.outfit(color: sari.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.text('cancel'),
                style: GoogleFonts.outfit(color: sari.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            child: Text(context.l10n.text('markPaid'), style: GoogleFonts.outfit()),
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

  int? _overdueDaysFor(CreditItemModel credit) {
    if (credit.isPaid) return null;
    final created = credit.createdAt;
    if (created == null) return null;
    final days = DateTime.now().difference(created).inDays;
    return days >= _overdueDays ? days : null;
  }

  Widget _creditCard(
    CreditItemModel credit,
    ColorScheme scheme,
    SariColors sari,
  ) {
    final settings = SettingsStore.instance;
    final accent = credit.isPaid ? sari.success : sari.accentAmber;
    final overdue = _overdueDaysFor(credit);
    final initial = credit.customerName.trim().isEmpty
        ? '?'
        : credit.customerName.trim()[0].toUpperCase();
    final dateText = credit.date.isEmpty ? credit.id : credit.date;

    return Opacity(
      opacity: credit.isPaid ? 0.8 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: sari.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: credit.isPaid
                ? sari.cardBorder
                : sari.accentAmber.withValues(alpha: 0.35),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              expandedAlignment: Alignment.centerLeft,
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: GoogleFonts.outfit(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                credit.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: scheme.onSurface,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dateText,
                      style: GoogleFonts.outfit(
                        color: sari.mutedText,
                        fontSize: 11.5,
                      ),
                    ),
                    if (credit.phone.isNotEmpty)
                      Text(
                        '· ${credit.phone}',
                        style: GoogleFonts.outfit(
                          color: sari.faintText,
                          fontSize: 11.5,
                        ),
                      ),
                    if (overdue != null)
                      Text(
                        'Overdue ${overdue}d',
                        style: GoogleFonts.outfit(
                          color: sari.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    settings.formatMoney(credit.amount),
                    style: GoogleFonts.outfit(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _statusPill(credit),
                ],
              ),
              children: [
                Divider(color: sari.cardBorder, height: 1, thickness: 0.8),
                const SizedBox(height: 10),
                Text(
                  context.l10n.text('creditItemsTitle'),
                  style: GoogleFonts.outfit(
                    color: sari.mutedText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                if (credit.items.isEmpty && credit.description.isEmpty)
                  Text(
                    context.l10n.text('noItemDetailsRecorded'),
                    style: GoogleFonts.outfit(
                      color: sari.faintText,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (credit.description.isNotEmpty && credit.items.isEmpty)
                  Text(
                    credit.description,
                    style: GoogleFonts.outfit(
                      color: scheme.onSurface,
                      fontSize: 13,
                    ),
                  )
                else
                  for (var i = 0; i < credit.items.length; i++)
                    _creditLineRow(
                      credit.items[i],
                      sari,
                      scheme,
                      isLast: i == credit.items.length - 1,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(CreditItemModel credit) {
    if (credit.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: sari.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'PAID',
          style: GoogleFonts.outfit(
            color: sari.success,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _markPaid(credit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: sari.accentAmber,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'MARK PAID',
          style: GoogleFonts.outfit(
            color: sari.onAccentAmber,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _creditLineRow(
    CreditLineItem line,
    SariColors sari,
    ColorScheme scheme, {
    bool isLast = false,
  }) {
    final settings = SettingsStore.instance;
    final name = line.name.trim().isEmpty ? '—' : line.name;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${line.quantity} × ${settings.formatMoney(line.price)}',
                  style: GoogleFonts.outfit(
                    color: sari.faintText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            settings.formatMoney(line.subtotal),
            style: GoogleFonts.outfit(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _CreditFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: sari.accentAmber,
      backgroundColor: sari.fieldFill,
      visualDensity: VisualDensity.compact,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? sari.accentAmber : sari.cardBorder,
        ),
      ),
      labelStyle: GoogleFonts.outfit(
        color: selected ? sari.onAccentAmber : sari.mutedText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _summaryCard(double totalUnpaid, int unpaidCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: sari.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sari.accentAmber.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: sari.accentAmber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              color: sari.accentAmber,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('totalUnpaid'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: sari.faintText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$unpaidCount unpaid · ${context.l10n.text('uncollectedCredits')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: sari.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            SettingsStore.instance.formatMoney(totalUnpaid),
            style: GoogleFonts.outfit(
              color: sari.accentAmber,
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCreditModal,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Credit',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: user == null
              ? Center(
                  child: Text(
                    context.l10n.text('creditViewLogin'),
                    style: GoogleFonts.outfit(color: sari.mutedText),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                          style: GoogleFonts.outfit(color: sari.mutedText),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: scheme.primary),
                      );
                    }

                    final credits = (snapshot.data?.docs ?? [])
                        .map(CreditItemModel.fromFirestore)
                        .toList()
                      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
                          .compareTo(a.createdAt ?? DateTime(1970)));

                    final filtered = credits.where((c) {
                      final matchesSearch = _searchQuery.isEmpty ||
                          c.customerName
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ||
                          c.phone.contains(_searchQuery);
                      final matchesStatus = _filter == _CreditFilter.all ||
                          (_filter == _CreditFilter.unpaid && !c.isPaid) ||
                          (_filter == _CreditFilter.paid && c.isPaid);
                      return matchesSearch && matchesStatus;
                    }).toList();

                    final unpaidCredits =
                        credits.where((c) => !c.isPaid).toList();
                    final totalUnpaid = unpaidCredits.fold(
                        0.0, (total, item) => total + item.amount);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _checkOverdue(credits);
                    });

                    return ListenableBuilder(
                      listenable: SettingsStore.instance,
                      builder: (context, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back_rounded,
                                      color: scheme.onSurface),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                Expanded(
                                  child: Text(
                                    context.l10n.text('creditListTitle'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
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
                            _summaryCard(totalUnpaid, unpaidCredits.length),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val.trim()),
                              style: GoogleFonts.outfit(
                                  color: scheme.onSurface, fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText:
                                    context.l10n.text('creditSearchHint'),
                                hintStyle: GoogleFonts.outfit(
                                    color: sari.faintText, fontSize: 12.5),
                                prefixIcon: Icon(Icons.search,
                                    color: sari.faintText, size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: sari.mutedText, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: sari.fieldFill,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
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
                                    color: scheme.primary,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _filterChip(
                                    context.l10n.text('filterAll'),
                                    _CreditFilter.all,
                                  ),
                                  const SizedBox(width: 8),
                                  _filterChip('Unpaid', _CreditFilter.unpaid),
                                  const SizedBox(width: 8),
                                  _filterChip('Paid', _CreditFilter.paid),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                            style: GoogleFonts.outfit(
                                              color: sari.mutedText,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      physics: const BouncingScrollPhysics(),
                                      padding:
                                          const EdgeInsets.only(bottom: 80),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
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
    );
  }
}