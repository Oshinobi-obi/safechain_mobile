import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safechain/screens/forgot_password/reset_password_screen.dart';
import 'package:safechain/screens/startup/startup_screen.dart';
import 'package:uni_links/uni_links.dart';

// A global navigator key is needed to navigate from the deep link handler
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
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // Handle deep links when the app is already running
    _handleIncomingLinks();
    // Handle the initial deep link when the app is launched from a cold state
    _handleInitialLink();
  }

  /// Handles incoming links while the app is running in the background.
  void _handleIncomingLinks() {
    _sub = uriLinkStream.listen((Uri? uri) {
      if (!mounted) return;
      _processLink(uri);
    }, onError: (err) {
      // You can add error logging here
    });
  }

  /// Handles the link that the app was launched with.
  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await getInitialUri();
      if (!mounted) return;
      _processLink(initialUri);
    } on PlatformException {
      // Handle error
    } on FormatException {
      // Handle error
    }
  }

  /// Parses the URI and navigates to the ResetPasswordScreen if it's a valid reset link.
  void _processLink(Uri? uri) {
    if (uri == null) return;

    // Check if the link is a password reset link
    if (uri.path == '/reset-password-page' && uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token']!;
      // Use the navigatorKey to push the new screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(token: token),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Assign the navigator key
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
