import 'package:flutter/material.dart';
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

  void _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please fill in all fields", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await AuthService().signIn(email, password);
      
      if (userData != null) {
        if (mounted) {
          _showSnack("Login Successful!", Colors.green);
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        if (mounted) {
          _showSnack("Invalid Credentials or User Not Found", Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Login Error: Please check your connection", Colors.red);
      }
      debugPrint("Login error detail: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, size: 100, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  "VIT Smart Lecture", 
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -1),
                ),
                const Text(
                  "Resource Management System", 
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 48),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: "Official Email", 
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: "Password", 
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _isLoading 
                  ? const CircularProgressIndicator(color: Colors.indigo)
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 58),
                        backgroundColor: Colors.indigo[900],
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.indigo.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _handleLogin,
                      child: const Text(
                        "Login to Dashboard",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                  },
                  child: const Text("Forgot Password?", style: TextStyle(color: Colors.indigo)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}