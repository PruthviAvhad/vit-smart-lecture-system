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

  String get _dayName => DateFormat('EEEE').format(_selectedDate);
  String get _dateString => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _formattedDate => DateFormat('dd MMM, yyyy').format(_selectedDate);

  
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out of the Teacher Portal?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _openBookingSheet(
    BuildContext context,
    String teacherId,
    String teacherName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingSheet(
        teacherId: teacherId,
        teacherName: teacherName,
        selectedDate: _dateString,
        selectedDay: _dayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      return const Scaffold(
        body: Center(
          child: Text("No active session found"),
        ),
      );
    }

    final userEmail = user.email!;

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(userEmail).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.indigo,
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(
              child: Text("Teacher profile not found"),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final String teacherId =
            data['officialId']?.toString() ?? "";

        final String teacherName =
            data['name']?.toString() ?? "Teacher";

        final bool isAvailable =
            data['status'] == "Available";

        return Scaffold(
          backgroundColor: Colors.grey[100],

          
          appBar: AppBar(
            backgroundColor: Colors.indigo[800],
            elevation: 0,
            title: const Text(
              "Teacher Portal",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                tooltip: "Notifications",
                icon: const Icon(
                  Icons.history,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationInbox(
                        userTopic: "Teacher_$teacherId",
                        userRole: "Teacher",
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: "Logout",
                icon: const Icon(
                  Icons.logout,
                  color: Colors.white,
                ),
                onPressed: _handleLogout,
              ),
            ],
          ),

         
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.indigo[800],
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
            label: const Text(
              "Book Extra Slot",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () =>
                _openBookingSheet(context, teacherId, teacherName),
          ),

         
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(
                  data,
                  isAvailable,
                  userEmail,
                ),

                const SizedBox(height: 12),

              
                WorkloadStats(
                  teacherId: teacherId,
                  selectedDate: _selectedDate,
                ),

                const SizedBox(height: 8),

                _buildDateSection(),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Schedule for $_dayName",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_view_day,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: 430,
                  child: LectureList(
                    teacherId: teacherId,
                    teacherName: teacherName,
                    dayName: _dayName,
                    dateString: _dateString,
                  ),
                ),

                const SizedBox(height: 90),
              ],
            ),
          ),
        );
      },
    );
  }

  
  Widget _buildHeader(
    Map<String, dynamic> data,
    bool isAvailable,
    String email,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white24,
                child: Text(
                  data['name'] != null
                      ? data['name'][0]
                      : "T",
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? "Teacher",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      data['designation'] ?? "Faculty",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "ID: ${data['officialId'] ?? '-'}",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAvailable
                      ? "Currently: Available"
                      : "Currently: On Leave",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                Switch(
                  activeColor: Colors.greenAccent,
                  value: isAvailable,
                  onChanged: (val) {
                    _db
                        .collection('users')
                        .doc(email)
                        .update({
                      'status': val
                          ? "Available"
                          : "On Leave",
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now()
                .subtract(const Duration(days: 30)),
            lastDate: DateTime(2027),
          );

          if (picked != null) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _formattedDate,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.calendar_month,
                color: Colors.indigo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}