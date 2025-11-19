import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'encryption_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EncryptionService _encryption = EncryptionService();

  // 🔹 Get current user ID
  String getCurrentUserId() {
    final userId = _auth.currentUser?.uid ?? '';
    print("[ChatService] Current user ID: $userId");
    return userId;
  }

  // 🔹 Get all users except the current user
  Stream<QuerySnapshot> getUsersStream() {
    print(
      "[ChatService] Subscribing to users stream (excluding current user)...",
    );
    final currentUserId = _auth.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      // Return an empty stream if not authenticated
      return const Stream.empty();
    }
    return _firestore
        .collection("users")
        .where("uid", isNotEqualTo: currentUserId)
        .snapshots();
  }

  // 🔹 Get messages between the current user and selected user
  Stream<QuerySnapshot> getMessagesStream(String otherUserId) {
    final currentUserId = getCurrentUserId();
    final chatId = _getChatId(currentUserId, otherUserId);
    print("[ChatService] Listening to message stream for chat: $chatId");

    return _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  // 🔹 Send a text message
  Future<void> sendTextMessage(String receiverId, String message) async {
    print("[ChatService] Sending text message to $receiverId: $message");
    try {
      final encryptedMessage = _encryption.encrypt(message);
      final currentUserId = getCurrentUserId();
      final chatId = _getChatId(currentUserId, receiverId);
      final timestamp = Timestamp.now();

      await _firestore.collection("chats").doc(chatId).set({
        "participants": [currentUserId, receiverId],
        "chatId": chatId,
        "lastMessage": message,
        "lastMessageTime": timestamp,
        "lastMessageSender": currentUserId,
      }, SetOptions(merge: true));

      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "receiverId": receiverId,
            "message": encryptedMessage,
            "type": "text",
            "timestamp": timestamp,
            "isRead": false,
          });

      print("[ChatService] Message successfully sent!");
    } catch (e) {
      print("[ChatService][Error] Failed to send message: $e");
      rethrow;
    }
  }

  // 🔹 Send an image message (Base64 encoded)
  Future<void> sendImageMessage(String receiverId, File imageFile) async {
    print("[ChatService] Sending image to $receiverId...");
    try {
      final currentUserId = getCurrentUserId();
      final chatId = _getChatId(currentUserId, receiverId);
      final timestamp = Timestamp.now();

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      print(
        "[ChatService] Image converted to Base64 string (length: ${base64Image.length})",
      );

      await _firestore.collection("chats").doc(chatId).set({
        "participants": [currentUserId, receiverId],
        "chatId": chatId,
        "lastMessage": "[Image]",
        "lastMessageTime": timestamp,
        "lastMessageSender": currentUserId,
      }, SetOptions(merge: true));

      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "receiverId": receiverId,
            "message": base64Image,
            "type": "image_base64",
            "timestamp": timestamp,
            "isRead": false,
          });

      print("[ChatService] Image message sent successfully!");
    } catch (e) {
      print("[ChatService][Error] Failed to send image: $e");
      rethrow;
    }
  }

  // 🔹 NEW: Send a voice message (Base64 encoded)
  Future<void> sendVoiceMessage(
    String receiverId,
    File audioFile,
    double durationSeconds,
  ) async {
    print("[ChatService] Sending voice message to $receiverId...");
    try {
      final currentUserId = getCurrentUserId();
      final chatId = _getChatId(currentUserId, receiverId);
      final timestamp = Timestamp.now();

      // ✅ Read audio bytes
      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);
      print(
        "[ChatService] Audio file converted to Base64 (length: ${base64Audio.length})",
      );

      // ✅ Ensure chat exists
      await _firestore.collection("chats").doc(chatId).set({
        "participants": [currentUserId, receiverId],
        "chatId": chatId,
        "lastMessage": "[Voice Message]",
        "lastMessageTime": timestamp,
        "lastMessageSender": currentUserId,
      }, SetOptions(merge: true));

      // ✅ Add voice message to Firestore
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "receiverId": receiverId,
            "message": base64Audio,
            "type": "voice_base64",
            "duration": durationSeconds,
            "timestamp": timestamp,
            "isRead": false,
          });

      print(
        "[ChatService] Voice message sent successfully! Duration: ${durationSeconds.toStringAsFixed(2)}s",
      );
    } catch (e) {
      print("[ChatService][Error] Failed to send voice message: $e");
      rethrow;
    }
  }

  // 🔹 Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String senderId) async {
    print(
      "[ChatService] Marking messages as read in chat: $chatId from sender: $senderId",
    );
    try {
      final currentUserId = getCurrentUserId();

      final unreadMessages = await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .where("senderId", isEqualTo: senderId)
          .where("receiverId", isEqualTo: currentUserId)
          .where("isRead", isEqualTo: false)
          .get();

      print(
        "[ChatService] Found ${unreadMessages.docs.length} unread messages.",
      );

      for (final doc in unreadMessages.docs) {
        await doc.reference.update({"isRead": true});
      }

      print("[ChatService] All unread messages marked as read.");
    } catch (e) {
      print("[ChatService][Error] Failed to mark messages as read: $e");
    }
  }

  // 🔹 Get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    print("[ChatService] Fetching user data for: $userId");
    try {
      final userDoc = await _firestore.collection("users").doc(userId).get();

      if (userDoc.exists) {
        print("[ChatService] User data retrieved successfully.");
        return userDoc.data() as Map<String, dynamic>;
      } else {
        print("[ChatService] No user found with ID: $userId");
        return null;
      }
    } catch (e) {
      print("[ChatService][Error] Failed to get user data: $e");
      return null;
    }
  }

  // 🔹 Update user profile
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    print(
      "[ChatService] Updating user profile for: $userId with data: $updates",
    );
    try {
      await _firestore.collection("users").doc(userId).update(updates);
      print("[ChatService] Profile updated successfully!");
    } catch (e) {
      print("[ChatService][Error] Failed to update profile: $e");
      throw "Failed to update profile";
    }
  }

  // 🔹 Generate unique chat ID from two user IDs
  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    final chatId = ids.join('_');
    print("[ChatService] Generated chat ID: $chatId");
    return chatId;
  }

  // 🔹 Public chat ID getter (for UI or logic)
  String getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    final chatId = ids.join('_');
    print("[ChatService] getChatId() returned: $chatId");
    return chatId;
  }

  // 🔹 Stub for unused function
  void getMessages(String s) {
    print("[ChatService] getMessages($s) called (no implementation).");
  }

  // 🔹 Delete chat (and all its messages)
  Future<void> deleteChat(String otherUserId) async {
    print("[ChatService] Deleting chat with user: $otherUserId");
    try {
      final currentUserId = getCurrentUserId();
      final chatId = getChatId(currentUserId, otherUserId);

      final messagesRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages');
      final batch = _firestore.batch();

      final snapshot = await messagesRef.get();
      print("[ChatService] Found ${snapshot.docs.length} messages to delete.");

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
        "[ChatService] Chat $chatId and all messages deleted successfully.",
      );
    } catch (e) {
      print("[ChatService][Error] Failed to delete chat: $e");
      rethrow;
    }
  }
}
