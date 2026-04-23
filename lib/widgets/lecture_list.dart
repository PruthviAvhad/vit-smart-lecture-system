import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:book_lec_app/widgets/booking_sheet.dart';

class LectureList extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final String dayName;
  final String dateString;

  const LectureList({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.dayName,
    required this.dateString,
  });

  // --- HELPER METHODS ---

  Future<String> _getSubjectFullName(String id) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('subjects').doc(id).get();
      return doc.data()?['name'] ?? id;
    } catch (e) {
      return id;
    }
  }

  Future<String> _getActualRoomNo(String id) async {
    if (id == "ONLINE") return "ONLINE";
    try {
      var doc = await FirebaseFirestore.instance.collection('resources').doc(id).get();
      return doc.data()?['currentRoomNo']?.toString() ?? id;
    } catch (e) {
      return id;
    }
  }

  // --- LOGIC METHODS ---

  void _handleDelete(BuildContext context, String docId, bool isExtra) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExtra ? "Delete Extra Booking?" : "Cancel Regular Lecture?"),
        content: Text(isExtra 
          ? "This will permanently remove this extra class record." 
          : "This will mark this lecture as cancelled for $dateString only."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (isExtra) {
                await FirebaseFirestore.instance.collection('extra_bookings').doc(docId).delete();
              } else {
                await FirebaseFirestore.instance.collection('cancelled_lectures').add({
                  'lectureId': docId,
                  'date': dateString,
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleRestore(String docId) async {
    // Finds and deletes the cancellation record to make the lecture active again
    var snap = await FirebaseFirestore.instance
        .collection('cancelled_lectures')
        .where('lectureId', isEqualTo: docId)
        .where('date', isEqualTo: dateString)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  void _openEditSheet(BuildContext context, Map<String, dynamic> data, String docId, bool isExtra) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingSheet(
        teacherId: teacherId,
        teacherName: teacherName,
        selectedDate: dateString,
        selectedDay: dayName,
        editDocId: isExtra ? docId : null, 
        initialData: data,
      ),
    ).then((_) {
      if (!isExtra) {
         FirebaseFirestore.instance.collection('cancelled_lectures').add({
            'lectureId': docId,
            'date': dateString,
         });
      }
    });
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        db.collection('timetable').where('teacherId', isEqualTo: teacherId).where('day', isEqualTo: dayName).snapshots(),
        db.collection('extra_bookings').where('teacherId', isEqualTo: teacherId).where('date', isEqualTo: dateString).snapshots(),
        db.collection('cancelled_lectures').where('date', isEqualTo: dateString).snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final cancelledIds = snapshot.data![2].docs.map((d) => d['lectureId'] as String).toSet();
        
        // We keep all slots; we don't filter them out anymore.
        final allSlots = [...snapshot.data![0].docs, ...snapshot.data![1].docs];

        allSlots.sort((a, b) => (a['startTime'] ?? "").compareTo(b['startTime'] ?? ""));

        if (allSlots.isEmpty) {
          return const Center(child: Text("No lectures scheduled for today."));
        }

        return ListView.builder(
          itemCount: allSlots.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) {
            var doc = allSlots[index];
            var data = doc.data() as Map<String, dynamic>;
            bool isCancelled = cancelledIds.contains(doc.id);
            bool isExtra = data.containsKey('type') && data['type'] == 'Extra';
            bool isOnline = data['isOnline'] ?? false;

            return FutureBuilder<List<String>>(
              future: Future.wait([
                _getSubjectFullName(data['subjectId'] ?? ""),
                _getActualRoomNo(data['resourceId'] ?? ""),
              ]),
              builder: (context, nameSnap) {
                String subjectName = nameSnap.data?[0] ?? "Loading...";
                String roomNo = isOnline ? "ONLINE" : (nameSnap.data?[1] ?? "...");

                return Opacity(
                  opacity: isCancelled ? 0.6 : 1.0, // Fade out if cancelled
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isCancelled ? Colors.grey[100] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      border: isCancelled ? Border.all(color: Colors.grey[300]!) : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
                      leading: _buildTimeLeading(data['startTime'] ?? "--", isCancelled),
                      title: Text(
                        "$subjectName (${data['division'] ?? 'All'})",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? Colors.grey[600] : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        isCancelled ? "LECTURE CANCELLED" : "Room: $roomNo | Batch: ${data['batch'] ?? 'All'}",
                        style: TextStyle(
                          color: isCancelled ? Colors.red[300] : Colors.grey[600], 
                          fontSize: 12,
                          fontWeight: isCancelled ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isExtra && !isCancelled) _buildExtraBadge(),
                          
                          if (isCancelled)
                            // RESTORE BUTTON
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.indigo),
                              onPressed: () => _handleRestore(doc.id),
                              tooltip: "Make Active",
                            )
                          else
                            // OPTIONS MENU
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (val) {
                                if (val == 'edit') _openEditSheet(context, data, doc.id, isExtra);
                                if (val == 'delete') _handleDelete(context, doc.id, isExtra);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(isExtra ? "Edit Booking" : "Reschedule"),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(isExtra ? "Delete Extra" : "Cancel for Today"),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimeLeading(String time, bool isCancelled) {
    return Container(
      width: 55, height: 55,
      decoration: BoxDecoration(
        color: isCancelled ? Colors.grey[200] : Colors.indigo[50], 
        borderRadius: BorderRadius.circular(10)
      ),
      child: Center(
        child: Text(
          time, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: isCancelled ? Colors.grey[500] : Colors.indigo[900], 
            fontSize: 13
          )
        )
      ),
    );
  }

  Widget _buildExtraBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
      child: Text("EXTRA", style: TextStyle(color: Colors.orange[800], fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}