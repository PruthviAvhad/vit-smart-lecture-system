import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:book_lec_app/widgets/lecture_list.dart';
import 'package:book_lec_app/widgets/booking_sheet.dart';
import 'package:book_lec_app/widgets/workload_stats.dart'; 
import '../common/notification_inbox.dart'; 

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();

  // Getters for Firestore filtering
  String get _dayName => DateFormat('EEEE').format(_selectedDate);
  String get _dateString => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _formattedDate => DateFormat('dd MMM, yyyy').format(_selectedDate);

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(userEmail).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Profile not found.")),
          );
        }

        var userData = userSnap.data!.data() as Map<String, dynamic>;
        String teacherId = userData['officialId']?.toString() ?? "";
        String teacherName = userData['name'] ?? "Teacher";
        bool isAvailable = userData['status'] == "Available";

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text("Teacher Portal", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.indigo[800],
            elevation: 0,
            actions: [
              // --- UPDATED: NOTIFICATION HISTORY WITH STRICT FILTERING ---
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: "Broadcast History",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationInbox(
                        // Pass teacher's email as topic to see direct messages 
                        // and pass "Teacher" role to enable strict filtering
                        userTopic: userEmail ?? "Teacher", 
                        userRole: "Teacher", 
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => FirebaseAuth.instance.signOut(),
              )
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.indigo[800],
            onPressed: () => _showBookingSheet(context, teacherId, teacherName),
            label: const Text("Book Extra Slot", style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
          body: SingleChildScrollView( 
            child: Column(
              children: [
                _buildHeader(userData, isAvailable, userEmail!),
                
                // Analytics Section
                WorkloadStats(teacherId: teacherId, selectedDate: _selectedDate),
                
                _buildDateSection(),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Schedule for $_dayName", 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Icon(Icons.sort, color: Colors.grey),
                    ],
                  ),
                ),

                // Schedule List
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: LectureList(
                    teacherId: teacherId,
                    teacherName: teacherName,
                    dayName: _dayName,
                    dateString: _dateString,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBookingSheet(BuildContext context, String id, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingSheet(
        teacherId: id,
        teacherName: name,
        selectedDate: _dateString,
        selectedDay: _dayName,
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data, bool isAvailable, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white24,
                child: Text(data['name']?[0] ?? "T", 
                  style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? "Teacher", 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(data['designation'] ?? "Faculty", 
                      style: const TextStyle(color: Colors.white70)),
                    Text("ID: ${data['officialId']}", 
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAvailable ? "Currently: Available" : "Currently: On Leave",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Switch(
                  value: isAvailable,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) {
                    _db.collection('users').doc(email).update({
                      'status': val ? "Available" : "On Leave"
                    });
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime(2027),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(15), 
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_formattedDate, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const Icon(Icons.calendar_month, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}