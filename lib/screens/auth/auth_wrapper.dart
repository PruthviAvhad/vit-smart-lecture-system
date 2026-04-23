import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../../services/auth_service.dart';
import '../teacher/teacher_dashboard.dart';
import '../student/student_dashboard.dart';
import '../admin/admin_panel.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking if user is logged in
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If NOT logged in -> Show Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // If LOGGED IN -> Check Role and redirect
        return FutureBuilder<String>(
          future: AuthService().getUserRole(snapshot.data!.email!),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnapshot.hasData) {
              final role = roleSnapshot.data;
              if (role == 'admin') return AdminPanel();
              if (role == 'teacher') return TeacherDashboard();
              return StudentDashboard();
            }

            return const LoginScreen(); // Fallback
          },
        );
      },
    );
  }
}