import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Needed to detect Chrome
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  /// Function to handle FCM Topic Subscriptions
  Future<void> _setupNotificationTopics(Map<String, dynamic> userData) async {
    // FIX: Push notifications setup varies on Web. 
    // This check prevents the crash on Chrome.
    if (kIsWeb) {
      debugPrint("FCM Topic subscription skipped: Running on Web.");
      return;
    }

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Request Permission (Crucial for Android 13+ and iOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Subscribe to Global Campus Alerts
      await messaging.subscribeToTopic('all_campus');

      String role = userData['role'] ?? "Student";

      // 3. Role-Based Subscriptions
      if (role == "Teacher") {
        String officialId = userData['officialId']?.toString() ?? "";
        if (officialId.isNotEmpty) {
          await messaging.subscribeToTopic('Teacher_$officialId');
          debugPrint("Subscribed to Teacher_$officialId");
        }
      } else if (role == "Student") {
        String year = userData['year'] ?? "";
        String div = userData['division'] ?? "";
        if (year.isNotEmpty && div.isNotEmpty) {
          String classTopic = '${year}_Div_$div';
          await messaging.subscribeToTopic(classTopic);
          debugPrint("Subscribed to $classTopic");
        }
      }
    } catch (e) {
      debugPrint("Error setting up notifications: $e");
    }
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);

    // Call the updated AuthService that returns the Firestore Map
    final userData = await AuthService().signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    
    if (userData != null && mounted) {
      // Success: Setup notification topics
      await _setupNotificationTopics(userData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login Successful! Syncing notices..."), 
          backgroundColor: Colors.green
        ),
      );

      // Manual navigation if not using an AuthWrapper
      // Navigator.pushReplacementNamed(context, '/dashboard');

    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Credentials or User Not Found"), 
          backgroundColor: Colors.red
        ),
      );
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 20),
                const Text("VIT Smart Lecture", 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Resource Management System", 
                  style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Official Email", 
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password", 
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 30),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))
                      ),
                      onPressed: _handleLogin,
                      child: const Text("Login to Dashboard", 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}