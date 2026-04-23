import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class SendNotificationDialog extends StatefulWidget {
  final String senderRole; // Pass 'Admin' or 'Prof. Name'
  final bool isAdmin;      // Admins see all classes, Teachers see their own

  SendNotificationDialog({required this.senderRole, this.isAdmin = false});

  @override
  _SendNotificationDialogState createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<SendNotificationDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  
  // Default topics - Add your college divisions here
  String _selectedTopic = 'all_campus';
  final List<String> _topics = ['all_campus', 'FY_Div_A', 'SY_Div_A', 'TY_Div_A'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Compose Announcement"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isAdmin) 
              DropdownButtonFormField<String>(
                value: _selectedTopic,
                decoration: InputDecoration(labelText: "Target Audience"),
                items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedTopic = val!),
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: "Heading (e.g. Holiday)"),
            ),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: InputDecoration(labelText: "Message Content"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (_titleController.text.isNotEmpty && _bodyController.text.isNotEmpty) {
              await NotificationService.send(
                title: _titleController.text,
                body: _bodyController.text,
                topic: _selectedTopic,
                senderRole: widget.senderRole,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Notification Broadcasted!")),
              );
            }
          },
          child: Text("Send Now"),
        ),
      ],
    );
  }
}