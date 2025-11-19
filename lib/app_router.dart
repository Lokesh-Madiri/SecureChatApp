import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_scrren.dart';
import '../screens/auth_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthScreen());

      case '/chat':
        // Expecting: { "userId": "...", "userName": "...", "userEmail": "...", "userImageBase64": "..." }
        final args = settings.arguments;

        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              userId: args["userId"],
              userName: args["userName"],
              userEmail: args["userEmail"],
              userImageBase64: args["userImageBase64"] ?? "",
            ),
          );
        }

        // If wrong or missing arguments
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("Invalid chat arguments")),
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text("Page not found"))),
        );
    }
  }
}
