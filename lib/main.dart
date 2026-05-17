import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:safechain/screens/forgot_password/reset_password_screen.dart';
import 'package:safechain/screens/startup/startup_screen.dart';
import 'package:safechain/services/connectivity_service.dart';
import 'package:safechain/services/notification_service.dart';
import 'package:safechain/firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Background FCM handler (Android/iOS only) ─────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final title = message.notification?.title ?? message.data['title'] ?? 'SafeChain';
  final body  = message.notification?.body  ?? message.data['body']  ?? '';

  final String typeString = message.data['type'] ?? 'announcement';
  final NotificationType type = NotificationType.values.firstWhere(
        (e) => e.name == typeString,
    orElse: () => NotificationType.announcement,
  );

  if (title.isNotEmpty) {
    // OS handles the banner, we just silently save it to the inbox
    await NotificationService.addNotification(title, body, type, showBanner: false);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase (Critical, must be done before runApp)
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 2. IMMEDIATELY run the app to prevent the black screen.
  // We no longer await Notification or Connectivity services here.
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

    // 3. Initialize non-blocking services AFTER the UI starts rendering
    _initializeAppServices();

    _initDeepLinks();
    if (Platform.isAndroid || Platform.isIOS) {
      _initFCMListeners();
    }
  }

  // NEW: Background initialization function
  Future<void> _initializeAppServices() async {
    await NotificationService.initialize();

    if (Platform.isAndroid || Platform.isIOS) {
      // Do not await this, let it fetch the token and ask permissions in the background
      NotificationService.initializeFCM();
    }

    // Start monitoring internet connectivity
    ConnectivityService().initialize();
  }

  void _initFCMListeners() {
    // App is in foreground — show local notification AND save to inbox
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'SafeChain';
      final body  = message.notification?.body  ?? message.data['body']  ?? '';

      final String typeString = message.data['type'] ?? 'announcement';
      final NotificationType type = NotificationType.values.firstWhere(
            (e) => e.name == typeString,
        orElse: () => NotificationType.announcement,
      );

      if (title.isNotEmpty) {
        NotificationService.addNotification(title, body, type, showBanner: true);
      }
    });

    // User tapped notification while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
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