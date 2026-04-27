import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

 
  Future<bool> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      
      if (result.user != null) {
     
        DocumentSnapshot doc = await _db.collection('users').doc(email.trim()).get();
        if (doc.exists) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          await _handleNotificationSubscriptions(userData);
          return true; 
        }
      }
      return false;
    } catch (e) {
      debugPrint("Login Error: $e");
      return false;
    }
  }

 
  Future<void> _handleNotificationSubscriptions(Map<String, dynamic> data) async {
    try {
      String role = data['role'] ?? 'student';
     
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

  
  Future<void> signOut() async {
    try {
      
      await _fcm.deleteToken(); 
      await _auth.signOut();
    } catch (e) {
      debugPrint("Logout Error: $e");
      await _auth.signOut();
    }
  }
}