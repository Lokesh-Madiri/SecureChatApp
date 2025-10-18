import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'encryption_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EncryptionService _encryption = EncryptionService();

  // Get current user ID
  String getCurrentUserId() {
    return _auth.currentUser?.uid ?? '';
  }

  // Get all users except current user
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore
        .collection("users")
        .where("uid", isNotEqualTo: _auth.currentUser?.uid)
        .snapshots();
  }

  // Get messages between current user and selected user
  Stream<QuerySnapshot> getMessagesStream(String otherUserId) {
    String currentUserId = getCurrentUserId();
    String chatId = _getChatId(currentUserId, otherUserId);

    return _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  // Send text message
  Future<void> sendTextMessage(String receiverId, String message) async {
    try {
      String encryptedMessage = _encryption.encrypt(message);

      String currentUserId = getCurrentUserId();
      String chatId = _getChatId(currentUserId, receiverId);
      Timestamp timestamp = Timestamp.now();

      // Create chat document if it doesn't exist
      await _firestore.collection("chats").doc(chatId).set({
        "participants": [currentUserId, receiverId],
        "chatId": chatId,
        "lastMessage": message, // Store unencrypted for preview
        "lastMessageTime": timestamp,
        "lastMessageSender": currentUserId,
      }, SetOptions(merge: true));

      // Add message to chat collection
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
    } catch (e) {
      print("Error sending message: $e");
      rethrow;
    }
  }

  // Send image message
  Future<void> sendImageMessage(String receiverId, File imageFile) async {
    try {
      String currentUserId = getCurrentUserId();
      String chatId = _getChatId(currentUserId, receiverId);
      Timestamp timestamp = Timestamp.now();

      // Upload image to Firebase Storage
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance
          .ref()
          .child("chat_images")
          .child(chatId)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String imageUrl = await snapshot.ref.getDownloadURL();

      // Create chat document if it doesn't exist
      await _firestore.collection("chats").doc(chatId).set({
        "participants": [currentUserId, receiverId],
        "chatId": chatId,
        "lastMessage": "[Image]",
        "lastMessageTime": timestamp,
        "lastMessageSender": currentUserId,
      }, SetOptions(merge: true));

      // Add message to chat collection
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "receiverId": receiverId,
            "message": imageUrl,
            "type": "image",
            "timestamp": timestamp,
            "isRead": false,
          });
    } catch (e) {
      print("Error sending image: $e");
      rethrow;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String senderId) async {
    String currentUserId = getCurrentUserId();

    QuerySnapshot unreadMessages = await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .where("senderId", isEqualTo: senderId)
        .where("receiverId", isEqualTo: currentUserId)
        .where("isRead", isEqualTo: false)
        .get();

    for (var doc in unreadMessages.docs) {
      await doc.reference.update({"isRead": true});
    }
  }

  // Get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection("users")
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error getting user data: $e");
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection("users").doc(userId).update(updates);
    } catch (e) {
      print("Error updating user profile: $e");
      throw "Failed to update profile";
    }
  }

  // Get chat ID from two user IDs
  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Add this in ChatService
  String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  void getMessages(String s) {}
}
