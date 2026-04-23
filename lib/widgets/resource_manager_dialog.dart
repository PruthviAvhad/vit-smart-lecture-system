import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Load all data ONCE at the start to prevent FutureBuilder flickering
  Future<void> _initializeData() async {
    try {
      final snapshot = await _db.collection('resources').get();
      final Map<String, String> existingData = {
        for (var doc in snapshot.docs) doc.id: doc['currentRoomNo']?.toString() ?? ""
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

  @override
  Widget build(BuildContext context) {
    final filteredResources = widget.allResources.where((r) => r != "Online").toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.meeting_room, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text("Room Mapping", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 200, 
              child: Center(child: CircularProgressIndicator())
            )
          : SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6, // Prevents overflow
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredResources.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    String resId = filteredResources[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text("Resource: $resId", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _controllers[resId],
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Enter Room No (e.g. 1316A)",
                            hintStyle: const TextStyle(fontSize: 12),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.save, color: Colors.blueAccent, size: 20),
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
          child: const Text("Done", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))
        ),
      ],
    );
  }

  Future<void> _saveRoom(String resId, String val) async {
    if (val.trim().isEmpty) return;
    
    try {
      await _db.collection('resources').doc(resId).set(
        {'currentRoomNo': val.trim()}, 
        SetOptions(merge: true)
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resource $resId mapped to $val"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 800),
          ),
        );
        // Hide keyboard after saving
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error saving room mapping"), backgroundColor: Colors.red),
        );
      }
    }
  }
}