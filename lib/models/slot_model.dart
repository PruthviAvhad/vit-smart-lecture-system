class Slot {
  final String id;
  final String timetableId;
  final String year;
  final String division;
  final String batch;
  final String room;
  final String teacherId;
  final String subject;
  final String startTime;
  final String endTime;
  final String day;
  final String type;

  Slot({
    required this.id, required this.timetableId, required this.year,
    required this.division, required this.batch, required this.room,
    required this.teacherId, required this.subject, required this.startTime,
    required this.endTime, required this.day, required this.type,
  });

  factory Slot.fromMap(Map<String, dynamic> data, String docId) {
    return Slot(
      id: docId,
      timetableId: data['timetableId'] ?? '',
      year: data['year'] ?? '',
      division: data['division'] ?? '',
      batch: data['batch'] ?? 'All',
      room: data['room'] ?? '',
      teacherId: data['teacherId'] ?? '',
      subject: data['subject'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      day: data['day'] ?? '',
      type: data['type'] ?? 'Regular',
    );
  }

  Map<String, dynamic> toMap() => {
    'timetableId': timetableId,
    'year': year,
    'division': division,
    'batch': batch,
    'room': room,
    'teacherId': teacherId,
    'subject': subject,
    'startTime': startTime,
    'endTime': endTime,
    'day': day,
    'type': type,
  };
}