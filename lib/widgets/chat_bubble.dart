import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class ChatBubble extends StatelessWidget {
  final bool isMe;
  final String message;
  final String messageType; // 'text', 'image_base64', or 'voice_base64'
  final String timestamp;
  final bool isRead;

  const ChatBubble({
    super.key,
    required this.isMe,
    required this.message,
    required this.messageType,
    required this.timestamp,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<Offset>(begin: Offset(isMe ? 1 : -1, 0), end: Offset(0, 0)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, Offset offset, child) {
        return Transform.translate(
          offset: Offset(offset.dx * 50, 0),
          child: Opacity(opacity: 1 - offset.dx.abs(), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMe)
              const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 📝 TEXT MESSAGE
                    if (messageType == 'text')
                      Text(message, style: const TextStyle(fontSize: 16)),

                    // 🖼️ IMAGE MESSAGE
                    if (messageType == 'image_base64')
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(),
                                body: PhotoView(
                                  imageProvider: MemoryImage(
                                    base64Decode(message),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(message),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    // 🎤 VOICE MESSAGE
                    if (messageType == 'voice_base64')
                      VoiceMessagePlayer(base64Audio: message),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isMe) const SizedBox(width: 4),
                        if (isMe)
                          Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: isRead ? Colors.blue : Colors.grey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe)
              const CircleAvatar(
                backgroundColor: Color(0xFF128C7E),
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🎧 Voice Message Player Widget (fixed for Android)
class VoiceMessagePlayer extends StatefulWidget {
  final String base64Audio;

  const VoiceMessagePlayer({super.key, required this.base64Audio});

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  File? _tempFile;

  @override
  void initState() {
    super.initState();

    _player.durationStream.listen((d) {
      if (d != null) setState(() => _duration = d);
    });

    _player.positionStream.listen((p) {
      setState(() => _position = p);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      final bytes = base64Decode(widget.base64Audio);

      // ✅ Save the bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      _tempFile = File(
        '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _tempFile!.writeAsBytes(bytes, flush: true);

      // ✅ Play the audio file
      await _player.setFilePath(_tempFile!.path);
      await _player.play();

      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    if (_tempFile != null && _tempFile!.existsSync()) {
      _tempFile!.delete(); // Clean up temp audio file
    }
    super.dispose();
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              ),
              iconSize: 36,
              color: Colors.teal,
              onPressed: _togglePlay,
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble(),
                value: _position.inMilliseconds
                    .clamp(0, _duration.inMilliseconds)
                    .toDouble(),
                onChanged: (value) async {
                  final newPosition = Duration(milliseconds: value.toInt());
                  await _player.seek(newPosition);
                },
              ),
            ),
            Text(_formatTime(_position), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
