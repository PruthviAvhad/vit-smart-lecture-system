import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class StudentScheduleList extends StatelessWidget {
  final String year;
  final String division;
  final String batch;
  final String dayName;
  final String dateString;
  final bool isBatchWise; 

  const StudentScheduleList({
    super.key,
    required this.year,
    required this.division,
    required this.batch,
    required this.dayName,
    required this.dateString,
    required this.isBatchWise, 
  });

  
  Future<String> _getSubjectName(String id) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('subjects').doc(id).get();
      return doc.data()?['name'] ?? id;
    } catch (e) {
      return id;
    }
  }


  Future<String> _getRoomName(String id) async {
    if (id.toUpperCase() == "ONLINE") return "Online Class";
    try {
      var doc = await FirebaseFirestore.instance.collection('resources').doc(id).get();
      return doc.data()?['currentRoomNo']?.toString() ?? id;
    } catch (e) {
      return id;
    }
  }

  
  Future<String> _getTeacherName(String id) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .where('officialId', isEqualTo: id)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data()['name'] ?? id;
      }
      return id;
    } catch (e) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
     
        db.collection('timetable')
            .where('year', isEqualTo: year)
            .where('division', isEqualTo: division)
            .where('day', isEqualTo: dayName).snapshots(),
       
        db.collection('extra_bookings')
            .where('year', isEqualTo: year)
            .where('division', isEqualTo: division)
            .where('date', isEqualTo: dateString).snapshots(),
     
        db.collection('cancelled_lectures')
            .where('date', isEqualTo: dateString).snapshots(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) return const Center(child: Text("Error loading schedule."));

        final cancelledIds = snapshot.data![2].docs.map((d) => d['lectureId']).toSet();

     
        final allSlots = [...snapshot.data![0].docs, ...snapshot.data![1].docs]
            .where((doc) => !cancelledIds.contains(doc.id))
            .where((doc) {
             
              if (!isBatchWise) return true;
              
             
              String b = doc['batch'] ?? "All";
              return b == "All" || b == batch;
            }).toList();

        allSlots.sort((a, b) => (a['startTime'] ?? "").compareTo(b['startTime'] ?? ""));

        if (allSlots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available_rounded, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("No lectures for $dayName", 
                  style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: allSlots.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            var data = allSlots[index].data() as Map<String, dynamic>;
            bool isExtra = data.containsKey('type') && data['type'] == 'Extra';
            bool isPersonalBatch = (data['batch'] == "All" || data['batch'] == batch);

            return FutureBuilder<List<String>>(
              future: Future.wait([
                _getSubjectName(data['subjectId'] ?? ""),
                _getRoomName(data['resourceId'] ?? ""),
                _getTeacherName(data['teacherId'] ?? ""), 
              ]),
              builder: (context, nameSnap) {
                String subName = nameSnap.data?[0] ?? "Loading...";
                String roomName = nameSnap.data?[1] ?? "...";
                String teacherName = nameSnap.data?[2] ?? "...";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  
                    border: (!isBatchWise && !isPersonalBatch) 
                        ? Border.all(color: Colors.grey.shade200) 
                        : null,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  child: Opacity(
              
                    opacity: (!isBatchWise && !isPersonalBatch) ? 0.5 : 1.0,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 55,
                        decoration: BoxDecoration(
                          color: isExtra ? Colors.orange[50] : Colors.indigo[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(data['startTime'] ?? "--", 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: isExtra ? Colors.orange[900] : Colors.indigo[900]
                            )),
                        ),
                      ),
                      title: Text(subName, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("👨‍🏫 $teacherName", 
                            style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w500, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text("📍 $roomName | 🏷️ Batch: ${data['batch']}", 
                            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                      trailing: isExtra ? _buildExtraBadge() : null,
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

  Widget _buildExtraBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[100], 
        borderRadius: BorderRadius.circular(6)
      ),
      child: const Text("EXTRA", 
        style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}