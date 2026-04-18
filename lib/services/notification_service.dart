import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
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
  static const _fcmTokenKey      = 'fcm_token';
  static const _baseUrl          = 'https://safechain.site';

  // ── flutter_local_notifications ──────────────────────────────
  static final FlutterLocalNotificationsPlugin _localNotif =
  FlutterLocalNotificationsPlugin();
  static bool _localNotifInitialized = false;

  // ── Broadcast stream ──────────────────────────────────────────
  static final StreamController<int> _countController =
  StreamController<int>.broadcast();
  static Stream<int> get countStream => _countController.stream;

  // ── Initialize local notifications ───────────────────────────
  static Future<void> initialize() async {
    if (_localNotifInitialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _localNotifInitialized = true;
      return;
    }

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _localNotif.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {},
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'safechain_channel',
      'SafeChain Notifications',
      description: 'Notifications from the SafeChain app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _localNotifInitialized = true;
  }

  // ── Initialize FCM ────────────────────────────────────────────
  static Future<void> initializeFCM() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and save FCM token — upload to server only if user is logged in.
    // If not logged in yet, the token is cached in SharedPreferences and
    // uploadTokenAfterLogin() will send it once the user signs in.
    final token = await messaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh — always re-upload the new token
    messaging.onTokenRefresh.listen((newToken) async {
      await _saveFCMToken(newToken, forceUpload: true);
    });
  }

  // ── FIX: Call this right after a user logs in ─────────────────
  // Reads the cached FCM token from prefs and uploads it to the server.
  // This is needed because initializeFCM() runs at startup before login,
  // so the user is null at that point and the upload is skipped.
  static Future<void> uploadTokenAfterLogin() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_fcmTokenKey);
    if (token == null) return;

    final user = await SessionManager.getUser();
    if (user == null) return;

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/fcm/save_token.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resident_id': user.residentId,
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }),
      );
    } catch (e) {
      // Silently fail — will be retried next time
    }
  }

  // ── Save FCM token to server + local prefs ────────────────────
  // forceUpload: true skips the oldToken == token early-exit check.
  // Used by onTokenRefresh to ensure a changed token always gets uploaded.
  static Future<void> _saveFCMToken(String token, {bool forceUpload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString(_fcmTokenKey);

    // Always cache the latest token locally
    await prefs.setString(_fcmTokenKey, token);

    // Skip server upload if token unchanged and not forced
    if (!forceUpload && oldToken == token) return;

    final user = await SessionManager.getUser();
    if (user == null) {
      // User not logged in yet — token is saved to prefs above.
      // uploadTokenAfterLogin() will handle the server upload after login.
      return;
    }

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/fcm/save_token.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resident_id': user.residentId,
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }),
      );
    } catch (e) {
      // Silently fail — will retry next launch
    }
  }

  // ── Show a local notification ─────────────────────────────────
  static Future<void> showLocalNotification(String title, String body,
      {NotificationType type = NotificationType.announcement}) async {
    if (!_localNotifInitialized) await initialize();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final color = type == NotificationType.security
        ? const Color(0xFFEF4444)
        : type == NotificationType.device
        ? const Color(0xFF20C997)
        : const Color(0xFFF97316);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'safechain_channel',
      'SafeChain Notifications',
      channelDescription: 'Notifications from the SafeChain app',
      importance: Importance.high,
      priority: Priority.high,
      color: color,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    await _localNotif.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  // ── Add in-app notification + optionally show local banner ────
  static Future<void> addNotification(
      String title,
      String message,
      NotificationType type, {
        bool showBanner = true,
      }) async {
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

    await _saveAndBroadcast(user.residentId, notifications);

    if (showBanner) {
      await showLocalNotification(title, message, type: type);
    }
  }

  // ── Internal save + broadcast ─────────────────────────────────
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

  // ── CRUD ──────────────────────────────────────────────────────
  static Future<List<Notification>> getNotifications() async {
    final user = await SessionManager.getUser();
    if (user == null) return [];
    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList(_getScopedKey(user.residentId)) ?? [];
    return strings.map<Notification>((s) => Notification.fromMap(jsonDecode(s))).toList();
  }

  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  static Future<void> markAsRead(String id) async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final notifications = await getNotifications();
    for (final n in notifications) { if (n.id == id) n.isRead = true; }
    await _saveAndBroadcast(user.residentId, notifications);
  }

  static Future<void> markAllAsRead() async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final notifications = await getNotifications();
    for (final n in notifications) { n.isRead = true; }
    await _saveAndBroadcast(user.residentId, notifications);
  }

  static Future<void> deleteOne(String id) async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final notifications = await getNotifications();
    notifications.removeWhere((n) => n.id == id);
    await _saveAndBroadcast(user.residentId, notifications);
  }

  static Future<void> clearAll() async {
    final user = await SessionManager.getUser();
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getScopedKey(user.residentId));
    _countController.add(0);
  }

  static String _getScopedKey(String residentId) =>
      '${_notificationsKey}_$residentId';
}