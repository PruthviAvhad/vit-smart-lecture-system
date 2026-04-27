import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


import './services/notification_service.dart'; 
import './screens/auth/login_screen.dart'; 
import './screens/auth/auth_wrapper.dart'; 
import './secrets.dart'; 


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: AppSecrets.apiKey,
        authDomain: AppSecrets.authDomain,
        projectId: AppSecrets.projectId,
        storageBucket: AppSecrets.storageBucket,
        messagingSenderId: AppSecrets.messagingSenderId,
        appId: AppSecrets.appId,
      ),
    );
  }
  debugPrint("📩 Background Message Received: ${message.notification?.title}");
}

void main() async {
 
  WidgetsFlutterBinding.ensureInitialized();
  

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: AppSecrets.apiKey,
      authDomain: AppSecrets.authDomain,
      projectId: AppSecrets.projectId,
      storageBucket: AppSecrets.storageBucket,
      messagingSenderId: AppSecrets.messagingSenderId,
      appId: AppSecrets.appId,
    ),
  );

 
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initNotifications();


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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo[800],
          secondary: Colors.indigoAccent,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        
    
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

      
        cardTheme: CardThemeData(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),

     
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade100),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade100),
          ),
        ),
      ),


      home: const AuthWrapper(), 
      
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const AuthWrapper(), 
      },
    );
  }
}