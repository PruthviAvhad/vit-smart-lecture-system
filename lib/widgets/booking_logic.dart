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
    
    var cancelSnap = await _db.collection('cancelled_lectures')
        .where('date', isEqualTo: selectedDate).get();
    final cancelledIds = cancelSnap.docs.map((d) => d['lectureId'] as String).toSet();

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

    if (tWeekly.docs.any((d) => !cancelledIds.contains(d.id)) || 
        tExtra.docs.any((d) => d.id != editDocId)) {
      return "Conflict: You already have a lecture scheduled at $startTime";
    }

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
      
      if (existingBatch == "All" || batch == "All" || existingBatch == batch) {
        return "Conflict: Div $division ($existingBatch) is already busy at $startTime";
      }
    }

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

    return null;
  }
}