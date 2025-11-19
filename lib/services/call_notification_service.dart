import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send call notification to another user
  Future<void> sendCallNotification({
    required String targetUserId,
    required String callerName,
    required bool isVideo,
    required String channelId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final notificationData = {
      'callerId': currentUserId,
      'callerName': callerName,
      'targetUserId': targetUserId,
      'isVideo': isVideo,
      'channelId': channelId,
      'type': 'call',
      'status': 'ringing', // ringing, answered, missed, ended
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': FieldValue.serverTimestamp(),
    };

    // Add notification to target user's notifications collection
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add(notificationData);
  }

  // Update call notification status (answered, missed, etc.)
  Future<void> updateCallNotificationStatus({
    required String notificationId,
    required String targetUserId,
    required String status, // answered, missed, ended
  }) async {
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .doc(notificationId)
        .update({'status': status, 'answeredAt': FieldValue.serverTimestamp()});
  }

  // Get incoming call notifications for current user
  Stream<QuerySnapshot> getIncomingCallNotifications() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('notifications')
        .where('targetUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markNotificationAsRead({
    required String notificationId,
    required String targetUserId,
  }) async {
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .doc(notificationId)
        .update({'status': 'read'});
  }
}
