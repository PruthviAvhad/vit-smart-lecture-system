import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkloadStats extends StatelessWidget {
  final String teacherId;
  final DateTime selectedDate;

  const WorkloadStats({super.key, required this.teacherId, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    String dayName = DateFormat('EEEE').format(selectedDate);
    String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Card 1: Today's Count
          Expanded(
            child: _statCard(
              "Today",
              _countStream(dayName, dateStr),
              Colors.orange.shade800,
              Icons.today,
            ),
          ),
          const SizedBox(width: 15),
          // Card 2: Weekly Load
          Expanded(
            child: _statCard(
              "Weekly Load",
              _weeklyStream(),
              Colors.indigo.shade800,
              Icons.bar_chart,
            ),
          ),
        ],
      ),
    );
  }

  // Stream to count lectures for the selected day (Permanent + Extra)
  Stream<int> _countStream(String day, String date) {
    var db = FirebaseFirestore.instance;
    return Stream.fromFuture(Future.wait([
      db.collection('timetable').where('teacherId', isEqualTo: teacherId).where('day', isEqualTo: day).get(),
      db.collection('extra_bookings').where('teacherId', isEqualTo: teacherId).where('date', isEqualTo: date).get(),
    ])).map((snaps) => snaps[0].docs.length + snaps[1].docs.length);
  }

  // Stream to count total weekly master slots
  Stream<int> _weeklyStream() {
    return FirebaseFirestore.instance
        .collection('timetable')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Widget _statCard(String label, Stream<int> stream, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snap) => Text(
              "${snap.data ?? 0} Slots",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}