import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelId;
  final bool isVideo;

  const VideoCallScreen({
    super.key,
    required this.channelId,
    required this.isVideo,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // static const String appId = '0d5f2c113e1646969858c59f77451210';
  final String appId = dotenv.env['AGORA_APP_ID'] ?? '';

  RtcEngine? _engine;
  final List<int> _remoteUids = [];
  bool _isEngineReady = false;
  late int _localUid;

  @override
  void initState() {
    super.initState();
      if (appId.isEmpty) {
        throw Exception('AGORA_APP_ID not found in .env');
      }

    _initAgora();
  }

  Future<void> _initAgora() async {
    print('[Agora] === INIT START ===');

    // Requesting permissions
    print('[Agora] Requesting microphone and camera permissions...');
    await [Permission.microphone, Permission.camera].request();

    var micStatus = await Permission.microphone.status;
    var camStatus = await Permission.camera.status;

    print('[Agora] Microphone permission: $micStatus');
    print('[Agora] Camera permission: $camStatus');

    if (!micStatus.isGranted || !camStatus.isGranted) {
      print('[Agora][Error] Microphone or Camera permission not granted.');
      return;
    }

    try {
      print('[Agora] Creating Agora engine...');
      _engine = createAgoraRtcEngine();

      print('[Agora] Initializing engine with App ID...');
      await _engine?.initialize(RtcEngineContext(appId: appId));

      print('[Agora] Engine initialized successfully.');

      if (widget.isVideo) {
        print('[Agora] Enabling video...');
        await _engine?.enableVideo();

        print('[Agora] Starting local video preview...');
        await _engine?.startPreview();
      } else {
        print('[Agora] Disabling video...');
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
        ),
      );

      // Generate local UID`
      _localUid = DateTime.now().millisecondsSinceEpoch % 100000;
      print('[Agora] Generated local UID: $_localUid');

      print('[Agora] Joining channel...');
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
    }

    print('[Agora] === INIT END ===');
  }

  @override
  void dispose() {
    print('[Agora] Disposing Agora engine...');
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  void _endCall() async {
    print('[Agora] Ending call...');
    await _engine?.leaveChannel();
    await _engine?.stopPreview();
    await _engine?.release();
    Navigator.pop(context); // Go back to previous screen
  }

  Widget _videoCallLayout() {
    return Stack(
      children: [
        // Remote video
        _remoteUids.isNotEmpty
            ? AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _remoteUids[0]),
                  connection: RtcConnection(channelId: widget.channelId),
                ),
              )
            : const Center(
                child: Text(
                  'Waiting for participant...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),

        // Local video preview using the stored UID
        Positioned(
          top: 20,
          right: 20,
          width: 120,
          height: 160,
          child: Builder(
            builder: (context) {
              print('[Agora] Rendering local video view with UID: $_localUid');
              return AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: 0),
                  useAndroidSurfaceView: true,
                ),
              );
            },
          ),
        ),

        //End Call Button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: FloatingActionButton(
            onPressed: _endCall,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('[Agora] Building UI: _isEngineReady = $_isEngineReady');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Call'),
        backgroundColor: Colors.black,
      ),
      body: _isEngineReady
          ? _videoCallLayout()
          : Center(
              child: Lottie.asset(
                'assets/loading_animation.json',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}
