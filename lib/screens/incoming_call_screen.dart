import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_app/services/call_service.dart';
import 'package:chat_app/screens/video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String channelId;
  final bool isVideo;
  final String callId; // Add call ID
  final Function onAccept;
  final Function onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.channelId,
    required this.isVideo,
    required this.callId, // Add call ID
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final CallService _callService = CallService();

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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor.withOpacity(0.9),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundColor.withOpacity(0.95), _backgroundColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caller avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.isVideo ? Icons.videocam : Icons.call,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Caller name
                    Text(
                      widget.callerName,
                      style: TextStyle(
                        color: _onSurfaceColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Call type
                    Text(
                      widget.isVideo ? "Video Call" : "Voice Call",
                      style: TextStyle(
                        color: _onSurfaceColor.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Call actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reject button
                        _buildCallActionButton(
                          icon: Icons.call_end,
                          label: "Reject",
                          backgroundColor: _errorColor,
                          onTap: () async {
                            // Update call status to rejected
                            await _callService.updateCallStatus(
                              widget.callId,
                              "rejected",
                              callerName: widget.callerName,
                            );
                            widget.onReject();
                            Navigator.pop(context);
                          },
                        ),

                        // Accept button
                        _buildCallActionButton(
                          icon: Icons.call,
                          label: "Accept",
                          backgroundColor: _successColor,
                          onTap: () async {
                            // Update call status to answered
                            await _callService.updateCallStatus(
                              widget.callId,
                              "answered",
                              callerName: widget.callerName,
                            );
                            widget.onAccept();
                            Navigator.pop(context);

                            // Navigate to video call screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoCallScreen(
                                  channelId: widget.channelId,
                                  isVideo: widget.isVideo,
                                  callId: widget.callId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 28),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: _onSurfaceColor.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
