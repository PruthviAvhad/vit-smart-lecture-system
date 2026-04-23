import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMessageComposer extends StatefulWidget {
  const AdminMessageComposer({super.key});

  @override
  State<AdminMessageComposer> createState() => _AdminMessageComposerState();
}

class _AdminMessageComposerState extends State<AdminMessageComposer> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _selectedTarget = "all_campus"; 
  bool _isSending = false;

  // These topics match the logic in NotificationInbox
  final List<String> _topics = [
    "all_campus",
    "TY_Div_A", "TY_Div_B", "TY_Div_C",
    "SY_Div_A", "SY_Div_B", "SY_Div_C",
    "FY_Div_A", "FY_Div_B", "FY_Div_C",
  ];

  Future<void> _sendMessage() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // --- CRITICAL FIX FOR MULTI-ROLE VIEWING ---
      // We save 'topics' as an array so that arrayContainsAny can find it
      await _db.collection('notifications').add({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'topics': [_selectedTarget], // Must stay as a List [v]
        'category': _selectedTarget == "all_campus" ? "Global" : "Urgent",
        'timestamp': FieldValue.serverTimestamp(),
        'senderRole': 'Admin',
        'senderName': 'Admin Office',
      });

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notice Broadcasted Successfully!"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Optional: Go back to Admin Panel after sending
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Broadcast Notice", 
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Target Audience", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedTarget = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Text("Notice Details", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Title",
                hintText: "e.g., Exam Postponed",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _bodyController,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: "Message Description",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending 
                  ? const SizedBox.shrink() 
                  : const Icon(Icons.send_rounded),
                label: _isSending 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Send Broadcast", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[900],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}