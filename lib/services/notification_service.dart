import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart'; // Import the vault to keep keys private

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Pulling the Master Service Account JSON from your hidden secrets.dart
  static const _serviceAccountJson = AppSecrets.serviceAccount;

  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  /// --- THE SECURE SEND METHOD ---
  static Future<void> send({
    required String title,
    required String body,
    required String topic,
    required String senderRole,
  }) async {
    try {
      // 1. Save to Firestore (For the in-app "Bell Icon" inbox)
      await _db.collection('notifications').add({
        'title': title,
        'body': body,
        'topic': topic,
        'senderRole': senderRole,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Trigger FCM Push Notification using OAuth2
      await _sendFCMNative(title, body, topic);

      print("Notification successfully logged and pushed to $topic");
    } catch (e) {
      print("Error in NotificationService.send: $e");
    }
  }

  /// Internal logic to handle the OAuth2 handshake and HTTP POST to FCM
  static Future<void> _sendFCMNative(String title, String body, String topic) async {
    try {
      // Authenticate using the Service Account from secrets.dart
      final client = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson(_serviceAccountJson),
        _scopes,
      );

      final String projectId = _serviceAccountJson['project_id'];
      final String fcmUrl = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final response = await client.post(
        Uri.parse(fcmUrl),
        body: jsonEncode({
          'message': {
            'topic': topic,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'status': 'done',
            },
          },
        }),
      );

      client.close();
      if (response.statusCode != 200) {
        print("FCM Push Failed: ${response.body}");
      }
    } catch (e) {
      print("OAuth2/FCM Error: $e");
    }
  }

  /// Automated Lecture Status Alerts
  static Future<void> sendLectureUpdate({
    required String status,
    required String subject,
    required String time,
    required String room,
    required String year,
    required String div,
  }) async {
    String topic = "${year}_Div_$div";
    String title = "";
    String body = "";

    if (status == 'New') {
      title = "✨ Extra Lecture Added";
      body = "$subject is scheduled at $time in $room.";
    } else if (status == 'Rescheduled') {
      title = "🕒 Lecture Rescheduled";
      body = "$subject has been moved to $time (Room: $room).";
    } else if (status == 'Cancelled') {
      title = "❌ Lecture Cancelled";
      body = "The $subject lecture at $time has been cancelled.";
    }

    await send(
      title: title,
      body: body,
      topic: topic,
      senderRole: "Department Admin",
    );
  }
}