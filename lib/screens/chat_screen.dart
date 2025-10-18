import 'dart:io';

import 'package:chat_app/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/services/encryption_service.dart';
import 'package:chat_app/widgets/message_input.dart';
import 'package:chat_app/screens/video_call_screen.dart';
import 'package:lottie/lottie.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final EncryptionService _encryptionService = EncryptionService();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedUserId = '';
  String _selectedUserName = '';
  bool _isUsersListVisible = true;
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _decryptedMessages = {};

  @override
  void initState() {
    super.initState();
    _encryptionService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isUsersListVisible) {
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectUser(String userId, String userName) {
    setState(() {
      _selectedUserId = userId;
      _selectedUserName = userName;
      _isUsersListVisible = false;
      _decryptedMessages.clear(); // Clear cached messages when switching users
    });
  }

  void _showUsersList() {
    setState(() {
      _isUsersListVisible = true;
      _selectedUserId = '';
    });
  }

  Future<void> _sendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        await _chatService.sendImageMessage(_selectedUserId, File(image.path));
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isUsersListVisible
          ? AppBar(
              title: const Text('Secure Chat'),
              backgroundColor: const Color(0xFF128C7E),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _showUsersList,
              ),
              title: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(_selectedUserName),
                ],
              ),
              backgroundColor: const Color(0xFF128C7E),
              actions: [
                IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoCallScreen(
                          channelId: _chatService.getChatId(
                            _chatService.getCurrentUserId(),
                            _selectedUserId,
                          ),
                          isVideo: true,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoCallScreen(
                          channelId: _chatService.getChatId(
                            _chatService.getCurrentUserId(),
                            _selectedUserId,
                          ),
                          isVideo: false,
                        ),
                      ),
                    );
                  },
                ),

                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
      body: _isUsersListVisible ? _buildUsersList() : _buildChatInterface(),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Lottie.asset(
              'assets/loading_animation.json', // your Lottie JSON file
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No other users found. Create another account to chat.',
            ),
          );
        }

        return ListView(
          children: snapshot.data!.docs
              .map<Widget>((doc) => _buildUserListItem(doc))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(data['name'] ?? 'Unknown User'),
      subtitle: Text(data['email'] ?? ''),
      onTap: () => _selectUser(data['uid'], data['name']),
    );
  }

  Widget _buildChatInterface() {
    return Stack(
      children: [
        // 🌀 Lottie Background
        Positioned.fill(
          child: Opacity(
            opacity: 1, // keep it subtle; you can increase this if you want
            child: Lottie.asset(
              'assets/Background_shooting_star.json', // your Lottie background file
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
        ),

        // 💬 Chat UI on top of background
        Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getMessagesStream(_selectedUserId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView(
                    controller: _scrollController,
                    children: snapshot.data!.docs
                        .map<Widget>((doc) => _buildMessageItem(doc))
                        .toList(),
                  );
                },
              ),
            ),
            MessageInput(
              onSendMessage: (message) {
                _chatService.sendTextMessage(_selectedUserId, message);
                _scrollToBottom();
              },
              onSendImage: _sendImage,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;

    bool isMe = data['senderId'] == _chatService.getCurrentUserId();
    String messageContent = data['message'];
    String messageType = data['type'] ?? 'text';
    String messageId = document.id;

    // Use cached decrypted message if available
    if (_decryptedMessages.containsKey(messageId) && messageType == 'text') {
      messageContent = _decryptedMessages[messageId]!;
    } else if (messageType == 'text') {
      // If not cached, decrypt asynchronously and update UI when done
      _decryptMessage(messageId, messageContent);
      messageContent = 'Decrypting...';
    }

    return ChatBubble(
      message: messageContent,
      isMe: isMe,
      messageType: messageType,
      timestamp: data['timestamp'] != null
          ? DateFormat(
              'HH:mm',
            ).format((data['timestamp'] as Timestamp).toDate())
          : '',
      isRead: data['isRead'] ?? false,
    );
  }

  Future<void> _decryptMessage(
    String messageId,
    String encryptedMessage,
  ) async {
    try {
      final decryptedMessage = await _encryptionService.decrypt(
        encryptedMessage,
      );

      if (mounted) {
        setState(() {
          _decryptedMessages[messageId] = decryptedMessage;
        });
      }
    } catch (e) {
      print("Error decrypting message: $e");

      if (mounted) {
        setState(() {
          _decryptedMessages[messageId] = 'Unable to decrypt message';
        });
      }
    }
  }
}
