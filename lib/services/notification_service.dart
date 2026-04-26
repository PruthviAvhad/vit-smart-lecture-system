import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Initialize permissions and listeners
  static Future<void> initNotifications() async {
    // 1. Request Permissions (Crucial for iOS/Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 User granted notification permissions');
      
      // 2. Get the token (for testing/individual target if needed)
      String? token = await _messaging.getToken();
      debugPrint("📱 FCM Token: $token");

      // 3. Subscribe to global campus updates by default
      await _messaging.subscribeToTopic('all_campus');
    }
  }

  /// Send a notification and save it to the global 'notifications' collection
  /// This ensures it shows up in the NotificationInbox UI
  static Future<void> send({
    required String title,
    required String body,
    required List<String> topics,
    String category = "General",
    String senderName = "System",
  }) async {
    try {
      // We save the notification to Firestore. 
      // A Cloud Function usually triggers the actual FCM push based on this entry.
      await _db.collection('notifications').add({
        'title': title,
        'body': body,
        'topics': topics, // Array of target topics
        'category': category,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint("✅ Notification logged in Firestore for topics: $topics");
    } catch (e) {
      debugPrint("❌ Error sending notification: $e");
    }
  }

  /// Subscribe user to a specific topic (e.g., their Division)
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint("📌 Subscribed to $topic");
  }
}