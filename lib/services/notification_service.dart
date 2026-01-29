import 'dart:convert';
import 'dart:math';
import 'package:safechain/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType { device, announcement, security }

class Notification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      type: NotificationType.values.firstWhere((e) => e.name == map['type'], orElse: () => NotificationType.announcement),
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] ?? false,
    );
  }
}

class NotificationService {
  static const _notificationsKey = 'notifications';

  static Future<void> addNotification(String title, String message, NotificationType type) async {
    final user = await SessionManager.getUser();
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    final newNotification = Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(9999).toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );

    notifications.insert(0, newNotification);

    final List<String> notificationStrings = notifications.map((n) => jsonEncode(n.toMap())).toList();
    await prefs.setStringList(_getScopedKey(user.residentId), notificationStrings);
  }

  static Future<List<Notification>> getNotifications() async {
    final user = await SessionManager.getUser();
    if (user == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final notificationStrings = prefs.getStringList(_getScopedKey(user.residentId)) ?? [];
    return notificationStrings.map<Notification>((s) => Notification.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> markAllAsRead() async {
    final user = await SessionManager.getUser();
    if (user == null) return;

    final notifications = await getNotifications();
    for (var notification in notifications) {
      notification.isRead = true;
    }

    final List<String> notificationStrings = notifications.map((n) => jsonEncode(n.toMap())).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_getScopedKey(user.residentId), notificationStrings);
  }

  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  static String _getScopedKey(String residentId) {
    return '${_notificationsKey}_$residentId';
  }
}
