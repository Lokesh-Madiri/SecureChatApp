import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/chat_service.dart';
import '../services/chat_notification_service.dart'; // Added import
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // 👈 added
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import 'package:cloud_firestore/cloud_firestore.dart'; // Added import

class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function() onSendImage;
  final String receiverId; // 👈 who we’re chatting with

  const MessageInput({
    super.key,
    required this.onSendMessage,
    required this.onSendImage,
    required this.receiverId,
  });

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _messageController = TextEditingController();
  bool _isComposing = false;
  bool _isRecording = false;
  bool _showEmojiPicker = false; // 👈 added for emoji picker toggle

  final AudioRecorder _recorder = AudioRecorder();
  final ChatService _chatService = ChatService();
  final ChatNotificationService _notificationService =
      ChatNotificationService(); // Added notification service
  final FirebaseAuth _auth = FirebaseAuth.instance; // Added auth instance
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Added firestore instance
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // 👇 close emoji picker when keyboard opens
    FocusManager.instance.addListener(() {
      if (FocusManager.instance.primaryFocus != null && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  // 🔹 Send a text message
  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) {
      print('[MessageInput] Empty message ignored.');
      return;
    }

    print('[MessageInput] Sending text message: "$text"');
    widget.onSendMessage(text.trim());

    // Send notification for the new message to the recipient (not the sender)
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Get the sender's name from user document to ensure accuracy
      String senderName = currentUser.displayName ?? 'User';
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          senderName = userDoc.data()!['name'] ?? senderName;
        }
      } catch (e) {
        print('Error getting sender name: $e');
      }

      await _notificationService.sendNewMessageNotification(
        receiverId:
            widget.receiverId, // This is correct - sending to the recipient
        senderName: senderName,
        message: text.trim(),
        messageType: 'text',
      );
    }

    _messageController.clear();
    setState(() => _isComposing = false);
  }

  /// Insert emoji text at current cursor position
  void _onEmojiSelected(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = (selection.isValid && selection.start >= 0)
        ? text.replaceRange(selection.start, selection.end, emoji)
        : text + emoji;

    final cursorPos =
        (selection.isValid && selection.start >= 0
            ? selection.start
            : newText.length - emoji.length) +
        emoji.length;

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos),
    );

    setState(() => _isComposing = _messageController.text.isNotEmpty);
  }

  /// Handle backspace tapped on emoji keyboard
  void _onBackspacePressed() {
    final text = _messageController.text;
    final selection = _messageController.selection;

    if (!selection.isValid) {
      if (text.isNotEmpty) {
        final newText = text.substring(0, text.length - 1);
        _messageController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
      setState(() => _isComposing = _messageController.text.isNotEmpty);
      return;
    }

    final start = selection.start;
    final end = selection.end;

    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      // remove previous code unit (this is a simple approach; emoji surrogate pairs handled well enough by picker)
      final charStart = start - 1;
      final newText = text.replaceRange(charStart, end, '');
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: charStart),
      );
    }

    setState(() => _isComposing = _messageController.text.isNotEmpty);
  }

  // 🎤 Start recording
  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() => _isRecording = true);
        print('[MessageInput] 🎙️ Recording started: $filePath');
      } else {
        print('[MessageInput][Error] Microphone permission not granted.');
      }
    } catch (e) {
      print('[MessageInput][Error] Failed to start recording: $e');
    }
  }

  // 🛑 Stop recording & send
  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path == null) {
        print('[MessageInput] ⚠️ No audio file found.');
        return;
      }

      final file = File(path);
      final duration = await _getAudioDuration(file);
      print('[MessageInput] 🎤 Recording stopped: $path');
      print('[MessageInput] ⏱️ Duration: ${duration.toStringAsFixed(2)}s');

      // Notify the parent widget to handle the voice message sending
      // The actual sending is handled by the ChatScreen through the callback

      // Send notification for the new voice message to the recipient
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get the sender's name from user document to ensure accuracy
        String senderName = currentUser.displayName ?? 'User';
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (userDoc.exists && userDoc.data() != null) {
            senderName = userDoc.data()!['name'] ?? senderName;
          }
        } catch (e) {
          print('Error getting sender name: $e');
        }

        await _notificationService.sendNewMessageNotification(
          receiverId: widget.receiverId, // Sending to the recipient
          senderName: senderName,
          message: 'Voice message',
          messageType: 'voice_base64',
        );
      }

      print('[MessageInput] ✅ Voice message sent successfully.');
    } catch (e) {
      print('[MessageInput][Error] Failed to stop recording: $e');
    }
  }

  // Rough duration estimate (in seconds)
  Future<double> _getAudioDuration(File file) async {
    try {
      final bytes = await file.length();
      final approxSeconds = bytes / 16000; // rough estimate
      return approxSeconds.clamp(1, 60).toDouble();
    } catch (e) {
      print('[MessageInput][Error] Could not determine duration: $e');
      return 0.0;
    }
  }

  // 📸 Open camera and send image
  Future<void> _openCamera() async {
    print('[MessageInput] Camera tapped.');
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        print('[MessageInput] Captured image: ${photo.path}');
        widget.onSendImage();

        // Send notification for the new image message to the recipient
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // Get the sender's name from user document to ensure accuracy
          String senderName = currentUser.displayName ?? 'User';
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .get();
            if (userDoc.exists && userDoc.data() != null) {
              senderName = userDoc.data()!['name'] ?? senderName;
            }
          } catch (e) {
            print('Error getting sender name: $e');
          }

          await _notificationService.sendNewMessageNotification(
            receiverId: widget.receiverId, // Sending to the recipient
            senderName: senderName,
            message: 'Photo',
            messageType: 'image_base64',
          );
        }

        print('[MessageInput] ✅ Image sent successfully!');
      } else {
        print('[MessageInput] Camera canceled or no photo captured.');
      }
    } catch (e) {
      print('[MessageInput][Error] Failed to capture or send image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 💬 Message input bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              // 😊 Emoji button (toggle)
              IconButton(
                icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard_alt_outlined
                      : Icons.emoji_emotions_outlined,
                ),
                onPressed: () {
                  setState(() => _showEmojiPicker = !_showEmojiPicker);
                  if (_showEmojiPicker) FocusScope.of(context).unfocus();
                  print('[MessageInput] Emoji toggle: $_showEmojiPicker');
                },
              ),

              // 📎 Attach button
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {
                  print('[MessageInput] Attach image tapped.');
                  widget.onSendImage();
                },
              ),

              // ✏️ Text input
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (text) {
                    setState(() => _isComposing = text.isNotEmpty);
                  },
                  onSubmitted: _handleSubmitted,
                  onTap: () {
                    if (_showEmojiPicker) {
                      setState(() => _showEmojiPicker = false);
                    }
                  },
                ),
              ),

              // 🎤 Mic / Stop
              IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  color: _isRecording ? Colors.red : Colors.black87,
                ),
                onPressed: () {
                  if (_isRecording) {
                    _stopRecording();
                  } else {
                    _startRecording();
                  }
                },
              ),

              // 🚀 Send / 📸 Camera
              _isComposing
                  ? IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF128C7E)),
                      onPressed: () =>
                          _handleSubmitted(_messageController.text),
                    )
                  : IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _openCamera,
                    ),
            ],
          ),
        ),

        // 😄 Emoji picker (visible when toggled)
        Offstage(
          offstage: !_showEmojiPicker,
          child: SizedBox(
            height: 260,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _onEmojiSelected(emoji.emoji);
              },
              onBackspacePressed: _onBackspacePressed,
              config: const Config(
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  backgroundColor: Color(0xFFF2F2F2),
                ),
                categoryViewConfig: CategoryViewConfig(
                  showBackspaceButton: true,
                  backspaceColor: Colors.black54,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: Color(0xFFF2F2F2),
                  buttonColor: Color(0xFF128C7E),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
