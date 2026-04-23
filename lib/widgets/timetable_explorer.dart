import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:async/async.dart';

class TimetableExplorer extends StatelessWidget {
  final String selectedYear;
  final String selectedDiv;
  final String selectedDay;
  final String activeSem;
  final DateTime selectedDate;

  const TimetableExplorer({
    super.key,
    required this.selectedYear,
    required this.selectedDiv,
    required this.selectedDay,
    required this.activeSem,
    required this.selectedDate,
  });

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- IMPROVED HISTORY LOGGING ---
  static Future<void> _logToHistory({
    required String title,
    required String body,
    required String topic,
  }) async {
    // 1. Log for the Students/Teachers (Targeted Topic)
    await _db.collection('notifications').add({
      'title': title,
      'body': body,
      'topic': topic, 
      'senderRole': 'Admin',
      'senderName': 'System Admin', // This ensures "By: Admin" shows up in UI
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Log for Global Admin Oversight (Internal Log)
    // Changing topic to 'admin_logs' so it doesn't clutter the 'all_campus' board
    await _db.collection('notifications').add({
      'title': "[System] $title",
      'body': "Target: $topic | $body",
      'topic': "admin_logs", 
      'senderRole': 'Admin',
      'senderName': 'System Admin',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    return StreamBuilder<List<QuerySnapshot>>(
      stream: StreamZip([
        _db.collection('timetable')
            .where('semesterId', isEqualTo: activeSem)
            .where('year', isEqualTo: selectedYear)
            .where('division', isEqualTo: selectedDiv)
            .where('day', isEqualTo: selectedDay).snapshots(),
        _db.collection('extra_bookings')
            .where('year', isEqualTo: selectedYear)
            .where('division', isEqualTo: selectedDiv)
            .where('date', isEqualTo: dateStr).snapshots(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        List<DocumentSnapshot> allDocs = [];
        if (snapshot.hasData) {
          for (var snap in snapshot.data!) {
            allDocs.addAll(snap.docs);
          }
        }

        allDocs.sort((a, b) {
          String t1 = (a.data() as Map<String, dynamic>)['startTime'] ?? "00:00";
          String t2 = (b.data() as Map<String, dynamic>)['startTime'] ?? "00:00";
          return t1.compareTo(t2);
        });

        if (allDocs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No lectures scheduled.")));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allDocs.length,
          itemBuilder: (context, index) {
            var doc = allDocs[index];
            var data = doc.data() as Map<String, dynamic>;
            bool isExtra = doc.reference.path.contains('extra_bookings');

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), 
                side: BorderSide(color: isExtra ? Colors.orange.shade300 : Colors.grey.shade200, width: isExtra ? 2 : 1)
              ),
              child: ListTile(
                onTap: () => showEditDialog(context, doc, selectedYear, selectedDiv, selectedDay, data['startTime'], activeSem, selectedDate),
                leading: CircleAvatar(
                  backgroundColor: isExtra ? Colors.orange.shade50 : Colors.blue.shade50, 
                  child: Icon(isExtra ? Icons.star : Icons.book, color: isExtra ? Colors.orange : Colors.blue)
                ),
                title: Row(
                  children: [
                    FutureBuilder<String>(
                      future: _fetchName('subjects', data['subjectId'], 'name'),
                      builder: (context, res) => Text(res.data ?? "...", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (isExtra) _tag("EXTRA", Colors.orange),
                  ],
                ),
                subtitle: _buildSlotSubtitle(data),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red), 
                  onPressed: () async {
                    bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Delete Slot?"),
                        content: const Text("Students will be notified of this cancellation."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      String subName = await _fetchName('subjects', data['subjectId'], 'name');
                      String targetTopic = "${selectedYear}_Div_$selectedDiv";

                      await _logToHistory(
                        title: "❌ Lecture Cancelled",
                        body: "$subName at ${data['startTime']} has been removed by Admin.",
                        topic: targetTopic,
                      );

                      await doc.reference.delete();
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TRIPLE CONFLICT VALIDATION ---
  static Future<String?> _validateBooking({
    required String teacherId,
    required String resourceId,
    required String startTime,
    required String day,
    required String dateStr,
    required String division,
    required String batch,
    String? currentDocId,
  }) async {
    if (resourceId != "Online") {
      var rReg = await _db.collection('timetable').where('day', isEqualTo: day).where('startTime', isEqualTo: startTime).where('resourceId', isEqualTo: resourceId).get();
      var rExt = await _db.collection('extra_bookings').where('date', isEqualTo: dateStr).where('startTime', isEqualTo: startTime).where('resourceId', isEqualTo: resourceId).get();
      if (rReg.docs.any((d) => d.id != currentDocId) || rExt.docs.any((d) => d.id != currentDocId)) return "Conflict: Room is already occupied.";
    }

    var tReg = await _db.collection('timetable').where('day', isEqualTo: day).where('startTime', isEqualTo: startTime).where('teacherId', isEqualTo: teacherId).get();
    var tExt = await _db.collection('extra_bookings').where('date', isEqualTo: dateStr).where('startTime', isEqualTo: startTime).where('teacherId', isEqualTo: teacherId).get();
    if (tReg.docs.any((d) => d.id != currentDocId) || tExt.docs.any((d) => d.id != currentDocId)) return "Conflict: Teacher is busy in another class.";

    var bReg = await _db.collection('timetable').where('day', isEqualTo: day).where('startTime', isEqualTo: startTime).where('division', isEqualTo: division).get();
    var bExt = await _db.collection('extra_bookings').where('date', isEqualTo: dateStr).where('startTime', isEqualTo: startTime).where('division', isEqualTo: division).get();
    for (var d in [...bReg.docs, ...bExt.docs]) {
      if (d.id == currentDocId) continue;
      String exBatch = d['batch'] ?? "All";
      if (exBatch == "All" || batch == "All" || exBatch == batch) return "Conflict: This division/batch already has a class.";
    }
    return null;
  }

  // --- EDIT / ADD DIALOG ---
  static void showEditDialog(BuildContext context, DocumentSnapshot? doc, String year, String div, String day, String? time, String sem, DateTime date) {
    bool isEdit = doc != null;
    Map<String, dynamic> data = isEdit ? (doc.data() as Map<String, dynamic>) : {};
    String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    bool isPermanent = isEdit ? doc.reference.path.contains('timetable') : true;

    String? sSub = data['subjectId'];
    String? sTeacher = data['teacherId'];
    String? sRoom = data['resourceId'];
    String? sBatch = data['batch'] ?? "All";
    String sTime = time ?? "09:00";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? "Update Slot" : "Add New Slot"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                  activeColor: Colors.blue,
                  title: const Text("Weekly Permanent Slot", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(isPermanent ? "Every $day" : "One-time: $dateStr"),
                  value: isPermanent,
                  onChanged: isEdit ? null : (v) => setDState(() => isPermanent = v),
                ),
                const Divider(),
                _buildAsyncDrop('subjects', 'name', sSub, (v) => setDState(() => sSub = v)),
                const SizedBox(height: 12),
                _buildAsyncDrop('users', 'name', sTeacher, (v) => setDState(() => sTeacher = v), isTeacher: true),
                const SizedBox(height: 15),
                const Align(alignment: Alignment.centerLeft, child: Text("Room Selection:", style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 95,
                  child: _buildResourceMonitor(day, sTime, sRoom, (v) => setDState(() => sRoom = v), docId: doc?.id),
                ),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _simpleDrop("Time", sTime, List.generate(11, (i) => "${(i + 8).toString().padLeft(2, '0')}:00"), (v) => setDState(() => sTime = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _simpleDrop("Batch", sBatch!, ["All", "${div}1", "${div}2", "${div}3"], (v) => setDState(() => sBatch = v))),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: (sRoom == null || sSub == null || sTeacher == null) ? null : () async {
                String? error = await _validateBooking(
                  teacherId: sTeacher!, resourceId: sRoom!, startTime: sTime, 
                  day: day, dateStr: dateStr, division: div, batch: sBatch!, currentDocId: doc?.id
                );

                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                } else {
                  var p = {
                    'subjectId': sSub, 'teacherId': sTeacher, 'resourceId': sRoom, 
                    'batch': sBatch, 'startTime': sTime, 'day': day, 
                    'year': year, 'division': div, 'semesterId': sem
                  };

                  String subName = await _fetchName('subjects', sSub, 'name');
                  String roomNo = await _fetchRoomNo(sRoom);
                  String targetTopic = "${year}_Div_$div";

                  if (isEdit) {
                    if (doc!.reference.path.contains('extra_bookings')) p['date'] = dateStr;
                    await doc.reference.update(p);
                    
                    await _logToHistory(
                      title: "🕒 Slot Updated",
                      body: "$subName moved to $sTime in $roomNo by Admin.",
                      topic: targetTopic,
                    );
                  } else {
                    if (!isPermanent) p['date'] = dateStr;
                    await _db.collection(isPermanent ? 'timetable' : 'extra_bookings').add(p);
                    
                    await _logToHistory(
                      title: isPermanent ? "📅 Weekly Slot Added" : "✨ Extra Slot Added",
                      body: "New $subName scheduled at $sTime in $roomNo.",
                      topic: targetTopic,
                    );
                  }
                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text("Save Slot"),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  static Widget _buildResourceMonitor(String day, String time, String? currentRoom, Function(String) onSelect, {String? docId}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('timetable').where('day', isEqualTo: day).where('startTime', isEqualTo: time).snapshots(),
      builder: (context, snap) {
        Set<String> busy = snap.hasData ? snap.data!.docs.where((d) => d.id != docId).map((d) => d['resourceId'].toString().toUpperCase()).toSet() : {};
        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('resources').snapshots(),
          builder: (context, resSnap) {
            if (!resSnap.hasData) return const Center(child: LinearProgressIndicator());
            var list = resSnap.data!.docs;
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: list.length + 1,
              itemBuilder: (context, i) {
                if (i == list.length) return _resourceTile("Online", "Online", currentRoom == "Online", false, () => onSelect("Online"));
                var r = list[i];
                bool isBusy = busy.contains(r.id.toUpperCase());
                return _resourceTile(r['currentRoomNo'] ?? r.id, r.id, currentRoom == r.id, isBusy, () => onSelect(r.id));
              },
            );
          },
        );
      },
    );
  }

  static Widget _resourceTile(String label, String id, bool sel, bool busy, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 85, margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.blue : (busy ? Colors.red.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? Colors.blue : (busy ? Colors.red.shade200 : Colors.grey.shade300)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black)),
          if (busy) const Text("BUSY", style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  static Widget _tag(String text, Color color) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
  );

  static Widget _buildSlotSubtitle(Map<String, dynamic> data) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FutureBuilder<String>(
        future: _fetchName('users', data['teacherId'], 'name', isTeacher: true),
        builder: (context, res) => Text("👨‍🏫 ${res.data ?? '...'}", style: const TextStyle(fontSize: 12)),
      ),
      FutureBuilder<String>(
        future: _fetchRoomNo(data['resourceId']),
        builder: (context, res) => Text("🕒 ${data['startTime']} | 📍 ${res.data ?? '...'}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ),
    ]);
  }

  static Future<String> _fetchRoomNo(String? id) async {
    if (id == null || id == "Online") return id ?? "Unknown";
    try {
      var d = await _db.collection('resources').doc(id).get();
      return d.exists ? d['currentRoomNo'] ?? id : id;
    } catch (e) { return id; }
  }

  static Future<String> _fetchName(String col, String? id, String field, {bool isTeacher = false}) async {
    if (id == null || id.isEmpty || id == "Online") return id ?? "Unknown";
    try {
      if (isTeacher) {
        var s = await _db.collection(col).where('officialId', isEqualTo: id).limit(1).get();
        return s.docs.isNotEmpty ? s.docs.first[field] : "Unknown";
      }
      var d = await _db.collection(col).doc(id).get();
      return d.exists ? d[field] : "Unknown";
    } catch (e) { return "Unknown"; }
  }

  static Widget _buildAsyncDrop(String col, String field, String? val, Function(String?) onCh, {bool isTeacher = false}) {
    return FutureBuilder<QuerySnapshot>(
      future: isTeacher ? _db.collection(col).where('role', isEqualTo: 'teacher').get() : _db.collection(col).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        var items = snap.data!.docs.map((d) {
          String id = isTeacher ? d['officialId'] : d.id;
          return DropdownMenuItem(value: id, child: Text(d[field]));
        }).toList();
        return DropdownButtonFormField<String>(
          isExpanded: true, value: items.any((i) => i.value == val) ? val : null, items: items, onChanged: onCh,
          decoration: InputDecoration(labelText: "Select $col", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        );
      },
    );
  }

  static Widget _simpleDrop(String l, String v, List<String> i, Function(String?) o) {
    return DropdownButtonFormField<String>(
      value: i.contains(v) ? v : i.first, items: i.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: o,
      decoration: InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}