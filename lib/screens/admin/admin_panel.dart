import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:book_lec_app/widgets/timetable_explorer.dart';
import 'package:book_lec_app/widgets/resource_manager_dialog.dart';
import '../common/notification_inbox.dart'; 
import '../admin/admin_message_composer.dart'; 

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Configuration
  final List<String> _years = ["FY", "SY", "TY", "Btech"];
  final List<String> _divisions = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"];
  final List<String> _allResources = [
    "L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "L9", 
    "R1", "R2", "R3", "R4", "R5", "R6", "R7", "T1", "T2"
  ];

  // Filters & State
  String _selectedYear = "TY";
  String _selectedDiv = "B";
  String _selectedDay = DateFormat('EEEE').format(DateTime.now()); 
  DateTime _selectedDate = DateTime.now();
  String _activeSem = "SEM_6_2026";

  /// --- BULLETPROOF LOGOUT LOGIC ---
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to end your admin session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Logout")
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // 1. Show loading overlay
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
        );
      }

      // 2. Cleanup Push Notifications (Unsubscribe from Admin/Global topics)
      if (!kIsWeb) {
        try {
          await FirebaseMessaging.instance.unsubscribeFromTopic("all_campus");
          await FirebaseMessaging.instance.unsubscribeFromTopic("admin_alerts");
        } catch (fcmErr) {
          debugPrint("FCM Unsubscribe skipped: $fcmErr");
        }
      }
      
      // 3. Clear FirebaseAuth session
      await FirebaseAuth.instance.signOut();

      // 4. Navigate to Login and CLEAR ALL STACKS
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loader
        // Ensure '/login' is defined in your main.dart routes
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      debugPrint("Logout Error: $e");
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Admin Dashboard", 
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(_activeSem.replaceAll("_", " "), 
              style: const TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Global Announcement",
            icon: const Icon(Icons.campaign_outlined, color: Colors.orange, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminMessageComposer())),
          ),
          IconButton(
            tooltip: "Manage Resources",
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.indigo, size: 24), 
            onPressed: () => showDialog(context: context, builder: (ctx) => ResourceManagerDialog(allResources: _allResources)),
          ),
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent), 
            onPressed: _handleLogout, 
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TimetableExplorer.showEditDialog(
          context, null, _selectedYear, _selectedDiv, _selectedDay, "09:00", _activeSem, _selectedDate
        ),
        label: const Text("Manual Override"),
        icon: const Icon(Icons.add_moderator),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}), 
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateSelector(),
              const SizedBox(height: 25),
              _sectionTitle("Timetable Explorer", "Viewing schedule for $_selectedYear - Div $_selectedDiv"),
              _buildGlobalFilters(),
              const SizedBox(height: 15),
              // Main Schedule Component
              TimetableExplorer(
                selectedYear: _selectedYear,
                selectedDiv: _selectedDiv,
                selectedDay: _selectedDay,
                activeSem: _activeSem,
                selectedDate: _selectedDate,
              ),
              const SizedBox(height: 100), 
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context, 
          initialDate: _selectedDate, 
          firstDate: DateTime.now().subtract(const Duration(days: 30)), 
          lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.indigo)),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
            _selectedDay = DateFormat('EEEE').format(picked);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: Colors.indigo.withOpacity(0.1))
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, color: Colors.indigo, size: 20),
          const SizedBox(width: 12),
          Text(DateFormat('EEEE, dd MMM yyyy').format(_selectedDate), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const Spacer(),
          const Icon(Icons.expand_more, size: 20, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildGlobalFilters() => Row(children: [
    Expanded(child: _drop("Year", _selectedYear, _years, (v) => setState(() => _selectedYear = v!))),
    const SizedBox(width: 12),
    Expanded(child: _drop("Division", _selectedDiv, _divisions, (v) => setState(() => _selectedDiv = v!))),
  ]);

  Widget _sectionTitle(String t, String s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
    Text(s, style: const TextStyle(fontSize: 13, color: Colors.grey)),
    const SizedBox(height: 12),
  ]);

  Widget _drop(String l, String v, List<String> i, Function(String?) o) {
    return DropdownButtonFormField<String>(
      value: v, 
      items: i.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(), 
      onChanged: o,
      decoration: InputDecoration(
        labelText: l, 
        labelStyle: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w500),
        filled: true, 
        fillColor: Colors.grey.shade50, 
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }
}