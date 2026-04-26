import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- FIXED IMPORT ---
// Using relative path to ensure the compiler finds your service file correctly
import '../services/notification_service.dart';

class ResourceManagerDialog extends StatefulWidget {
  final List<String> allResources;
  const ResourceManagerDialog({super.key, required this.allResources});

  @override
  State<ResourceManagerDialog> createState() => _ResourceManagerDialogState();
}

class _ResourceManagerDialogState extends State<ResourceManagerDialog> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final snapshot = await _db.collection('resources').get();
      final Map<String, String> existingData = {
        for (var doc in snapshot.docs) 
          doc.id: (doc.data().containsKey('currentRoomNo')) 
              ? doc['currentRoomNo']?.toString() ?? "" 
              : ""
      };

      for (var resId in widget.allResources) {
        if (resId == "Online") continue;
        _controllers[resId] = TextEditingController(text: existingData[resId] ?? "");
      }
    } catch (e) {
      debugPrint("Error initializing resources: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- IMPROVED SAVE LOGIC ---
  Future<void> _saveRoom(String resId, String val) async {
    final cleanVal = val.trim();
    if (cleanVal.isEmpty) return;
    
    try {
      // 1. Update the Mapping in Firestore
      await _db.collection('resources').doc(resId).set(
        {'currentRoomNo': cleanVal}, 
        SetOptions(merge: true)
      );

      // 2. Trigger Push Notification via static Service
      // Updated to match your NotificationService.send signature
      await NotificationService.send(
        title: "🏫 Room Location Update",
        body: "Resource $resId is now mapped to Room $cleanVal.",
        topics: ["Admin_Updates"], // Sending to an admin/all-user topic
        category: "System Update",
        senderName: "Resource Manager",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resource $resId mapped to $cleanVal"),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
          ),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out "Online" as it doesn't need a physical room mapping
    final filteredResources = widget.allResources.where((r) => r != "Online").toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.room_preferences, color: Colors.indigo),
          SizedBox(width: 10),
          Text("Admin Room Mapping", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredResources.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    String resId = filteredResources[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text("Resource ID: $resId", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _controllers[resId],
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Assign Room (e.g. 1316A)",
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 22),
                              onPressed: () => _saveRoom(resId, _controllers[resId]!.text),
                            ),
                          ),
                          onSubmitted: (val) => _saveRoom(resId, val),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
      ],
    );
  }
}