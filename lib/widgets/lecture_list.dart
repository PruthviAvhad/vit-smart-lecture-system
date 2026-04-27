import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:book_lec_app/widgets/booking_sheet.dart';

class LectureList extends StatefulWidget {
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

  @override
  State<LectureList> createState() => _LectureListState();
}

class _LectureListState extends State<LectureList> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, String> _subjectCache = {};
  final Map<String, String> _roomCache = {};

  Future<String> _getSubjectFullName(String id) async {
    if (id.isEmpty) return "Unknown Subject";

    if (_subjectCache.containsKey(id)) {
      return _subjectCache[id]!;
    }

    try {
      final doc = await _db.collection('subjects').doc(id).get();
      final name = doc.data()?['name'] ?? id;
      _subjectCache[id] = name;
      return name;
    } catch (_) {
      return id;
    }
  }

  Future<String> _getActualRoomNo(String id) async {
    if (id.isEmpty) return "---";
    if (id == "ONLINE") return "ONLINE";

    if (_roomCache.containsKey(id)) {
      return _roomCache[id]!;
    }

    try {
      final doc = await _db.collection('resources').doc(id).get();
      final room = doc.data()?['currentRoomNo']?.toString() ?? id;
      _roomCache[id] = room;
      return room;
    } catch (_) {
      return id;
    }
  }

  
  void _handleDelete(BuildContext context, String docId, bool isExtra) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isExtra ? "Delete Extra Booking?" : "Cancel Regular Lecture?",
        ),
        content: Text(
          isExtra
              ? "This will permanently delete this extra lecture."
              : "This will cancel this lecture only for ${widget.dateString}.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              if (isExtra) {
                await _db.collection('extra_bookings').doc(docId).delete();
              } else {
                await _db
                    .collection('cancelled_lectures')
                    .doc("${docId}_${widget.dateString}")
                    .set({
                  'lectureId': docId,
                  'date': widget.dateString,
                });
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              "Confirm",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  
  Future<void> _handleRestore(String docId) async {
    final snap = await _db
        .collection('cancelled_lectures')
        .where('lectureId', isEqualTo: docId)
        .where('date', isEqualTo: widget.dateString)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }


  Future<void> _openEditSheet(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
    bool isExtra,
  ) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingSheet(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        selectedDate: widget.dateString,
        selectedDay: widget.dayName,

     
        editDocId: isExtra ? docId : null,

    
        originalLectureId: isExtra ? null : docId,

        initialData: data,
      ),
    );

    if (result == true && !isExtra) {
      await _db
          .collection('cancelled_lectures')
          .doc("${docId}_${widget.dateString}")
          .set({
        'lectureId': docId,
        'date': widget.dateString,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        _db
            .collection('timetable')
            .where('teacherId', isEqualTo: widget.teacherId)
            .where('day', isEqualTo: widget.dayName)
            .snapshots(),

        _db
            .collection('extra_bookings')
            .where('teacherId', isEqualTo: widget.teacherId)
            .where('date', isEqualTo: widget.dateString)
            .snapshots(),

        _db
            .collection('cancelled_lectures')
            .where('date', isEqualTo: widget.dateString)
            .snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final timetableDocs = snapshot.data![0].docs;
        final extraDocs = snapshot.data![1].docs;
        final cancelDocs = snapshot.data![2].docs;

        final cancelledIds =
            cancelDocs.map((e) => e['lectureId'] as String).toSet();

        final allLectures = [...timetableDocs, ...extraDocs];

        allLectures.sort(
          (a, b) =>
              (a['startTime'] ?? "").compareTo(b['startTime'] ?? ""),
        );

        if (allLectures.isEmpty) {
          return const Center(
            child: Text("No lectures scheduled today."),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          itemCount: allLectures.length,
          itemBuilder: (context, index) {
            final doc = allLectures[index];
            final data = doc.data() as Map<String, dynamic>;

            final bool isExtra = data['type'] == 'Extra';
            final bool isCancelled = cancelledIds.contains(doc.id);
            final bool isOnline = data['isOnline'] ?? false;

            return FutureBuilder<List<String>>(
              future: Future.wait([
                _getSubjectFullName(data['subjectId'] ?? ""),
                _getActualRoomNo(data['resourceId'] ?? ""),
              ]),
              builder: (context, snap) {
                final subject = snap.data?[0] ?? "Loading...";
                final room =
                    isOnline ? "ONLINE" : (snap.data?[1] ?? "...");

                return Opacity(
                  opacity: isCancelled ? 0.6 : 1,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color:
                          isCancelled ? Colors.grey[100] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: _buildTimeBox(
                        data['startTime'] ?? "--",
                        isCancelled,
                      ),
                      title: Text(
                        "$subject (${data['division']})",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        isCancelled
                            ? "LECTURE CANCELLED"
                            : "Room: $room | Batch: ${data['batch'] ?? 'All'}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isExtra && !isCancelled)
                            _buildExtraBadge(),

                          if (isCancelled)
                            IconButton(
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.indigo,
                              ),
                              onPressed: () =>
                                  _handleRestore(doc.id),
                            )
                          else
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _openEditSheet(
                                    context,
                                    data,
                                    doc.id,
                                    isExtra,
                                  );
                                }

                                if (val == 'delete') {
                                  _handleDelete(
                                    context,
                                    doc.id,
                                    isExtra,
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    isExtra
                                        ? "Edit Booking"
                                        : "Reschedule",
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    isExtra
                                        ? "Delete Extra"
                                        : "Cancel for Today",
                                  ),
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

  Widget _buildTimeBox(String time, bool cancelled) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color:
            cancelled ? Colors.grey[200] : Colors.indigo[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cancelled
                ? Colors.grey
                : Colors.indigo[900],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "EXTRA",
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.orange[800],
        ),
      ),
    );
  }
}