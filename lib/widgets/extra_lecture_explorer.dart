import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExtraLectureExplorer extends StatefulWidget {
  const ExtraLectureExplorer({super.key});

  @override
  State<ExtraLectureExplorer> createState() => _ExtraLectureExplorerState();
}

class _ExtraLectureExplorerState extends State<ExtraLectureExplorer> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();
  
  // Adjusted to match your AdminPanel's naming convention
  String _selectedYear = "TY";
  String _selectedDiv = "B";

  @override
  Widget build(BuildContext context) {
    // Ensure this format matches how you ADD extra lectures to Firestore
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.orange.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  icon: const Icon(Icons.calendar_month, size: 20, color: Colors.orange),
                  label: Text(DateFormat('dd MMM yyyy').format(_selectedDate), 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 8),
              // Updated years to match AdminPanel
              Expanded(child: _filterDrop("Year", _selectedYear, ["FE", "SE", "SY", "TE", "TY", "BE"], (v) => setState(() => _selectedYear = v!))),
              const SizedBox(width: 8),
              Expanded(child: _filterDrop("Div", _selectedDiv, ["A", "B", "C", "D", "E"], (v) => setState(() => _selectedDiv = v!))),
            ],
          ),
        ),
        Expanded(child: _buildExtraList(dateStr)),
      ],
    );
  }

  Widget _buildExtraList(String dateStr) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('extra_bookings')
          .where('date', isEqualTo: dateStr)
          .where('year', isEqualTo: _selectedYear)
          .where('division', isEqualTo: _selectedDiv)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("No extra lectures scheduled", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                Text("for $dateStr", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var docId = docs[index].id;
            var data = docs[index].data() as Map<String, dynamic>;
            
            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.orange.shade100),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: Colors.orange),
                ),
                title: Text("${data['startTime']} | ${data['subjectId']}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // Resolved Teacher Name from Official ID
                    FutureBuilder<QuerySnapshot>(
                      future: _db.collection('users').where('officialId', isEqualTo: data['teacherId']).limit(1).get(),
                      builder: (context, userSnap) {
                        String name = (userSnap.hasData && userSnap.data!.docs.isNotEmpty) 
                            ? userSnap.data!.docs.first['name'] : (data['teacherId'] ?? "TBD");
                        return Text("👨‍🏫 $name", style: TextStyle(color: Colors.grey.shade700, fontSize: 13));
                      }
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<DocumentSnapshot>(
                      future: _db.collection('resources').doc(data['resourceId']).get(),
                      builder: (context, resSnap) {
                        String room = (resSnap.hasData && resSnap.data!.exists) 
                            ? resSnap.data!['currentRoomNo'] ?? data['resourceId'] 
                            : data['resourceId'];
                        return Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text("📍 Room: $room", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                        );
                      },
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(docId),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Extra Lecture?"),
        content: const Text("This will permanently remove this session from the student view."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _db.collection('extra_bookings').doc(id).delete();
              if (mounted) Navigator.pop(ctx);
            }, 
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _filterDrop(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}