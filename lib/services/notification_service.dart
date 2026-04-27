import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

 
  static Future<void> initNotifications() async {
 
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions');
      
     
      String? token = await _messaging.getToken();
      debugPrint("📱 FCM Token: $token");

    
      await _messaging.subscribeToTopic('all_campus');
    }
  }

  static Future<void> send({
    required String title,
    required String body,
    required List<String> topics,
    String category = "General",
    String senderName = "System",
  }) async {
    try {
      
      await _db.collection('notifications').add({
        'title': title,
        'body': body,
        'topics': topics, 
        'category': category,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint("Notification logged in Firestore for topics: $topics");
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint("Subscribed to $topic");
  }
}