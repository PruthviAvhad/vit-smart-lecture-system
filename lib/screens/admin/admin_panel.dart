import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:book_lec_app/widgets/timetable_explorer.dart';
import 'package:book_lec_app/widgets/resource_manager_dialog.dart';
import '../common/notification_inbox.dart'; 
// Import the composer file here
import '../admin/admin_message_composer.dart'; 

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Configuration
  final List<String> _years = ["FE", "SE", "SY", "TE", "TY", "BE"];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("Admin Panel", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          // 1. NEW: BROADCAST ICON
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.orange, size: 28),
            tooltip: "Broadcast New Notice",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminMessageComposer()),
              );
            },
          ),

          // 2. NOTIFICATION HISTORY
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent, size: 26),
            tooltip: "System Broadcast History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationInbox(
                    userTopic: "all_campus", 
                    userRole: "Admin", 
                  ),
                ),
              );
            },
          ),

          // 3. RESOURCE SETTINGS
          IconButton(
            icon: const Icon(Icons.settings_suggest, color: Colors.blueAccent, size: 28), 
            onPressed: () => showDialog(
              context: context, 
              builder: (ctx) => ResourceManagerDialog(allResources: _allResources)
            ),
          ),

          // 4. LOGOUT
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent), 
            onPressed: () => FirebaseAuth.instance.signOut()
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TimetableExplorer.showEditDialog(
            context, 
            null,           // New slot
            _selectedYear, 
            _selectedDiv, 
            _selectedDay, 
            "09:00",        // Default start time
            _activeSem, 
            _selectedDate   
          );
        },
        label: const Text("Add New Slot"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(),
            const SizedBox(height: 25),
            
            _sectionTitle("Timetable Explorer", "Schedules for $_selectedYear - $_selectedDiv"),
            _buildGlobalFilters(),
            const SizedBox(height: 15),
            
            TimetableExplorer(
              selectedYear: _selectedYear,
              selectedDiv: _selectedDiv,
              selectedDay: _selectedDay,
              activeSem: _activeSem,
              selectedDate: _selectedDate,
            ),
            
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context, 
          initialDate: _selectedDate, 
          firstDate: DateTime(2025), 
          lastDate: DateTime(2030)
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
          color: Colors.blue.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: Colors.blue.withOpacity(0.1))
        ),
        child: Row(children: [
          const Icon(Icons.calendar_month, color: Colors.blue),
          const SizedBox(width: 12),
          Text(DateFormat('dd MMM yyyy (EEEE)').format(_selectedDate), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          const Icon(Icons.edit, size: 18, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildGlobalFilters() => Row(children: [
    Expanded(child: _drop("Year", _selectedYear, _years, (v) => setState(() => _selectedYear = v!))),
    const SizedBox(width: 8),
    Expanded(child: _drop("Division", _selectedDiv, _divisions, (v) => setState(() => _selectedDiv = v!))),
  ]);

  Widget _sectionTitle(String t, String s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    Text(s, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
    const SizedBox(height: 10),
  ]);

  Widget _drop(String l, String v, List<String> i, Function(String?) o) {
    return DropdownButtonFormField<String>(
      value: v, 
      items: i.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
      onChanged: o,
      decoration: InputDecoration(
        labelText: l, 
        filled: true, 
        fillColor: Colors.grey.shade50, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
      ),
    );
  }
}