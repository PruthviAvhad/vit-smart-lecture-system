import 'package:cloud_firestore/cloud_firestore.dart';

class BookingConflictHelper {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String?> checkAllConflicts({
    required String teacherId,
    required String selectedDate, // Format: yyyy-MM-dd
    required String selectedDay,  // Format: Monday
    required String startTime,    // Format: 09:00
    required String division,
    required String batch,        // "All", "B1", "B2", etc.
    required String? resourceId,  // The Room/Lab ID
    required bool isOnline,
    required String? editDocId,   // The ID of the current doc if editing
    required String activeSem,    // e.g., "SEM_6_2026"
  }) async {
    
    // 1. Fetch cancellations for this specific date
    // We check this so that if a regular lecture was cancelled, 
    // the slot becomes "available" for an extra booking.
    var cancelSnap = await _db.collection('cancelled_lectures')
        .where('date', isEqualTo: selectedDate).get();
    final cancelledIds = cancelSnap.docs.map((d) => d['lectureId'] as String).toSet();

    // --- 2. TEACHER CONFLICT CHECK ---
    // Check if the teacher is already teaching somewhere else at this time
    var tWeekly = await _db.collection('timetable')
        .where('activeSem', isEqualTo: activeSem)
        .where('teacherId', isEqualTo: teacherId)
        .where('day', isEqualTo: selectedDay)
        .where('startTime', isEqualTo: startTime).get();
    
    var tExtra = await _db.collection('extra_bookings')
        .where('activeSem', isEqualTo: activeSem)
        .where('teacherId', isEqualTo: teacherId)
        .where('date', isEqualTo: selectedDate)
        .where('startTime', isEqualTo: startTime).get();

    // Validation: Ignore the record if it was cancelled or if it's the one we are currently editing
    if (tWeekly.docs.any((d) => !cancelledIds.contains(d.id)) || 
        tExtra.docs.any((d) => d.id != editDocId)) {
      return "Conflict: You already have a lecture scheduled at $startTime";
    }

    // --- 3. STUDENT/CLASS CONFLICT CHECK ---
    // Check if the division/batch is already busy
    var sWeekly = await _db.collection('timetable')
        .where('activeSem', isEqualTo: activeSem)
        .where('division', isEqualTo: division)
        .where('day', isEqualTo: selectedDay)
        .where('startTime', isEqualTo: startTime).get();

    var sExtra = await _db.collection('extra_bookings')
        .where('activeSem', isEqualTo: activeSem)
        .where('division', isEqualTo: division)
        .where('date', isEqualTo: selectedDate)
        .where('startTime', isEqualTo: startTime).get();

    List<QueryDocumentSnapshot> allStudentDocs = [...sWeekly.docs, ...sExtra.docs];
    
    for (var doc in allStudentDocs) {
      if (doc.id == editDocId || cancelledIds.contains(doc.id)) continue;
      
      String existingBatch = doc['batch'] ?? "All";
      
      // Logic: If existing is "All", the whole div is busy. 
      // If current is "All", it clashes with any specific batch (B1, B2).
      if (existingBatch == "All" || batch == "All" || existingBatch == batch) {
        return "Conflict: Div $division ($existingBatch) is already busy at $startTime";
      }
    }

    // --- 4. RESOURCE (ROOM/LAB) CONFLICT CHECK ---
    // Only check if it's an offline lecture and a resource is selected
    if (!isOnline && resourceId != null && resourceId.isNotEmpty) {
      var rWeekly = await _db.collection('timetable')
          .where('activeSem', isEqualTo: activeSem)
          .where('resourceId', isEqualTo: resourceId)
          .where('day', isEqualTo: selectedDay)
          .where('startTime', isEqualTo: startTime).get();

      var rExtra = await _db.collection('extra_bookings')
          .where('activeSem', isEqualTo: activeSem)
          .where('resourceId', isEqualTo: resourceId)
          .where('date', isEqualTo: selectedDate)
          .where('startTime', isEqualTo: startTime).get();

      if (rWeekly.docs.any((d) => !cancelledIds.contains(d.id)) || 
          rExtra.docs.any((d) => d.id != editDocId)) {
        return "Conflict: Room $resourceId is already occupied at this time.";
      }
    }

    // If we reached here, no conflicts were found!
    return null;
  }
}