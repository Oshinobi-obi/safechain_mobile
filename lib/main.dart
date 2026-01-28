import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:safechain/screens/forgot_password/reset_password_screen.dart';
import 'package:safechain/screens/startup/startup_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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