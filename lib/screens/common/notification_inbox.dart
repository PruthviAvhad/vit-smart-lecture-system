import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationInbox extends StatelessWidget {
  final String userTopic; // The Class Name (e.g. SY_Div_A) or Teacher ID
  final String userRole;  // "Admin", "Teacher", or "Student"

  const NotificationInbox({
    super.key, 
    required this.userTopic, 
    required this.userRole
  });

  @override
  Widget build(BuildContext context) {
    // 1. Setup the query
    Query query = FirebaseFirestore.instance.collection('notifications');

    // 2. Apply Smart Filtering based on Role
    // FIX: We now look for the specific topic OR 'all_campus' globally
    if (userRole == "Teacher") {
      query = query.where('topics', arrayContainsAny: ['Teacher_$userTopic', 'all_campus']);
    } else if (userRole == "Student") {
      query = query.where('topics', arrayContainsAny: [userTopic, 'all_campus']);
    } 
    // Note: Admin sees everything, so no 'where' clause is added for Admin.

    // 3. Sort by Time (Descending)
    // CRITICAL: Switching to arrayContainsAny requires a NEW Composite Index.
    // Check your debug console for the new Firebase link.
    query = query.orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text("$userRole Notice Board"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          // --- ERROR HANDLING ---
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          // --- LOADING STATE ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // --- EMPTY STATE ---
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          // --- LIST VIEW ---
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              
              // Safe parsing for timestamp
              DateTime time = (data['timestamp'] is Timestamp) 
                  ? (data['timestamp'] as Timestamp).toDate() 
                  : DateTime.now();

              // UI Logic for Categories
              String category = data['category'] ?? "General";
              List topics = data['topics'] ?? [];
              bool isGlobal = topics.contains("all_campus");
              bool isSlot = category == "Slot";

              Color accentColor = isGlobal ? Colors.orange[800]! : (isSlot ? Colors.blue[700]! : Colors.indigo);
              Color bgColor = isGlobal ? Colors.orange[50]! : (isSlot ? Colors.blue[50]! : Colors.white);
              IconData leadingIcon = isGlobal ? Icons.campaign : (isSlot ? Icons.event_available : Icons.notifications);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: bgColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: accentColor.withOpacity(0.1), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.1),
                            child: Icon(leadingIcon, color: accentColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? "Notice",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5),
                                ),
                                Text(
                                  category.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w900, 
                                    color: accentColor,
                                    letterSpacing: 0.5
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('hh:mm a').format(time),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(height: 1),
                      ),
                      Text(
                        data['body'] ?? "",
                        style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_pin, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                "From: ${data['senderName'] ?? data['senderRole']}",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(time),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "All Caught Up!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            "No new notices for $userTopic right now.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            const Text(
              "Firestore Index Required",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "The new search filter needs a Composite Index. Please click the blue link in your VS Code / Android Studio debug console to enable it.\n\n$error",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}