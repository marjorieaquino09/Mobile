import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';

enum NotificationType {
  lowStock,
  payment,
  creditOverdue,
  orderReady,
  inventory,
  transaction,
}

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String timeAgo;
  final NotificationType type;
  final bool unread;
  final DateTime? createdAt;

  const NotificationItem({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.type,
    this.id = '',
    this.unread = true,
    this.createdAt,
  });

  bool get isRead => !unread;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timeAgo,
    NotificationType? type,
    bool? unread,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timeAgo: timeAgo ?? this.timeAgo,
      type: type ?? this.type,
      unread: unread ?? this.unread,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'timeAgo': timeAgo,
        'type': type.name,
        'unread': unread,
        'isRead': isRead,
        'createdAt': createdAt?.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'subtitle': subtitle,
        'type': type.name,
        'isRead': isRead,
        'timeAgo': timeAgo,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final typeName = (map['type'] as String?) ?? 'payment';
    final type = NotificationType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => NotificationType.payment,
    );
    DateTime? created;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String && rawCreated.isNotEmpty) {
      created = DateTime.tryParse(rawCreated);
    }
    final isRead = map['isRead'] == true || map['unread'] == false;
    return NotificationItem(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      timeAgo: (map['timeAgo'] ?? '').toString(),
      type: type,
      unread: !isRead,
      createdAt: created,
    );
  }

  factory NotificationItem.fromFirestore(
    String docId,
    Map<String, dynamic> map,
  ) {
    return NotificationItem.fromMap({...map, 'id': docId});
  }

  String displayTime(AppLocalizations l10n) {
    if (createdAt == null) {
      return timeAgo == 'Just now' ? l10n.text('justNow') : timeAgo;
    }
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return l10n.text('justNow');
    if (diff.inMinutes < 60) {
      return l10n.text('minutesAgo', values: {'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return l10n.text('hoursAgo', values: {'count': '${diff.inHours}'});
    }
    return l10n.text('daysAgo', values: {'count': '${diff.inDays}'});
  }
}
