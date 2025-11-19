import 'dart:convert';

import 'package:chat_app/screens/chat_screen.dart';
import 'package:chat_app/screens/profile_scrren.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/services/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListsScreen extends StatefulWidget {
  const ChatListsScreen({super.key});

  @override
  State<ChatListsScreen> createState() => _ChatListsScreenState();
}

class _ChatListsScreenState extends State<ChatListsScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final EncryptionService _encryptionService = EncryptionService();

  // design colors (match your theme)
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _onSurfaceColor = Colors.white;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      await _encryptionService.initialize();
      print('[ChatLists] Encryption initialized');
    } catch (e) {
      print('[ChatLists][Error] Encryption init failed: $e');
    }
  }

  /// Fetch latest message preview
  Future<Map<String, String>> _fetchLatestMessageFor(String userId) async {
    final currentUser = _chatService.getCurrentUserId();
    final chatId = _chatService.getChatId(currentUser, userId);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {"message": "No messages yet", "time": ""};
      }

      final data = snapshot.docs.first.data();
      final type = data['type'];
      final timestamp = data['timestamp'] as Timestamp?;
      final formattedTime = timestamp != null
          ? DateFormat('hh:mm a').format(timestamp.toDate())
          : "";

      if (type == "image_base64") {
        return {"message": "📷 Photo", "time": formattedTime};
      }

      if (type == "voice_base64") {
        return {"message": "🎤 Voice Message", "time": formattedTime};
      }

      if (type == "system") {
        return {"message": data["message"], "time": formattedTime};
      }

      if (type == "text") {
        final encrypted = data["message"];
        final decrypted = await _encryptionService.decryptWithFallback(
          encrypted,
        );
        return {"message": decrypted, "time": formattedTime};
      }

      return {"message": "Message", "time": formattedTime};
    } catch (e) {
      print('[ChatLists][Error] $e');
      return {"message": "Error", "time": ""};
    }
  }

  Future<void> _openProfile() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      appBar: AppBar(
        title: const Text("Chats"),
        backgroundColor: _primaryColor,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: _openProfile),
        ],
      ),

      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.white54),
                  hintText: 'Search or start new chat',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
            ),
          ),

          // 🔥 USER LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading users",
                      style: TextStyle(color: _onSurfaceColor),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                final users = snapshot.data!.docs;

                final filtered = _searchQuery.isEmpty
                    ? users
                    : users.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery) ||
                            email.contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(color: _onSurfaceColor),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final userId = data["uid"];
                    final name = data["name"] ?? "Unknown";
                    final email = data["email"] ?? "";
                    final profileBase64 = data["profileImageBase64"] ?? "";

                    final hasImage =
                        profileBase64.isNotEmpty && profileBase64 != "null";

                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              userId: userId,
                              userName: name,
                              userEmail: email,
                              userImageBase64: profileBase64,
                            ),
                          ),
                        );
                      },

                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),

                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: hasImage
                            ? MemoryImage(base64Decode(profileBase64))
                            : null,
                        child: !hasImage
                            ? Icon(
                                Icons.person,
                                size: 28,
                                color: _onSurfaceColor,
                              )
                            : null,
                      ),

                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      subtitle: FutureBuilder<Map<String, String>>(
                        future: _fetchLatestMessageFor(userId),
                        builder: (context, snap) {
                          final msg = snap.data?["message"] ?? "";
                          return Text(
                            msg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          );
                        },
                      ),

                      trailing: FutureBuilder<Map<String, String>>(
                        future: _fetchLatestMessageFor(userId),
                        builder: (context, snap) {
                          final time = snap.data?["time"] ?? "";
                          return Text(
                            time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
