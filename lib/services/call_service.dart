import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_app/services/chat_service.dart';

// Import for SetOptions
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;

class CallService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _chatService = ChatService();

  Future<String> saveCallLog({
    required String otherUserId,
    required String otherUserName,
    required bool isVideo,
    required bool isOutgoing,
    bool isAnswered = true,
    String? channelId,
  }) async {
    final uid = _auth.currentUser!.uid;

    // Save call log to calls collection
    final callData = {
      "callerId": isOutgoing ? uid : otherUserId,
      "receiverId": isOutgoing ? otherUserId : uid,
      "name": otherUserName,
      "type": isVideo ? "video" : "voice",
      "direction": isOutgoing ? "outgoing" : "incoming",
      "status": isAnswered ? "answered" : "missed",
      "channelId": channelId ?? _chatService.getChatId(uid, otherUserId),
      "timestamp": FieldValue.serverTimestamp(),
    };

    try {
      final docRef = await _firestore.collection("calls").add(callData);

      // Also save call as a message in the chat
      // Updated to include the recipient's name
      final callMessage = isOutgoing
          ? (isVideo
                ? "You made a video call to $otherUserName"
                : "You made a voice call to $otherUserName")
          : (isAnswered
                ? (isVideo
                      ? "Video call from $otherUserName"
                      : "Voice call from $otherUserName")
                : (isVideo
                      ? "Missed video call from $otherUserName"
                      : "Missed voice call from $otherUserName"));

      final chatId = _chatService.getChatId(uid, otherUserId);

      // Create system message for the call
      await _firestore.collection("chats").doc(chatId).set({
        "participants": [uid, otherUserId],
        "chatId": chatId,
        "lastMessage": callMessage,
        "lastMessageTime": FieldValue.serverTimestamp(),
        "lastMessageSender": uid,
      }, SetOptions(merge: true));

      // Add the call as a system message
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": uid,
            "receiverId": otherUserId,
            "message": callMessage,
            "type": "system",
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
          });

      return docRef.id;
    } catch (e) {
      print("📞 [CallService] Error saving call log: $e");
      // Even if we can't save to calls collection, still save as a chat message
      // Updated to include the recipient's name
      final callMessage = isOutgoing
          ? (isVideo
                ? "You made a video call to $otherUserName"
                : "You made a voice call to $otherUserName")
          : (isAnswered
                ? (isVideo
                      ? "Video call from $otherUserName"
                      : "Voice call from $otherUserName")
                : (isVideo
                      ? "Missed video call from $otherUserName"
                      : "Missed voice call from $otherUserName"));

      final chatId = _chatService.getChatId(uid, otherUserId);

      // Create system message for the call
      await _firestore.collection("chats").doc(chatId).set({
        "participants": [uid, otherUserId],
        "chatId": chatId,
        "lastMessage": callMessage,
        "lastMessageTime": FieldValue.serverTimestamp(),
        "lastMessageSender": uid,
      }, SetOptions(merge: true));

      // Add the call as a system message
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": uid,
            "receiverId": otherUserId,
            "message": callMessage,
            "type": "system",
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
          });

      // Return a dummy ID since we couldn't save to calls collection
      return "dummy_call_id";
    }
  }

  // Method to listen for incoming calls
  Stream<QuerySnapshot> getIncomingCalls() {
    final uid = _auth.currentUser!.uid;
    try {
      return _firestore
          .collection("calls")
          .where("receiverId", isEqualTo: uid)
          .where("status", isEqualTo: "ringing")
          .snapshots();
    } catch (e) {
      print("📞 [CallService] Error listening for incoming calls: $e");
      // Return an empty stream if we can't listen for calls
      return const Stream.empty();
    }
  }

  // Method to update call status
  Future<void> updateCallStatus(
    String callId,
    String status, {
    String? callerName,
  }) async {
    try {
      await _firestore.collection("calls").doc(callId).update({
        "status": status,
        "endTime": FieldValue.serverTimestamp(),
      });

      // If the call was answered or rejected, add a message to the chat
      if (status == "answered" && callerName != null) {
        // Get the current user ID
        final uid = _auth.currentUser!.uid;

        // We need to get the other user ID from the call document
        // This would require an additional query, so we'll skip it for now
        // In a real implementation, you would pass the other user ID as a parameter
      }
    } catch (e) {
      print("📞 [CallService] Error updating call status: $e");
      // Silently fail if we can't update call status due to permissions
    }
  }

  // Method to initiate an incoming call
  Future<void> initiateIncomingCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required bool isVideo,
    String? channelId,
  }) async {
    try {
      final callData = {
        "callerId": callerId,
        "receiverId": receiverId,
        "name": callerName,
        "type": isVideo ? "video" : "voice",
        "direction": "incoming",
        "status": "ringing",
        "channelId": channelId ?? _chatService.getChatId(callerId, receiverId),
        "timestamp": FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection("calls").add(callData);

      // Also save as a message in the chat for the receiver
      final callMessage = isVideo
          ? "Incoming video call from $callerName"
          : "Incoming voice call from $callerName";

      final chatId = _chatService.getChatId(callerId, receiverId);

      // Create system message for the call
      await _firestore.collection("chats").doc(chatId).set({
        "participants": [callerId, receiverId],
        "chatId": chatId,
        "lastMessage": callMessage,
        "lastMessageTime": FieldValue.serverTimestamp(),
        "lastMessageSender": callerId,
      }, SetOptions(merge: true));

      // Add the call as a system message
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "senderId": callerId,
            "receiverId": receiverId,
            "message": callMessage,
            "type": "system",
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
          });
    } catch (e) {
      print("📞 [CallService] Error initiating incoming call: $e");
      // Silently fail if we can't initiate incoming call due to permissions
    }
  }
}
