import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory Notification.fromMap(Map<String, dynamic> map) => Notification(
    id: map['id'],
    title: map['title'],
    message: map['message'],
    type: NotificationType.values.firstWhere(
          (e) => e.name == map['type'],
      orElse: () => NotificationType.announcement,
    ),
    timestamp: DateTime.parse(map['timestamp']),
    isRead: map['isRead'] ?? false,
  );
}

class NotificationService {
  static const _notificationsKey = 'notifications';

  // ── flutter_local_notifications plugin instance ─────────────────
  static final FlutterLocalNotificationsPlugin _localNotif =
  FlutterLocalNotificationsPlugin();

  static bool _localNotifInitialized = false;

  // ── Broadcast stream ────────────────────────────────────────────
  static final StreamController<int> _countController =
  StreamController<int>.broadcast();

  static Stream<int> get countStream => _countController.stream;

  // ── Initialize local notifications (call once in main.dart) ────
  static Future<void> initialize() async {
    if (_localNotifInitialized) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _localNotif.initialize(initSettings);

    // Create the notification channel for Android 8+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'safechain_channel',         // channel id
      'SafeChain Notifications',   // channel name
      description: 'Notifications from the SafeChain app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permission on Android 13+
    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _localNotifInitialized = true;
  }

  // ── Push a phone status bar notification ───────────────────────
  static Future<void> _pushPhoneNotification(
      String title,
      String message,
      NotificationType type,
      ) async {
    if (!_localNotifInitialized) await initialize();

    // Pick icon color per type
    final color = type == NotificationType.security
        ? const Color(0xFFEF4444) // red
        : type == NotificationType.device
        ? const Color(0xFF20C997) // green
        : const Color(0xFFF97316); // orange (announcement)

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'safechain_channel',
      'SafeChain Notifications',
      channelDescription: 'Notifications from the SafeChain app',
      importance: Importance.high,
      priority: Priority.high,
      color: color,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(message),
    );

    final NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // unique id
      title,
      message,
      details,
    );
  }

  // ── Internal: save + broadcast stream ──────────────────────────
  static Future<void> _saveAndBroadcast(
      String residentId,
      List<Notification> notifications,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final strings = notifications.map((n) => jsonEncode(n.toMap())).toList();
    await prefs.setStringList(_getScopedKey(residentId), strings);
    final count = notifications.where((n) => !n.isRead).length;
    _countController.add(count);
  }

  // ── Add notification — saves locally AND pushes to status bar ──
  static Future<void> addNotification(
      String title,
      String message,
      NotificationType type,
      ) async {
    final user = await SessionManager.getUser();
    if (user == null) return;

    final notifications = await getNotifications();

    final newNotification = Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(9999).toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );

    notifications.insert(0, newNotification);
    if (notifications.length > 50) notifications.removeLast();

    // Save to SharedPreferences + fire stream
    await _saveAndBroadcast(user.residentId, notifications);

    // Push to phone status bar
    await _pushPhoneNotification(title, message, type);
  }

  // ── Get all notifications ───────────────────────────────────────
  static Future<List<Notification>> getNotifications() async {
    final user = await SessionManager.getUser();
    if (user == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList(_getScopedKey(user.residentId)) ?? [];
    return strings
        .map<Notification>((s) => Notification.fromMap(jsonDecode(s)))
        .toList();
  }

  // ── Unread count ────────────────────────────────────────────────
  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // ── Mark one as read ────────────────────────────────────────────
  static Future<void> markAsRead(String id) async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final notifications = await getNotifications();
    for (final n in notifications) {
      if (n.id == id) n.isRead = true;
    }
    await _saveAndBroadcast(user.residentId, notifications);
  }

  // ── Mark ALL as read ────────────────────────────────────────────
  static Future<void> markAllAsRead() async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final notifications = await getNotifications();
    for (final n in notifications) {
      n.isRead = true;
    }
    await _saveAndBroadcast(user.residentId, notifications);
  }

  // ── Delete one ──────────────────────────────────────────────────
  static Future<void> deleteOne(String id) async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final notifications = await getNotifications();
    notifications.removeWhere((n) => n.id == id);
    await _saveAndBroadcast(user.residentId, notifications);
  }

  // ── Clear ALL ───────────────────────────────────────────────────
  static Future<void> clearAll() async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getScopedKey(user.residentId));
    _countController.add(0);
  }

  // ── Scoped key per user ─────────────────────────────────────────
  static String _getScopedKey(String residentId) =>
      '${_notificationsKey}_$residentId';
}