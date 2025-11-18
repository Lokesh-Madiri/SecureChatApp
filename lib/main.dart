import 'package:chat_app/screens/profile_scrren.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'services/user_service.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const AppInitializer());
}


class AppInitializer extends StatelessWidget {
  
  const AppInitializer({super.key});

  // Initialize Firebase safely and only once
  Future<FirebaseApp> _initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      return await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      return Firebase.apps.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        // ✅ Firebase initialized
        if (snapshot.connectionState == ConnectionState.done) {
          return const SecureChatApp();
        }

        // ❌ Error initializing Firebase
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(
                  'Error initializing Firebase: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        // ⏳ Show loading spinner until Firebase finishes initializing
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}

class SecureChatApp extends StatelessWidget {
  const SecureChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Chat',
      theme: ThemeData(
        primaryColor: const Color(0xFF128C7E),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF25D366),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Lottie.asset(
                  'assets/loading_animation.json',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            );
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            UserService().ensureUserDocumentExists(user);
            return const ChatScreen();
          } else {
            return const AuthScreen();
          }
        },
      ),
      routes: {'/profile': (context) => const ProfileScreen()},
      debugShowCheckedModeBanner: false,
    );
  }
}
