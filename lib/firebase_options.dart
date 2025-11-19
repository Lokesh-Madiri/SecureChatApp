import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not set for this platform.',
        );
    }
  }

  // 🌐 Web config
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAZKEHlIigrwNarB0x1DBXiOxdCcf7HC9o",
    authDomain: "flutter-7c414.firebaseapp.com",
    projectId: "flutter-7c414",
    storageBucket: "flutter-7c414.firebasestorage.app",
    messagingSenderId: "608205446090",
    appId: "1:608205446090:web:d2e19319afb2e225d68d33",
    measurementId: "G-7FG6SLJZKQ",
  );

  // 🤖 Android (dummy for now, replace if you download google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDDOcduv6TzHU6aeakCuqZKTKFy5YvMiZI",
    appId: "1:608205446090:android:f6be8629c0efd937d68d33",
    messagingSenderId: "608205446090",
    projectId: "flutter-7c414",
    storageBucket: "flutter-7c414.firebasestorage.app",
  );

  // 🍏 iOS (dummy, replace later if you add GoogleService-Info.plist)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyAZKEHlIigrwNarB0x1DBXiOxdCcf7HC9o",
    appId: "1:608205446090:ios:dummyappid123456",
    messagingSenderId: "608205446090",
    projectId: "flutter-7c414",
    storageBucket: "flutter-7c414.firebasestorage.app",
    iosClientId: "dummy-ios-client-id.apps.googleusercontent.com",
    iosBundleId: "com.example.photoeditornew",
  );

  // 💻 macOS (same as iOS, can adjust later)
  static const FirebaseOptions macos = ios;

  // 🖥 Windows
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyAZKEHlIigrwNarB0x1DBXiOxdCcf7HC9o",
    appId: "1:608205446090:windows:dummyappid123456",
    messagingSenderId: "608205446090",
    projectId: "flutter-7c414",
    storageBucket: "flutter-7c414.firebasestorage.app",
  );

  // 🐧 Linux
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: "AIzaSyAZKEHlIigrwNarB0x1DBXiOxdCcf7HC9o",
    appId: "1:608205446090:linux:dummyappid123456",
    messagingSenderId: "608205446090",
    projectId: "flutter-7c414",
    storageBucket: "flutter-7c414.firebasestorage.app",
  );
}
