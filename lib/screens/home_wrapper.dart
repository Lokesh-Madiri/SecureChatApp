import 'package:flutter/material.dart';
import 'package:chat_app/screens/chat_lists_screen.dart';
import 'package:chat_app/screens/community_screen.dart';
import 'package:chat_app/screens/calls_screen.dart';
import 'package:chat_app/screens/profile_scrren.dart';
import 'package:chat_app/screens/incoming_call_screen.dart';
import 'package:chat_app/services/call_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _index = 0;
  final CallService _callService = CallService();

  final List<Widget> _screens = const [
    ChatListsScreen(),
    CommunityScreen(),
    CallsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    try {
      // Listen for incoming calls
      _callService.getIncomingCalls().listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final callDoc = snapshot.docs.first;
            final callData = callDoc.data() as Map<String, dynamic>;
            final callerId = callData['callerId'] as String;
            final callerName = callData['name'] as String;
            final channelId = callData['channelId'] as String? ?? 'default';
            final isVideo = callData['type'] == 'video';
            final callId = callDoc.id; // Get the document ID

            // Show incoming call screen
            _showIncomingCallScreen(
              callerId,
              callerName,
              channelId,
              isVideo,
              callId,
            );
          }
        },
        onError: (error) {
          print("📞 [HomeWrapper] Error listening for incoming calls: $error");
          // Silently fail if we can't listen for incoming calls due to permissions
        },
      );
    } catch (e) {
      print("📞 [HomeWrapper] Error setting up incoming call listener: $e");
      // Silently fail if we can't set up the listener due to permissions
    }
  }

  void _showIncomingCallScreen(
    String callerId,
    String callerName,
    String channelId,
    bool isVideo,
    String callId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallScreen(
        callerId: callerId,
        callerName: callerName,
        channelId: channelId,
        isVideo: isVideo,
        callId: callId,
        onAccept: () {
          // Handle accept - navigation is handled in IncomingCallScreen
        },
        onReject: () {
          // Update call status to rejected
          _callService.updateCallStatus(callId, "rejected");
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Color(0xFF25D366),
        unselectedItemColor: Colors.white70,
        currentIndex: _index,
        onTap: (value) {
          setState(() {
            _index = value;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: "Communities",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: "Calls"),
        ],
      ),
    );
  }
}
