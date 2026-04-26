import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../student/student_dashboard.dart';
import '../admin/admin_panel.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  /// Fetches the user role from the 'users' collection using the email as the Doc ID.
  Future<String> _getUserRole(String email) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      
      if (doc.exists && doc.data() != null) {
        // Normalizes role string to handle database inconsistencies
        return (doc.get('role') as String).toLowerCase().trim();
      }
      return 'not_found'; 
    } catch (e) {
      debugPrint("Firestore Role Fetch Error: $e");
      return 'error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Listen to the Firebase Auth state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // Handle initialization state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        // 2. AUTH CHECK: Redirect to Login if no active session
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        final String? userEmail = snapshot.data!.email;

        // Safety check for empty email profiles
        if (userEmail == null) {
          FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        // 3. ROLE FETCH: Determine which Dashboard to show
        return FutureBuilder<String>(
          key: ValueKey(snapshot.data!.uid), 
          future: _getUserRole(userEmail),
          builder: (context, roleSnapshot) {
            
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return _loadingScreen();
            }

            // Handle Firestore fetch errors or missing user docs
            if (roleSnapshot.hasError || 
                roleSnapshot.data == 'error' || 
                roleSnapshot.data == 'not_found') {
              return _errorScreen(context, "Account access error. Please contact Admin.");
            }

            final String role = roleSnapshot.data!;

            // 4. NAVIGATION LOGIC
            switch (role) {
              case 'admin':
                return const AdminPanel();
              case 'teacher':
                return const TeacherDashboard();
              case 'student':
                return const StudentDashboard();
              default:
                return const StudentDashboard();
            }
          },
        );
      },
    );
  }

  Widget _loadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.indigo,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _errorScreen(BuildContext context, String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                message, 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text("Return to Login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}