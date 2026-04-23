import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/login_screen.dart'; 
import 'screens/auth/auth_wrapper.dart'; 
import 'secrets.dart'; // Import your secret vault

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // These values are now pulled from secrets.dart which is hidden from GitHub
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: AppSecrets.apiKey,
      authDomain: AppSecrets.authDomain,
      projectId: AppSecrets.projectId,
      storageBucket: AppSecrets.storageBucket,
      messagingSenderId: AppSecrets.messagingSenderId,
      appId: AppSecrets.appId,
    ),
  );
  runApp(const VITSmartApp());
}

class VITSmartApp extends StatelessWidget {
  const VITSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VIT Smart Lecture System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AuthWrapper(), 
    );
  }
}