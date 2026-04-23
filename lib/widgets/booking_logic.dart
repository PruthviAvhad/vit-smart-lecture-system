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
  }) async {
    // 1. Fetch cancellations for today to allow "Recursive" availability
    var cancelSnap = await _db.collection('cancelled_lectures')
        .where('date', isEqualTo: selectedDate).get();
    final cancelledIds = cancelSnap.docs.map((d) => d['lectureId'] as String).toSet();

    // 2. TEACHER CONFLICT
    var tWeekly = await _db.collection('timetable')
        .where('teacherId', isEqualTo: teacherId)
        .where('day', isEqualTo: selectedDay)
        .where('startTime', isEqualTo: startTime).get();
    
    var tExtra = await _db.collection('extra_bookings')
        .where('teacherId', isEqualTo: teacherId)
        .where('date', isEqualTo: selectedDate)
        .where('startTime', isEqualTo: startTime).get();

    if (tWeekly.docs.any((d) => !cancelledIds.contains(d.id)) || 
        tExtra.docs.any((d) => d.id != editDocId)) {
      return "Conflict: You already have a lecture at $startTime";
    }

    // 3. STUDENT/CLASS CONFLICT
    var sWeekly = await _db.collection('timetable')
        .where('division', isEqualTo: division)
        .where('day', isEqualTo: selectedDay)
        .where('startTime', isEqualTo: startTime).get();

    var sExtra = await _db.collection('extra_bookings')
        .where('division', isEqualTo: division)
        .where('date', isEqualTo: selectedDate)
        .where('startTime', isEqualTo: startTime).get();

    List<QueryDocumentSnapshot> allStudents = [...sWeekly.docs, ...sExtra.docs];
    for (var doc in allStudents) {
      if (doc.id == editDocId || cancelledIds.contains(doc.id)) continue;
      String existingBatch = doc['batch'] ?? "All";
      if (existingBatch == "All" || batch == "All" || existingBatch == batch) {
        return "Conflict: Div $division ($batch) is busy at $startTime";
      }
    }

    // 4. ROOM CONFLICT
    if (!isOnline && resourceId != null) {
      var rWeekly = await _db.collection('timetable')
          .where('resourceId', isEqualTo: resourceId)
          .where('day', isEqualTo: selectedDay)
          .where('startTime', isEqualTo: startTime).get();

      var rExtra = await _db.collection('extra_bookings')
          .where('resourceId', isEqualTo: resourceId)
          .where('date', isEqualTo: selectedDate)
          .where('startTime', isEqualTo: startTime).get();

      if (rWeekly.docs.any((d) => !cancelledIds.contains(d.id)) || 
          rExtra.docs.any((d) => d.id != editDocId)) {
        return "Conflict: This room is already occupied.";
      }
    }
    return null;
  }
}