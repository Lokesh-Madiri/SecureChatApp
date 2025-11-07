import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/chat_service.dart';

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

  final AudioRecorder _recorder = AudioRecorder();
  final ChatService _chatService = ChatService();
  final ImagePicker _picker = ImagePicker();

  // 🔹 Send a text message
  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) {
      print('[MessageInput] Empty message ignored.');
      return;
    }

    print('[MessageInput] Sending text message: "$text"');
    widget.onSendMessage(text.trim());
    await _chatService.sendTextMessage(widget.receiverId, text.trim());

    _messageController.clear();
    setState(() => _isComposing = false);
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

      await _chatService.sendVoiceMessage(widget.receiverId, file, duration);
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
        await _chatService.sendImageMessage(
          widget.receiverId,
          File(photo.path),
        );
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
    return Container(
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
          // 😊 Emoji button
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: () => print('[MessageInput] Emoji tapped.'),
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
                  onPressed: () => _handleSubmitted(_messageController.text),
                )
              : IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _openCamera,
                ),
        ],
      ),
    );
  }
}
