
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingConflictHelper {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String?> checkAllConflicts({
    required String teacherId,
    required String selectedDate,
    required String selectedDay,
    required String startTime,
    required String division,
    required String batch,
    required String? resourceId,
    required bool isOnline,
    required String? editDocId,
    required String activeSem,
  }) async {
    try {

      final cancelSnap = await _db
          .collection('cancelled_lectures')
          .where('date', isEqualTo: selectedDate)
          .get();

      final cancelledIds =
          cancelSnap.docs.map((d) => d['lectureId'].toString()).toSet();

    
      final teacherRegular = await _db
          .collection('timetable')
          .where('teacherId', isEqualTo: teacherId)
          .where('semester', isEqualTo: activeSem)
          .where('day', isEqualTo: selectedDay)
          .where('startTime', isEqualTo: startTime)
          .get();

      for (var d in teacherRegular.docs) {
        if (!cancelledIds.contains(d.id)) {
          return "You already have regular lecture at $startTime";
        }
      }

      final teacherExtra = await _db
          .collection('extra_bookings')
          .where('teacherId', isEqualTo: teacherId)
          .where('date', isEqualTo: selectedDate)
          .where('startTime', isEqualTo: startTime)
          .get();

      for (var d in teacherExtra.docs) {
        if (d.id != editDocId) {
          return "You already booked another lecture at $startTime";
        }
      }

   

      final divRegular = await _db
          .collection('timetable')
          .where('semester', isEqualTo: activeSem)
          .where('division', isEqualTo: division)
          .where('day', isEqualTo: selectedDay)
          .where('startTime', isEqualTo: startTime)
          .get();

      final divExtra = await _db
          .collection('extra_bookings')
          .where('semester', isEqualTo: activeSem)
          .where('division', isEqualTo: division)
          .where('date', isEqualTo: selectedDate)
          .where('startTime', isEqualTo: startTime)
          .get();

      final allDivisionDocs = [
        ...divRegular.docs,
        ...divExtra.docs,
      ];

      for (var d in allDivisionDocs) {
        if (d.id == editDocId) continue;
        if (cancelledIds.contains(d.id)) continue;

        final map = d.data() as Map<String, dynamic>;
        String oldBatch = map['batch'] ?? "All";

        if (oldBatch == "All" ||
            batch == "All" ||
            oldBatch == batch) {
          return "Division already busy at $startTime";
        }
      }

   
      if (!isOnline && resourceId != null) {
        final roomRegular = await _db
            .collection('timetable')
            .where('semester', isEqualTo: activeSem)
            .where('resourceId', isEqualTo: resourceId)
            .where('day', isEqualTo: selectedDay)
            .where('startTime', isEqualTo: startTime)
            .get();

        final roomExtra = await _db
            .collection('extra_bookings')
            .where('resourceId', isEqualTo: resourceId)
            .where('date', isEqualTo: selectedDate)
            .where('startTime', isEqualTo: startTime)
            .get();

        final allRoomDocs = [
          ...roomRegular.docs,
          ...roomExtra.docs,
        ];

        for (var d in allRoomDocs) {
          if (d.id == editDocId) continue;
          if (cancelledIds.contains(d.id)) continue;

          return "Room already occupied at $startTime";
        }
      }

      return null;
    } catch (e) {
      return "Conflict check failed";
    }
  }
}