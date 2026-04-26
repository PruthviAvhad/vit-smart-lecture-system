import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Updated Sign In
  Future<bool> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      
      if (result.user != null) {
        // Fetch data to handle subscriptions immediately
        DocumentSnapshot doc = await _db.collection('users').doc(email.trim()).get();
        if (doc.exists) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          await _handleNotificationSubscriptions(userData);
          return true; // Success
        }
      }
      return false;
    } catch (e) {
      debugPrint("Login Error: $e");
      return false;
    }
  }

  /// Private helper for topic subscriptions
  Future<void> _handleNotificationSubscriptions(Map<String, dynamic> data) async {
    try {
      String role = data['role'] ?? 'student';
      // Always subscribe everyone to all_campus
      await _fcm.subscribeToTopic("all_campus");

      if (role.toLowerCase() == 'teacher') {
        String officialId = data['officialId']?.toString() ?? "";
        if (officialId.isNotEmpty) {
          await _fcm.subscribeToTopic("Teacher_$officialId");
        }
      } 
      else if (role.toLowerCase() == 'student') {
        String year = data['year'] ?? "";
        String div = data['division'] ?? "";
        if (year.isNotEmpty && div.isNotEmpty) {
          // Matching your Firebase naming convention
          await _fcm.subscribeToTopic("${year}_Div_$div");
        }
      }
    } catch (e) {
      debugPrint("Subscription Error: $e");
    }
  }

  Future<String> getUserRole(String email) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(email.trim()).get();
      if (doc.exists) {
        return doc['role']?.toString().toLowerCase() ?? 'student';
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
    return 'student';
  }

  /// IMPROVED SIGN OUT: Clears tokens/subscriptions to prevent mixed notifications
  Future<void> signOut() async {
    try {
      // Best practice: Delete the FCM token so the next user gets a fresh start
      await _fcm.deleteToken(); 
      await _auth.signOut();
    } catch (e) {
      debugPrint("Logout Error: $e");
      await _auth.signOut(); // Ensure signout happens even if FCM fails
    }
  }
}