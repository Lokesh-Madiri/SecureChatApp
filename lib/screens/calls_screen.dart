import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Design colors
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _onSurfaceColor = Colors.white;
  final Color _successColor = const Color(0xFF10B981);
  final Color _errorColor = const Color(0xFFEF4444);

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("Call History"),
        backgroundColor: _primaryColor,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Search bar
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
                  hintText: 'Search calls',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
            ),
          ),

          // Calls list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getCallsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // Check if it's a permission error
                  if (snapshot.error.toString().contains("permission-denied") ||
                      snapshot.error.toString().contains("PERMISSION_DENIED")) {
                    return _buildPermissionErrorState();
                  }

                  return Center(
                    child: Text(
                      "Error loading calls",
                      style: TextStyle(color: _onSurfaceColor),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                final calls = snapshot.data!.docs;

                // Filter calls based on search query
                final filtered = _searchQuery.isEmpty
                    ? calls
                    : calls.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call,
                          size: 64,
                          color: _onSurfaceColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No calls yet",
                          style: TextStyle(
                            color: _onSurfaceColor.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your call history will appear here",
                          style: TextStyle(
                            color: _onSurfaceColor.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final name = data["name"] ?? "Unknown";
                    final type = data["type"] ?? "voice";
                    final direction = data["direction"] ?? "incoming";
                    final status = data["status"] ?? "answered";
                    final timestamp = data["timestamp"] as Timestamp?;
                    final formattedTime = _formatCallTime(timestamp?.toDate());

                    final isVideo = type == "video";
                    final isOutgoing = direction == "outgoing";
                    final isAnswered = status == "answered";

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: _surfaceColor,
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.call,
                          color: isOutgoing ? _successColor : _errorColor,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            isOutgoing
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                            color: isOutgoing ? _successColor : _errorColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVideo ? "Video call" : "Voice call",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                          if (!isAnswered)
                            Text(
                              "Missed",
                              style: TextStyle(
                                color: _errorColor,
                                fontSize: 10,
                              ),
                            ),
                        ],
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

  Widget _buildPermissionErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 64, color: _errorColor),
          const SizedBox(height: 16),
          Text(
            "Permission Required",
            style: TextStyle(
              color: _onSurfaceColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Call history requires additional permissions. Please contact the app administrator.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _onSurfaceColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getCallsStream() {
    final currentUserId = _auth.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      return const Stream.empty();
    }

    try {
      return _firestore
          .collection("calls")
          .where("callerId", isEqualTo: currentUserId)
          .orderBy("timestamp", descending: true)
          .snapshots();
    } catch (e) {
      print("📞 [CallsScreen] Error getting calls stream: $e");
      // Return an empty stream if we can't get calls due to permissions
      return const Stream.empty();
    }
  }

  String _formatCallTime(DateTime? dateTime) {
    if (dateTime == null) return "";

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat('hh:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      // Yesterday
      return "Yesterday";
    } else if (difference.inDays < 7) {
      // Within a week - show day
      return DateFormat('EEEE').format(dateTime);
    } else {
      // Older - show date
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }
}
