import 'package:chat_app/screens/home_wrapper.dart';
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
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
    // Re-throw the error to prevent the app from running with uninitialized Firebase
    rethrow;
  }
  runApp(const SecureChatApp());
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

            // 🔥 Open HomeWrapper instead of ChatScreen
            return const HomeWrapper();
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
