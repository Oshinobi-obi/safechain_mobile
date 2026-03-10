import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  // Values from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBki0uYMdKd5jRXv9ga-_uV_KTY6LY2Vcc',
    appId:             '1:700412208028:android:66fe1bb5c04a8f5c97de59',
    messagingSenderId: '700412208028',
    projectId:         'safechain-4daf7',
    storageBucket:     'safechain-4daf7.firebasestorage.app',
  );
}