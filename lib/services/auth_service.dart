import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Updated Sign In: Returns the Firestore User Data Map
  /// This allows the LoginScreen to access role, year, and division immediately.
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    try {
      // 1. Authenticate with Firebase Auth
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;

      if (user != null) {
        // 2. Fetch user details from Firestore
        // Note: If you use email as the Doc ID, keep this. 
        // If you use UID as Doc ID, change to: _db.collection('users').doc(user.uid).get()
        DocumentSnapshot doc = await _db.collection('users').doc(email).get();
        
        if (doc.exists) {
          return doc.data() as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  /// Helper to get a specific user's role (Static check)
  Future<String> getUserRole(String email) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(email).get();
      if (doc.exists) {
        return doc['role'] ?? 'Student';
      }
    } catch (e) {
      print("Error fetching role: $e");
    }
    return 'Student';
  }

  /// Sign Out
  Future<void> signOut() async => await _auth.signOut();
}