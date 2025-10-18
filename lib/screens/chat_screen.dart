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
  Color? _chatBackgroundColor; // null means default (Lottie)
  final List<String> _lottieOptions = [
    'assets/Background_shooting_star.json',
    //could add more
  ];
  String? _selectedLottie;

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

  void _showChatThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Choose Lottie Background')),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _lottieOptions.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Default option (no selected Lottie)
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedLottie = null;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          border: _selectedLottie == null
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[300],
                        ),
                        child: const Center(child: Text('Default')),
                      ),
                    );
                  }

                  final lottieAsset = _lottieOptions[index - 1];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLottie = lottieAsset;
                        _chatBackgroundColor =
                            null; // clear color on Lottie pick
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        border: _selectedLottie == lottieAsset
                            ? Border.all(color: Colors.blue, width: 3)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Lottie.asset(
                          lottieAsset,
                          repeat: true,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const ListTile(title: Text('Choose Color Theme')),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue),
              title: const Text('Blue Theme'),
              onTap: () {
                setState(() {
                  _chatBackgroundColor = Colors.blue.withOpacity(0.1);
                  _selectedLottie = null; // clear Lottie on color pick
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green),
              title: const Text('Green Theme'),
              onTap: () {
                setState(() {
                  _chatBackgroundColor = Colors.green.withOpacity(0.1);
                  _selectedLottie = null;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.black),
              title: const Text('Dark Theme'),
              onTap: () {
                setState(() {
                  _chatBackgroundColor = Colors.black.withOpacity(0.2);
                  _selectedLottie = null;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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

  Future<void> _confirmAndDeleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete the entire chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chatService.deleteChat(_selectedUserId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully.')),
        );
        setState(() {
          // Optionally clear decrypted messages cache
          _decryptedMessages.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete chat: $e')));
      }
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

                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    // Handle menu item selection
                    switch (value) {
                      case 'chat_theme':
                        print('Option 1 selected');
                        _showChatThemePicker(context);
                        break;
                      case 'delete_chat':
                        print('Option 2 selected');
                        _confirmAndDeleteChat();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'chat_theme',
                          child: Text('Chat Theme'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete_chat',
                          child: Text('Delete Chat'),
                        ),
                      ],
                ),
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
          child: _selectedLottie != null
              ? Opacity(
                  opacity: 1,
                  child: Lottie.asset(
                    _selectedLottie!,
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                )
              : _chatBackgroundColor == null
              ? Opacity(
                  opacity: 1,
                  child: Lottie.asset(
                    'assets/Background_shooting_star.json',
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                )
              : Container(color: _chatBackgroundColor),
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
