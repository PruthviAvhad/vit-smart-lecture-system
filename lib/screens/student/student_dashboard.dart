import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:book_lec_app/widgets/student_schedule_list.dart';
import '../common/notification_inbox.dart'; 

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTime _selectedDate = DateTime.now();
  bool _isBatchWise = true; 
  String? _currentSubscription; 

  String get _dayName => DateFormat('EEEE').format(_selectedDate);
  String get _dateString => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _manageSubscription(String year, String division) async {
    String newTopic = "${year}_Div_$division";
    if (_currentSubscription == newTopic) return;

    try {
      if (_currentSubscription != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_currentSubscription!);
      }
      await FirebaseMessaging.instance.subscribeToTopic(newTopic);
      await FirebaseMessaging.instance.subscribeToTopic("all_campus");
      
      _currentSubscription = newTopic;
      debugPrint("🔔 Live Sync: Subscribed to $newTopic");
    } catch (e) {
      debugPrint("❌ Subscription Sync Error: $e");
    }
  }

  Future<void> _handleLogout(String year, String division) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Do you want to sign out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
    );

    try {
      String classTopic = "${year}_Div_$division";
      await FirebaseMessaging.instance.unsubscribeFromTopic(classTopic);
      await FirebaseMessaging.instance.unsubscribeFromTopic("all_campus");
      await _auth.signOut();
      
      if (mounted) {
        Navigator.of(context).pop(); 
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      await _auth.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _auth.currentUser?.email;

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(userEmail).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.indigo)));
        }
        
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(body: Center(child: Text("Profile data sync error.")));
        }

        var userData = userSnap.data!.data() as Map<String, dynamic>;
        String year = userData['year']?.toString() ?? "";
        String division = userData['division']?.toString() ?? "";
        String batch = userData['batch']?.toString() ?? "All";
        String classTopic = "${year}_Div_$division";

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _manageSubscription(year, division);
        });

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.indigo[900],
            elevation: 0,
            title: const Text("Student Portal", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationInbox(
                        userTopic: classTopic, 
                        userRole: "Student",
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => _handleLogout(year, division),
              )
            ],
          ),
          body: Column(
            children: [
              _buildHeader(userData),
              _buildDateSelector(),
              _buildViewToggle(), 
              _buildLiveStatusIndicator(),

              Expanded(
                child: StudentScheduleList(
                  year: year,
                  division: division,
                  batch: batch,
                  dayName: _dayName,
                  dateString: _dateString,
                  isBatchWise: _isBatchWise,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveStatusIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text("Live Schedule Sync Active", 
            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: BoxDecoration(
        color: Colors.indigo[900],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30), 
          bottomRight: Radius.circular(30)
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Text(data['name']?[0] ?? "S", 
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hi, ${data['name'] ?? 'Student'}", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("PRN: ${data['prn'] ?? 'N/A'} | Div: ${data['division']} | Batch: ${data['batch']}", 
                    style: TextStyle(color: Colors.indigo[100], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Row(
          children: [
            _toggleItem("My Batch", _isBatchWise, () => setState(() => _isBatchWise = true)),
            _toggleItem("Full Division", !_isBatchWise, () => setState(() => _isBatchWise = false)),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.indigo[900] : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label, 
              style: TextStyle(
                color: isActive ? Colors.white : Colors.indigo[900],
                fontWeight: FontWeight.bold
              )),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: InkWell(
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2025),
            lastDate: DateTime(2027),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(DateFormat('dd MMMM, yyyy').format(_selectedDate), 
                    style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const Icon(Icons.calendar_today_rounded, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}