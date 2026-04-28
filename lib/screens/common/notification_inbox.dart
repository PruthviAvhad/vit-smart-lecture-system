import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationInbox extends StatelessWidget {
  final String userTopic;
  final String userRole;

  const NotificationInbox({
    super.key,
    required this.userTopic,
    required this.userRole,
  });

  String _cleanText(String text) {
    final emojiPattern = RegExp(
      r'[\u{1f300}-\u{1f5ff}\u{1f600}-\u{1f64f}\u{1f680}-\u{1f6ff}\u{1f700}-\u{1f77f}\u{1f900}-\u{1f9ff}\u{1f1e6}-\u{1f1ff}]',
      unicode: true,
    );
    return text.replaceAll(emojiPattern, '').trim();
  }

  IconData _getCategoryIcon(String? category) {
    final cat = category?.toLowerCase() ?? '';

    switch (cat) {
      case 'lecture update':
      case 'extra lecture':
      case 'extra lecture added':
        return Icons.add_circle_outline;
      case 'lecture cancelled':
        return Icons.cancel_outlined;
      case 'exam':
        return Icons.assignment_outlined;
      case 'timetable update':
      case 'weekly slot added':
        return Icons.calendar_today_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    Query notificationQuery = FirebaseFirestore.instance.collection('notifications');

    if (userRole != "Admin") {
      notificationQuery = notificationQuery.where('topics', arrayContainsAny: [
        userTopic,
        'all_campus',
        if (userRole == "Teacher") 'all_teachers',
      ]);
    }

    notificationQuery = notificationQuery.orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.white,
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
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }

          final List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

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
    DateTime time = DateTime.now();
    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      time = (data['timestamp'] as Timestamp).toDate();
    }

    final String cleanTitle = _cleanText(data['title'] ?? "Notice");
    final String category = data['category'] ?? 'General';

    final Color iconColor = category.toLowerCase().contains('cancelled')
        ? Colors.redAccent
        : Colors.indigo;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(_getCategoryIcon(category), color: iconColor, size: 22),
        ),
        title: Text(
          cleanTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          "$category • ${DateFormat('hh:mm a').format(time)}",
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
                  _cleanText(data['body'] ?? ""),
                  style: TextStyle(color: Colors.grey[800], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "From: ${data['senderName'] ?? 'Admin'}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo
                      ),
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
          Icon(Icons.mail_outline_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "Inbox is empty",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
            const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 30),
            const SizedBox(height: 12),
            Text(
              "Syncing issues: $error",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}