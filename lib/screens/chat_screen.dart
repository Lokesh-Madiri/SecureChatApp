import 'dart:io';
import 'dart:convert';

import 'package:chat_app/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/services/encryption_service.dart';
import 'package:chat_app/services/call_service.dart';
import 'package:chat_app/widgets/message_input.dart';
import 'package:chat_app/screens/video_call_screen.dart';
import 'package:lottie/lottie.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String userImageBase64;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userImageBase64,
  });
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final EncryptionService _encryptionService = EncryptionService();
  final CallService _callService = CallService();
  final ImagePicker _imagePicker = ImagePicker();

  // 🔥 ADDED FOR USER SEARCH
  bool _isSearchingUsers = false; // shows/hides search bar in users list
  String _userSearchQuery = ''; // stores search text

  // Theme and Design
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _onSurfaceColor = Colors.white;

  Color? _chatBackgroundColor;
  final List<String> _lottieOptions = [
    'assets/Background_shooting_star.json',
    // Add more Lottie files here
  ];
  String? _selectedLottie;

  late String _selectedUserId;
  late String _selectedUserName;
  late String _selectedUserEmail;
  late String _selectedUserImageBase64;
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _decryptedMessages = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _encryptionService.initialize();

    _selectedUserId = widget.userId;
    _selectedUserName = widget.userName;
    _selectedUserEmail = widget.userEmail;
    _selectedUserImageBase64 = widget.userImageBase64;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (!_isUsersListVisible) {
      //   _scrollToBottom();
      // }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showChatThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _onSurfaceColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // Lottie Backgrounds Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat Backgrounds',
                    style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _lottieOptions.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildThemeOption(
                            label: 'Default',
                            isSelected:
                                _selectedLottie == null &&
                                _chatBackgroundColor == null,
                            onTap: () {
                              setState(() {
                                _selectedLottie = null;
                                _chatBackgroundColor = null;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_primaryColor, _secondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.chat,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          );
                        }

                        final lottieAsset = _lottieOptions[index - 1];
                        return _buildThemeOption(
                          label: 'Theme $index',
                          isSelected: _selectedLottie == lottieAsset,
                          onTap: () {
                            setState(() {
                              _selectedLottie = lottieAsset;
                              _chatBackgroundColor = null;
                            });
                            Navigator.pop(context);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Lottie.asset(
                              lottieAsset,
                              repeat: true,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Color Themes Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Color Themes',
                    style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildColorThemeOption(
                    color: Colors.blue.withOpacity(0.1),
                    label: 'Blue Theme',
                    icon: Icons.water_drop,
                  ),
                  _buildColorThemeOption(
                    color: Colors.green.withOpacity(0.1),
                    label: 'Green Theme',
                    icon: Icons.nature,
                  ),
                  _buildColorThemeOption(
                    color: Colors.purple.withOpacity(0.1),
                    label: 'Purple Theme',
                    icon: Icons.brush,
                  ),
                  _buildColorThemeOption(
                    color: Colors.black.withOpacity(0.2),
                    label: 'Dark Theme',
                    icon: Icons.dark_mode,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: _primaryColor, width: 3)
                  : Border.all(color: _surfaceColor.withOpacity(0.5), width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: child,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: _onSurfaceColor.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorThemeOption({
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _onSurfaceColor.withOpacity(0.2)),
        ),
        child: Icon(icon, color: _onSurfaceColor.withOpacity(0.7), size: 20),
      ),
      title: Text(label, style: TextStyle(color: _onSurfaceColor)),
      trailing: _chatBackgroundColor == color
          ? Icon(Icons.check_circle, color: _primaryColor)
          : null,
      onTap: () {
        setState(() {
          _chatBackgroundColor = color;
          _selectedLottie = null;
        });
        Navigator.pop(context);
      },
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

  void _selectUser(
    String userId,
    String userName,
    String userEmail,
    String profileImage,
  ) {
    setState(() {
      _selectedUserId = userId;
      _selectedUserName = userName;
      _selectedUserEmail = userEmail;
      _selectedUserImageBase64 = profileImage; // 🔥 Add this
      // _isUsersListVisible = false;
      _decryptedMessages.clear();
    });

    _animationController.reset();
    _animationController.forward();
  }

  // void _showUsersList() {
  //   setState(() {
  //     // _isUsersListVisible = true;
  //     _selectedUserId = '';
  //     _selectedUserName = '';
  //     _selectedUserEmail = '';
  //   });
  // }

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
      _showSnackBar('Failed to send image: ${e.toString()}');
    }
  }

  Future<Map<String, String>> _getLatestMessage(String userId) async {
    final chatId = _chatService.getChatId(
      _chatService.getCurrentUserId(),
      userId,
    );

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

    // Image message
    if (type == 'image') {
      return {"message": "📷 Photo", "time": formattedTime};
    }

    // System message
    if (type == 'system') {
      return {"message": data['message'], "time": formattedTime};
    }

    // Text message → decrypt
    if (type == 'text') {
      try {
        final encrypted = data['message'];
        final decrypted = await _encryptionService.decrypt(encrypted);
        return {"message": decrypted, "time": formattedTime};
      } catch (e) {
        return {"message": "Message", "time": formattedTime};
      }
    }

    return {"message": "Message", "time": formattedTime};
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text('Sign Out', style: TextStyle(color: _onSurfaceColor)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _onSurfaceColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: _onSurfaceColor)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        _showSnackBar('Error signing out: ${e.toString()}');
      }
    }
  }

  Future<void> _confirmAndDeleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text('Delete Chat', style: TextStyle(color: _onSurfaceColor)),
        content: Text(
          'Are you sure you want to delete the entire chat with $_selectedUserName? This action cannot be undone.',
          style: TextStyle(color: _onSurfaceColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: _onSurfaceColor)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chatService.deleteChat(_selectedUserId);
        _showSnackBar('Chat deleted successfully');
        setState(() {
          _decryptedMessages.clear();
        });
      } catch (e) {
        _showSnackBar('Failed to delete chat: ${e.toString()}');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _surfaceColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🟦 [ChatScreen] build() — opening chat with ${widget.userId}");

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildChatInterface(), // 👈 FIX: show chat directly
      ),
    );
  }

  Widget _buildUsersList() {
    return Column(
      children: [
        // TOP BAR
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text("Secure Chat"),

            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
            ],
          ),
        ),

        // 🔍 SEARCH BAR (WhatsApp style)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                icon: Icon(Icons.search, color: Colors.white70),
                hintText: "Search users...",
                hintStyle: TextStyle(color: Colors.white60),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _userSearchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),

        // USER LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatService.getUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return _buildErrorState("Error: ${snapshot.error}");
              if (snapshot.connectionState == ConnectionState.waiting)
                return _buildLoadingState();

              final users = snapshot.data!.docs;
              if (users.isEmpty) return _buildEmptyState();

              // 🔥 Apply search filter
              final filtered = _userSearchQuery.isEmpty
                  ? users
                  : users.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? "").toLowerCase();
                      final email = (data['email'] ?? "").toLowerCase();
                      return name.contains(_userSearchQuery) ||
                          email.contains(_userSearchQuery);
                    }).toList();

              return FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: EdgeInsets.zero, // 🔥 Remove unwanted top space
                  children: filtered
                      .map((doc) => _buildUserListItem(doc))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Unknown User';
    final String userId = data['uid'];

    // Profile Image
    final hasImage =
        data['profileImageBase64'] != null &&
        data['profileImageBase64'].toString().isNotEmpty;

    final avatar = CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey.shade800,
      backgroundImage: hasImage
          ? MemoryImage(base64Decode(data['profileImageBase64']))
          : null,
      child: !hasImage
          ? Icon(Icons.person, size: 28, color: _onSurfaceColor)
          : null,
    );

    return InkWell(
      onTap: () => _selectUser(
        userId,
        name,
        data['email'],
        data['profileImageBase64'] ?? '',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),

            // NAME + LATEST MESSAGE + TIME (like WhatsApp)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // LATEST MESSAGE
                  FutureBuilder<Map<String, String>>(
                    future: _getLatestMessage(userId),
                    builder: (context, snapshot) {
                      final msg = snapshot.data?["message"] ?? "";
                      final time = snapshot.data?["time"] ?? "";

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              msg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // MESSAGE TIME (WhatsApp style)
            FutureBuilder<Map<String, String>>(
              future: _getLatestMessage(userId),
              builder: (context, snapshot) {
                final time = snapshot.data?["time"] ?? "";

                return Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: _selectedLottie != null
              ? Opacity(
                  opacity: 0.6,
                  child: Lottie.asset(
                    _selectedLottie!,
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                )
              : _chatBackgroundColor == null
              ? Opacity(
                  opacity: 0.6,
                  child: Lottie.asset(
                    'assets/Background_shooting_star.json',
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                )
              : Container(color: _chatBackgroundColor),
        ),

        Column(
          children: [
            // Custom Chat App Bar
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    print("🔙 Back pressed — popping ChatScreen");
                    Navigator.pop(context); // Go back properly
                  },
                ),

                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      backgroundImage: (_selectedUserImageBase64.isNotEmpty)
                          ? MemoryImage(base64Decode(_selectedUserImageBase64))
                          : null,
                      child: _selectedUserImageBase64.isEmpty
                          ? Icon(Icons.person, color: _primaryColor, size: 20)
                          : null,
                    ),

                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _selectedUserEmail,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.video_call, color: Colors.white),
                    onPressed: () => _initiateCall(true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.white),
                    onPressed: () => _initiateCall(false),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: _surfaceColor,
                    onSelected: (value) {
                      switch (value) {
                        case 'chat_theme':
                          _showChatThemePicker(context);
                          break;
                        case 'delete_chat':
                          _confirmAndDeleteChat();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'chat_theme',
                        child: Row(
                          children: [
                            Icon(Icons.palette, color: _onSurfaceColor),
                            const SizedBox(width: 12),
                            Text(
                              'Chat Theme',
                              style: TextStyle(color: _onSurfaceColor),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete_chat',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            const SizedBox(width: 12),
                            Text(
                              'Delete Chat',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Messages
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessagesStream(_selectedUserId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorState('Error loading messages');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    final messages = snapshot.data!.docs;
                    if (messages.isEmpty) {
                      return _buildEmptyChatState();
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(messages[index]);
                      },
                    );
                  },
                ),
              ),
            ),

            // Message Input
            MessageInput(
              onSendMessage: (message) {
                _chatService.sendTextMessage(_selectedUserId, message);
                _scrollToBottom();
              },
              onSendImage: _sendImage,
              receiverId: _selectedUserId,
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

    if (_decryptedMessages.containsKey(messageId) && messageType == 'text') {
      messageContent = _decryptedMessages[messageId]!;
    } else if (messageType == 'text') {
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

  // Helper Widgets for Different States
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/loading_animation.json',
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              color: _onSurfaceColor.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: _onSurfaceColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/empty_state.json', // Add an empty state Lottie
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 24),
          Text(
            'No users found',
            style: TextStyle(
              color: _onSurfaceColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create another account to start chatting',
            style: TextStyle(
              color: _onSurfaceColor.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  _secondaryColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: _primaryColor,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: TextStyle(
              color: _onSurfaceColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message to $_selectedUserName',
            style: TextStyle(
              color: _onSurfaceColor.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
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
      if (mounted) {
        setState(() {
          _decryptedMessages[messageId] = 'Unable to decrypt message';
        });
      }
    }
  }

  // 🔹 Initiate a call (voice or video)
  Future<void> _initiateCall(bool isVideo) async {
    print(
      "📞 [ChatScreen] Initiating ${isVideo ? 'video' : 'voice'} call to $_selectedUserId",
    );

    try {
      // Generate a unique channel ID for this call
      final channelId = _chatService.getChatId(
        _chatService.getCurrentUserId(),
        _selectedUserId,
      );

      // Save call log and send system message, get the call ID
      final callId = await _callService.saveCallLog(
        otherUserId: _selectedUserId,
        otherUserName: _selectedUserName,
        isVideo: isVideo,
        isOutgoing: true,
        channelId: channelId,
      );

      // Navigate to the video call screen with the call ID
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            channelId: channelId,
            isVideo: isVideo,
            callId: callId,
          ),
        ),
      );
    } catch (e) {
      print("📞 [ChatScreen][Error] Failed to initiate call: $e");
      _showSnackBar(
        "Failed to initiate call. Calls will still show in chat history.",
      );

      // Even if we can't initiate the call properly, we still want to show it in chat
      // The saveCallLog method already handles this fallback
    }
  }
}
