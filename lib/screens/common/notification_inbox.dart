import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationInbox extends StatelessWidget {
  final String userTopic; // e.g., "SY_B" or "Teacher_ID"
  final String userRole;  // "Admin", "Teacher", or "Student"

  const NotificationInbox({
    super.key,
    required this.userTopic,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Define the Query
    Query notificationQuery = FirebaseFirestore.instance.collection('notifications');

    // 2. Role-Based Filtering
    // Admin sees everything. Others see specific topics + global campus news.
    if (userRole != "Admin") {
      notificationQuery = notificationQuery.where('topics', arrayContainsAny: [
        userTopic, 
        'all_campus',
        if (userRole == "Teacher") 'all_teachers',
      ]);
    }

    // 3. Sorting (Requires Composite Index in Firebase)
    notificationQuery = notificationQuery.orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("$userRole Notice Board"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationQuery.snapshots(),
        builder: (context, snapshot) {
          // --- Error State ---
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          // --- Loading State ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }

          final List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];

          // --- Empty State ---
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          // --- List of Notices ---
          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _buildNotificationCard(data);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    // Safe timestamp parsing
    DateTime time = DateTime.now();
    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      time = (data['timestamp'] as Timestamp).toDate();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.indigo.withOpacity(0.1), width: 1),
      ),
      elevation: 0.5,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8EAF6), // Light Indigo
          child: Icon(Icons.notifications_active, color: Colors.indigo, size: 20),
        ),
        title: Text(
          data['title'] ?? "Notice",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "${data['category'] ?? 'General'} • ${DateFormat('hh:mm a').format(time)}",
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  data['body'] ?? "",
                  style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "From: ${data['senderName'] ?? 'Admin'}",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(time),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No notices for $userTopic",
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 16),
            Text(
              "Query Error: $error",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            const Text(
              "Note: You likely need to create a 'Composite Index' in Firebase Console.",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}