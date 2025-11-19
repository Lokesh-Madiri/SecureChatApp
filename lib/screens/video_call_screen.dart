import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelId;
  final bool isVideo;
  final String? callId; // Add this to track the call

  const VideoCallScreen({
    super.key,
    required this.channelId,
    required this.isVideo,
    this.callId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  final String appId = dotenv.env['AGORA_APP_ID'] ?? '';

  RtcEngine? _engine;
  final List<int> _remoteUids = [];
  bool _isEngineReady = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = true;
  late int _localUid;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Design Colors
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _onSurfaceColor = Colors.white;
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _successColor = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _initAgora();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _endCall();
    super.dispose();
  }

  Future<void> _initAgora() async {
    print('[Agora] === INIT START ===');

    // Requesting permissions
    await [Permission.microphone, Permission.camera].request();

    var micStatus = await Permission.microphone.status;
    var camStatus = await Permission.camera.status;

    if (!micStatus.isGranted || !camStatus.isGranted) {
      _showPermissionError();
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine?.initialize(RtcEngineContext(appId: appId));

      if (widget.isVideo) {
        await _engine?.enableVideo();
        await _engine?.startPreview();
      } else {
        await _engine?.disableVideo();
      }

      _engine?.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            print('[Agora] ✅ Successfully joined channel: ${widget.channelId}');
            setState(() {
              _isEngineReady = true;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            print('[Agora] 👤 Remote user joined: $remoteUid');
            setState(() {
              if (!_remoteUids.contains(remoteUid)) {
                _remoteUids.add(remoteUid);
              }
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            print('[Agora] 👤 Remote user left: $remoteUid');
            setState(() {
              _remoteUids.remove(remoteUid);
            });
          },
          onConnectionStateChanged: (connection, state, reason) {
            print('[Agora] Connection state changed: $state');
          },
        ),
      );

      _localUid = DateTime.now().millisecondsSinceEpoch % 100000;

      await _engine?.joinChannel(
        token: '',
        channelId: widget.channelId,
        uid: _localUid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: widget.isVideo,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      print('[Agora][Error] Exception during setup: $e');
      _showErrorSnackBar('Failed to initialize call: ${e.toString()}');
    }
  }

  void _showPermissionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text(
          'Permissions Required',
          style: TextStyle(color: _onSurfaceColor),
        ),
        content: Text(
          'This app needs camera and microphone permissions to make calls.',
          style: TextStyle(color: _onSurfaceColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: _onSurfaceColor)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _endCall() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.stopPreview();
      await _engine?.release();

      // Update call status to ended if we have a call ID
      if (widget.callId != null && widget.callId != "dummy_call_id") {
        final FirebaseFirestore _firestore = FirebaseFirestore.instance;
        await _firestore.collection("calls").doc(widget.callId).update({
          "status": "ended",
          "endTime": FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('[Agora] Error ending call: $e');
      // Silently fail if we can't update call status due to permissions
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _toggleMute() async {
    try {
      await _engine?.muteLocalAudioStream(!_isMuted);
      setState(() {
        _isMuted = !_isMuted;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to toggle microphone');
    }
  }

  void _toggleVideo() async {
    if (!widget.isVideo) return;

    try {
      await _engine?.muteLocalVideoStream(!_isVideoEnabled);
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to toggle video');
    }
  }

  void _toggleSpeaker() async {
    try {
      await _engine?.setEnableSpeakerphone(!_isSpeakerEnabled);
      setState(() {
        _isSpeakerEnabled = !_isSpeakerEnabled;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to toggle speaker');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: _errorColor, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _surfaceColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildVideoCallLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _backgroundColor.withOpacity(0.9),
                      _backgroundColor,
                    ],
                  ),
                ),
              ),
            ),

            // Remote video
            if (_remoteUids.isNotEmpty)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUids[0]),
                    connection: RtcConnection(channelId: widget.channelId),
                  ),
                ),
              )
            else
              _buildWaitingForParticipant(),

            // Local video preview
            if (widget.isVideo && _isVideoEnabled)
              Positioned(
                top: 60,
                right: 20,
                width: 120,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primaryColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: VideoCanvas(uid: 0),
                        useAndroidSurfaceView: true,
                      ),
                    ),
                  ),
                ),
              ),

            // Header with call info
            _buildCallHeader(),

            // Control buttons
            _buildControlButtons(),

            // Connection status
            _buildConnectionStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForParticipant() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/call_waiting.json', // Add a waiting animation
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 24),
          Text(
            'Waiting for participant...',
            style: TextStyle(
              color: _onSurfaceColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this call ID: ${widget.channelId}',
            style: TextStyle(
              color: _onSurfaceColor.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHeader() {
    return Positioned(
      top: 60,
      left: 20,
      right: widget.isVideo ? 150 : 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _surfaceColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _isEngineReady ? _successColor : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isVideo ? 'Video Call' : 'Voice Call',
                    style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _remoteUids.isNotEmpty ? 'Connected' : 'Connecting...',
                    style: TextStyle(
                      color: _onSurfaceColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (_remoteUids.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person, color: _primaryColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_remoteUids.length}',
                    style: TextStyle(color: _onSurfaceColor, fontSize: 14),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Call duration and status
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _remoteUids.isNotEmpty
                  ? 'Connected • Live'
                  : 'Waiting to connect',
              style: TextStyle(
                color: _onSurfaceColor.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),

          // Control buttons row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _surfaceColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Microphone button
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: _isMuted ? 'Unmute' : 'Mute',
                  backgroundColor: _isMuted ? _errorColor : _surfaceColor,
                  onTap: _toggleMute,
                ),

                // Video button (only for video calls)
                if (widget.isVideo)
                  _buildControlButton(
                    icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    label: _isVideoEnabled ? 'Video Off' : 'Video On',
                    backgroundColor: _isVideoEnabled
                        ? _surfaceColor
                        : _errorColor,
                    onTap: _toggleVideo,
                  ),

                // Speaker button
                _buildControlButton(
                  icon: _isSpeakerEnabled ? Icons.volume_up : Icons.volume_off,
                  label: _isSpeakerEnabled ? 'Speaker' : 'Earpiece',
                  backgroundColor: _isSpeakerEnabled
                      ? _primaryColor
                      : _surfaceColor,
                  onTap: _toggleSpeaker,
                ),

                // End call button
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'End',
                  backgroundColor: _errorColor,
                  onTap: _endCall,
                  isEndCall: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool isEndCall = false,
  }) {
    return Column(
      children: [
        Container(
          width: isEndCall ? 60 : 50,
          height: isEndCall ? 60 : 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: isEndCall ? 24 : 20),
            onPressed: onTap,
          ),
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
    );
  }

  Widget _buildConnectionStatus() {
    return Positioned(
      top: 130,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _isEngineReady ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.orange.withOpacity(0.8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_onSurfaceColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Establishing connection...',
                style: TextStyle(color: _onSurfaceColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isEngineReady ? _buildVideoCallLayout() : _buildLoadingState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_backgroundColor.withOpacity(0.9), _backgroundColor],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/loading_animation.json',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing ${widget.isVideo ? 'Video' : 'Voice'} Call...',
              style: TextStyle(
                color: _onSurfaceColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait a moment',
              style: TextStyle(
                color: _onSurfaceColor.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
