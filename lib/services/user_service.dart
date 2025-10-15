import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ensure user document exists
  Future<void> ensureUserDocumentExists(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await createUserDocument(user);
      }
    } catch (e) {
      print("Error ensuring user document exists: $e");
    }
  }

  // Create user document
  Future<void> createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? 'User',
        'profileImage': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error creating user document: $e");
    }
  }

  // Update user login time
  Future<void> updateUserLoginTime(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating login time: $e");
      // If document doesn't exist, create it
      if (e.toString().contains('not-found')) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid == userId) {
          await createUserDocument(user);
        }
      }
    }
  }

  // Get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
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

  // Get all users except current user
  Stream<QuerySnapshot> getUsersStream() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return _firestore
        .collection("users")
        .where("uid", isNotEqualTo: currentUserId)
        .snapshots();
  }
}
