import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/notification_item.dart';
import 'push_notification_service.dart';
import 'settings_store.dart';

/// In-app notifications stored at `users/{uid}/notifications/{id}`.
class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  static const _legacyPrefsKey = 'app_notifications_v1';

  final List<NotificationItem> _items = [];
  bool _loaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

  List<NotificationItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  int get unreadCount => _items.where((n) => n.unread).length;

  AppLocalizations get _l10n => AppLocalizations(
        Locale(SettingsStore.instance.languageCode),
      );

  CollectionReference<Map<String, dynamic>>? _notificationsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  Future<void> load() async {
    await reloadForCurrentUser();
  }

  Future<void> reloadForCurrentUser() async {
    await _firestoreSub?.cancel();
    _firestoreSub = null;
    _items.clear();
    _loaded = false;
    notifyListeners();

    final ref = _notificationsRef();
    if (ref == null) {
      await _loadLegacyPrefsOnly();
      _loaded = true;
      notifyListeners();
      return;
    }

    _firestoreSub = ref
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        _items
          ..clear()
          ..addAll(
            snap.docs.map(
              (d) => NotificationItem.fromFirestore(d.id, d.data()),
            ),
          );
        _loaded = true;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('[NotificationStore] Firestore listen failed: $err');
        _loaded = true;
        notifyListeners();
      },
    );
  }

  Future<void> _loadLegacyPrefsOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final entry in list) {
        if (entry is Map<String, dynamic>) {
          _items.add(NotificationItem.fromMap(entry));
        } else if (entry is Map) {
          _items.add(NotificationItem.fromMap(
            Map<String, dynamic>.from(entry),
          ));
        }
      }
    } catch (e) {
      debugPrint('[NotificationStore] legacy parse failed: $e');
    }
  }

  bool _allowedBySettings(NotificationType type) {
    final settings = SettingsStore.instance;
    switch (type) {
      case NotificationType.lowStock:
        return settings.lowStockEnabled;
      case NotificationType.payment:
      case NotificationType.creditOverdue:
      case NotificationType.orderReady:
      case NotificationType.inventory:
      case NotificationType.transaction:
        return true;
    }
  }

  /// Single entry point for creating notifications (Firestore + optional banner).
  Future<void> createNotification({
    required String title,
    required String subtitle,
    required NotificationType type,
    String? timeAgo,
    bool showSystemBanner = true,
  }) async {
    if (!_allowedBySettings(type)) return;

    final ref = _notificationsRef();
    if (ref == null) return;

    final doc = ref.doc();
    final item = NotificationItem(
      id: doc.id,
      title: title,
      subtitle: subtitle,
      timeAgo: timeAgo ?? _l10n.text('justNow'),
      type: type,
      unread: true,
      createdAt: DateTime.now(),
    );

    await doc.set(item.toFirestore());

    if (showSystemBanner && SettingsStore.instance.pushEnabled) {
      await PushNotificationService.instance.showLocal(
        title: title,
        body: subtitle,
        payload: type.name,
      );
    }
  }

  Future<void> add({
    required String title,
    required String subtitle,
    required NotificationType type,
    String? timeAgo,
    bool showSystemBanner = true,
  }) =>
      createNotification(
        title: title,
        subtitle: subtitle,
        type: type,
        timeAgo: timeAgo,
        showSystemBanner: showSystemBanner,
      );

  Future<void> addCheckoutThankYou({
    required String orderId,
    required double total,
    required String paymentMethod,
    String customerName = '',
  }) async {
    final who = customerName.trim().isEmpty
        ? _l10n.text('customer')
        : customerName.trim();
    final shortId =
        orderId.length > 8 ? '${orderId.substring(0, 8)}…' : orderId;
    final money = SettingsStore.instance.formatMoney(total);
    await createNotification(
      title: _l10n.text('notificationThankYou'),
      subtitle: _l10n.text(
        'notificationCheckoutMessage',
        values: {
          'id': shortId,
          'customer': who,
          'method': paymentMethod,
          'amount': money,
        },
      ),
      type: NotificationType.payment,
    );
  }

  Future<void> addTransactionRecorded({
    required String paymentMethod,
    required double total,
    String customerName = '',
  }) async {
    final who =
        customerName.trim().isEmpty ? paymentMethod : customerName.trim();
    final money = SettingsStore.instance.formatMoney(total);
    await createNotification(
      title: _l10n.text('notificationTransactionRecorded'),
      subtitle: _l10n.text(
        'notificationTransactionMessage',
        values: {'customer': who, 'method': paymentMethod, 'amount': money},
      ),
      type: NotificationType.transaction,
    );
  }

  Future<void> addInventoryEvent({
    required String action,
    required String productName,
    int? stock,
  }) async {
    final stockPart = stock != null
        ? _l10n.text('notificationStockNow', values: {'stock': '$stock'})
        : '';
    final actionLabel = switch (action) {
      'added' => _l10n.text('actionAdded'),
      'edited' => _l10n.text('actionEdited'),
      'deleted' => _l10n.text('actionDeleted'),
      'added/updated' => _l10n.text('actionAddedUpdated'),
      'registered' => _l10n.text('actionRegistered'),
      _ => action,
    };
    await createNotification(
      title: _l10n.text('notificationInventoryUpdated'),
      subtitle: _l10n.text(
        'notificationInventoryMessage',
        values: {
          'name': productName,
          'action': actionLabel,
          'stock': stockPart
        },
      ),
      type: NotificationType.inventory,
    );
  }

  Future<void> addLowStockAlert({
    required String productName,
    required int stock,
  }) async {
    if (!SettingsStore.instance.lowStockEnabled) return;
    final already = _items.any(
      (n) =>
          n.type == NotificationType.lowStock &&
          n.unread &&
          n.subtitle.contains(productName),
    );
    if (already) return;

    await createNotification(
      title: _l10n.text(
        stock <= 0 ? 'notificationOutOfStock' : 'notificationLowStock',
      ),
      subtitle: stock <= 0
          ? _l10n
              .text('notificationItemOutOfStock', values: {'name': productName})
          : _l10n.text(
              'notificationItemLowStock',
              values: {'name': productName, 'stock': '$stock'},
            ),
      type: NotificationType.lowStock,
    );
  }

  Future<void> addCreditOverdueAlert({
    required String creditId,
    required String customerName,
    required double amount,
    required int daysOverdue,
  }) async {
    final already = _items.any(
      (n) =>
          n.type == NotificationType.creditOverdue &&
          n.subtitle.contains(creditId),
    );
    if (already) return;

    final money = SettingsStore.instance.formatMoney(amount);
    await createNotification(
      title: _l10n.text('notificationCreditOverdue'),
      subtitle: _l10n.text(
        'notificationCreditMessage',
        values: {
          'name': customerName,
          'amount': money,
          'days': '$daysOverdue',
          'id': creditId,
        },
      ),
      type: NotificationType.creditOverdue,
    );
  }

  Future<void> markAsRead(String id) async {
    final ref = _notificationsRef();
    if (ref == null) return;
    try {
      await ref.doc(id).update({'isRead': true});
    } catch (e) {
      debugPrint('[NotificationStore] markAsRead failed: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final ref = _notificationsRef();
    if (ref == null) return;
    final unread = _items.where((n) => n.unread).toList();
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(ref.doc(n.id), {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> clearAll() async {
    final ref = _notificationsRef();
    if (ref == null) return;
    final snap = await ref.limit(100).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}
