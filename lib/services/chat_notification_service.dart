import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class ChatNotificationService {
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  // Send notification when a new message is sent
  Future<void> sendNewMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String messageType,
  }) async {
    try {
      // Get receiver's user data to check if they want notifications
      final receiverDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();
      if (!receiverDoc.exists) return;

      final receiverData = receiverDoc.data();
      // Check if user has notifications enabled (default to true if not set)
      final notificationsEnabled =
          receiverData?['notificationsEnabled'] ?? true;

      if (!notificationsEnabled) {
        print('Notifications disabled for user: $receiverId');
        return;
      }

      String title = '$senderName sent you a message';
      String body = '';

      // Customize notification based on message type
      switch (messageType) {
        case 'text':
          body = message.length > 50
              ? '${message.substring(0, 50)}...'
              : message;
          break;
        case 'image_base64':
          title = '$senderName sent you a photo';
          body = 'Tap to view photo';
          break;
        case 'voice_base64':
          title = '$senderName sent you a voice message';
          body = 'Tap to listen';
          break;
        case 'system':
          title = 'Call notification';
          body = message;
          break;
        default:
          body = 'New message received';
      }

      // Send notification
      await _notificationService.sendNotificationToUser(
        userId: receiverId,
        title: title,
        body: body,
        data: {
          'type': 'new_message',
          'senderId': _auth.currentUser?.uid ?? '',
          'receiverId': receiverId,
          'messageType': messageType,
        },
      );
    } catch (e) {
      print('Error sending message notification: $e');
    }
  }

  // Send notification for incoming calls
  Future<void> sendIncomingCallNotification({
    required String receiverId,
    required String callerName,
    required String callType, // 'voice' or 'video'
  }) async {
    try {
      // Get receiver's user data to check if they want notifications
      final receiverDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();
      if (!receiverDoc.exists) return;

      final receiverData = receiverDoc.data();
      // Check if user has call notifications enabled (default to true if not set)
      final callNotificationsEnabled =
          receiverData?['callNotificationsEnabled'] ?? true;

      if (!callNotificationsEnabled) {
        print('Call notifications disabled for user: $receiverId');
        return;
      }

      final title = 'Incoming ${callType} call';
      final body = '$callerName is calling you';

      // Send notification
      await _notificationService.sendNotificationToUser(
        userId: receiverId,
        title: title,
        body: body,
        data: {
          'type': 'incoming_call',
          'callerId': _auth.currentUser?.uid ?? '',
          'receiverId': receiverId,
          'callType': callType,
        },
      );
    } catch (e) {
      print('Error sending call notification: $e');
    }
  }

  // Update user notification preferences
  Future<void> updateUserNotificationPreferences({
    required String userId,
    bool? notificationsEnabled,
    bool? callNotificationsEnabled,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (notificationsEnabled != null) {
        updateData['notificationsEnabled'] = notificationsEnabled;
      }

      if (callNotificationsEnabled != null) {
        updateData['callNotificationsEnabled'] = callNotificationsEnabled;
      }

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updateData);
        print('User notification preferences updated');
      }
    } catch (e) {
      print('Error updating user notification preferences: $e');
    }
  }
}
