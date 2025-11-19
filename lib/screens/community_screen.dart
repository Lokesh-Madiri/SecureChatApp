import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Text(
          "Communities (Gmail Integration Coming Soon)",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
