import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:safechain/screens/forgot_password/reset_password_screen.dart';
import 'package:safechain/screens/startup/startup_screen.dart';
import 'package:safechain/services/notification_service.dart';
import 'package:safechain/firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Handle FCM background messages (app killed / background) ────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Show local notification when app is in background/killed
  final title = message.notification?.title ?? message.data['title'] ?? 'SafeChain';
  final body  = message.notification?.body  ?? message.data['body']  ?? '';
  if (title.isNotEmpty) {
    await NotificationService.showLocalNotification(title, body);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();
  await NotificationService.initializeFCM();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initFCMListeners();
  }

  // ── Listen for FCM messages when app is open (foreground) ─────
  void _initFCMListeners() {
    // App is in foreground — show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'SafeChain';
      final body  = message.notification?.body  ?? message.data['body']  ?? '';
      if (title.isNotEmpty) {
        NotificationService.showLocalNotification(title, body);
      }
    });

    // App was in background and user tapped the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Navigate to announcements tab
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    });
  }

  Future<void> _initDeepLinks() async {
    if (Platform.isAndroid || Platform.isIOS) {
      _appLinks = AppLinks();
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        if (!mounted) return;
        _processLink(uri);
      });

      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        if (!mounted) return;
        _processLink(initialUri);
      }
    }
  }

  void _processLink(Uri uri) {
    if (uri.path == '/reset-password-page' && uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token']!;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(token: token),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SafeChain',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF20C997)),
      ),
      home: const StartupScreen(),
    );
  }
}