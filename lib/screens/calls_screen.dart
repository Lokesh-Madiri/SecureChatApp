import 'package:flutter/material.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Text(
          "Calls History",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
