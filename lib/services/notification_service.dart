import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http; // Added import
import 'dart:convert'; // Added import

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      print('Notification permissions status: ${settings.authorizationStatus}');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // Handle when app is opened from terminated state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print(
          'App opened from terminated state: ${message.notification?.title}',
        );
        _handleNotificationTap(message);
      });

      // Get the token
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Save token to user document
      if (token != null && _auth.currentUser != null) {
        await _saveFcmToken(token);
      }

      // Handle initial message when app is opened from quit state
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        print(
          'App opened from quit state: ${initialMessage.notification?.title}',
        );
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Local notification tapped');
      },
    );
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('Handling background message: ${message.notification?.title}');
    // Handle background notifications here
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
            'chat_channel_id',
            'Chat Notifications',
            channelDescription: 'Notifications for new messages and calls',
            importance: Importance.max,
            priority: Priority.high,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? 'You have a new notification',
        notificationDetails,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to chat screen or handle the notification tap
    print('Notification tapped: ${message.notification?.title}');
    // TODO: Implement navigation to appropriate screen based on notification data
  }

  // Save FCM token to user document
  Future<void> _saveFcmToken(String token) async {
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Send notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // For development, you can use a local server or ngrok
      // For production, replace with your deployed Vercel URL
      final String serverUrl = const String.fromEnvironment(
        'NOTIFICATION_SERVER_URL',
        defaultValue:
            'http://localhost:3000', // Default to local for development
      );

      final response = await http.post(
        Uri.parse('$serverUrl/api/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully via server');
        return;
      } else {
        print('Server returned error: ${response.body}');
        // Fallback to local notification
        await _showLocalNotificationForUser(title, body);
      }
    } catch (e) {
      print('Error sending notification to server: $e');
      // Fallback to local notification
      await _showLocalNotificationForUser(title, body);
    }
  }

  // Show local notification for a user
  Future<void> _showLocalNotificationForUser(String title, String body) async {
    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
            'chat_channel_id',
            'Chat Notifications',
            channelDescription: 'Notifications for new messages and calls',
            importance: Importance.max,
            priority: Priority.high,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }
}
