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

  final List<String> _topics = [
    "all_campus",
    "TY_Div_A", "TY_Div_B", "TY_Div_C",
    "SY_Div_A", "SY_Div_B", "SY_Div_C",
    "FY_Div_A", "FY_Div_B", "FY_Div_C",
  ];

  Future<void> _sendMessage() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      List<String> targetTopics = [_selectedTarget];
      
      if (_selectedTarget != "all_campus") {
        targetTopics.add("admin_logs");
      }

      await _db.collection('notifications').add({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'topics': targetTopics, 
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
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Broadcast Notice", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Target Audience", Icons.groups_rounded),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              items: _topics.map((t) => DropdownMenuItem(
                value: t, 
                child: Text(t.replaceAll('_', ' ')), 
              )).toList(),
              onChanged: (v) => setState(() => _selectedTarget = v!),
              decoration: _inputDecoration(null),
            ),
            
            const SizedBox(height: 30),
            
            _sectionHeader("Notice Details", Icons.edit_note_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration("Title (e.g. Exam Schedule)"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _bodyController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration("Message Description...").copyWith(
                alignLabelWithHint: true,
              ),
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Icon(Icons.send_rounded),
                label: Text(_isSending ? "Sending..." : "Send Broadcast", 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo[900], size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  InputDecoration _inputDecoration(String? label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.indigo.shade900, width: 2),
      ),
    );
  }
}