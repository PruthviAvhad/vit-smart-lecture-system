import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../services/notification_service.dart';
import 'booking_logic.dart';

class BookingSheet extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String selectedDate;
  final String selectedDay;
  final String? editDocId;
  final Map<String, dynamic>? initialData;

  const BookingSheet({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.selectedDate,
    required this.selectedDay,
    this.editDocId,
    this.initialData,
  });

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BookingConflictHelper _conflictHelper = BookingConflictHelper();

  late bool _isOnline;
  String? _selectedSubjectId;
  String? _selectedResourceId;
  late String _selectedSlot;
  late String _selectedDiv;
  late String _selectedBatch;
  late String _selectedYear;

  final List<String> _timeSlots = ["08:00", "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00"];
  final List<String> _years = ["FY", "SY", "TY", "BTech"];
  final List<String> _divisions = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "SEDA_A", "SEDA_B"];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _isOnline = data?['isOnline'] ?? false;
    _selectedSubjectId = data?['subjectId'];
    _selectedResourceId = data?['resourceId'];
    _selectedSlot = data?['startTime'] ?? "08:00";
    _selectedDiv = (data?['division'] ?? "A").replaceAll("Div ", "").replaceAll(" ", "_");
    _selectedBatch = data?['batch'] ?? "All";
    _selectedYear = data?['year'] ?? "TY";
  }

  Future<void> _confirmBooking() async {
    if (_selectedSubjectId == null || (!_isOnline && _selectedResourceId == null)) {
      _showSnack("Please select subject and room", Colors.orange);
      return;
    }

    String currentSem = _selectedYear == "SY" ? "Sem 6" : "Academic Sem";
    String? error = await _conflictHelper.checkAllConflicts(
      teacherId: widget.teacherId,
      selectedDate: widget.selectedDate,
      selectedDay: widget.selectedDay,
      startTime: _selectedSlot,
      division: _selectedDiv,
      batch: _selectedBatch,
      resourceId: _selectedResourceId,
      isOnline: _isOnline,
      editDocId: widget.editDocId,
      activeSem: currentSem, 
    );

    if (error != null) {
      _showSnack(error, Colors.red[800]);
      return;
    }

    try {
      String teacherTopicId = widget.teacherId;
      var tDoc = await _db.collection('users').doc(widget.teacherId).get();
      if (tDoc.exists) {
        final tData = tDoc.data();
        if (tData != null && tData.containsKey('officialId')) {
          teacherTopicId = tData['officialId'].toString();
        }
      }

      var sDoc = await _db.collection('subjects').doc(_selectedSubjectId).get();
      String subName = sDoc.data()?['name'] ?? "Lecture";

      String roomName = _isOnline ? "Online" : "Classroom";
      if (!_isOnline && _selectedResourceId != null) {
        var rDoc = await _db.collection('resources').doc(_selectedResourceId).get();
        roomName = rDoc.data()?['currentRoomNo'] ?? _selectedResourceId!;
      }

      int startH = int.parse(_selectedSlot.split(':')[0]);
      String endTime = "${(startH + 1).toString().padLeft(2, '0')}:00";

      final bookingData = {
        'teacherId': widget.teacherId,
        'teacherName': widget.teacherName,
        'subjectId': _selectedSubjectId,
        'resourceId': _isOnline ? "ONLINE" : _selectedResourceId,
        'startTime': _selectedSlot,
        'endTime': endTime,
        'date': widget.selectedDate,
        'day': widget.selectedDay,
        'division': _selectedDiv,
        'batch': _selectedBatch,
        'year': _selectedYear,
        'isOnline': _isOnline,
        'type': 'Extra',
        'semester': currentSem,
        'academicYear': "2025-26",
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (widget.editDocId == null) {
        bookingData['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('extra_bookings').add(bookingData);
      } else {
        await _db.collection('extra_bookings').doc(widget.editDocId).update(bookingData);
      }

      await NotificationService.send(
        title: "✨ Extra Lecture Added",
        body: "$subName for $_selectedYear Div $_selectedDiv at $_selectedSlot in $roomName.",
        topics: ["${_selectedYear}_Div_$_selectedDiv"], 
        category: "Lecture Update",
        senderName: widget.teacherName,
      );

      await NotificationService.send(
        title: "📅 Booking Confirmed",
        body: "Successfully booked $subName for Div $_selectedDiv.",
        topics: ["Teacher_$teacherTopicId"],
        category: "System",
        senderName: "Academic Portal",
      );

      if (mounted) {
        Navigator.pop(context);
        _showSnack("Slot confirmed and students notified!", Colors.green[800]);
      }
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildDragHandle(),
          _buildTitle(),
          const SizedBox(height: 20),
          _buildToggleCard(),
          const SizedBox(height: 20),
          _buildYearDivRow(),
          const SizedBox(height: 20),
          _buildLabel("Select Subject"),
          _buildSubjectDropdown(),
          const SizedBox(height: 20),
          _buildLabel("Select Time Slot (1 Hour)"),
          _buildTimeSlotGrid(),
          const SizedBox(height: 20),
          _buildLabel("Batch Selection"),
          _buildGenericDropdown(_getBatchesForDiv(_selectedDiv), _selectedBatch,
              (v) => setState(() => _selectedBatch = v!)),
          if (!_isOnline) ...[
            const SizedBox(height: 25),
            _buildLabel("Live Room Monitor (Today)"),
            _buildLiveRoomMonitor(),
          ],
          const SizedBox(height: 30),
          _buildConfirmButton(),
        ]),
      ),
    );
  }

  Widget _buildLiveRoomMonitor() {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        _db.collection('resources').snapshots(),
        _db.collection('timetable').where('day', isEqualTo: widget.selectedDay).where('startTime', isEqualTo: _selectedSlot).snapshots(),
        _db.collection('extra_bookings').where('date', isEqualTo: widget.selectedDate).where('startTime', isEqualTo: _selectedSlot).snapshots(),
        _db.collection('cancelled_lectures').where('date', isEqualTo: widget.selectedDate).snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final rooms = snapshot.data![0].docs;
        final cancelledIds = snapshot.data![3].docs.map((d) => d['lectureId']).toSet();

        Map<String, String> occupied = {};
        for (var d in snapshot.data![1].docs) {
          if (!cancelledIds.contains(d.id)) occupied[d['resourceId']] = d['division'];
        }
        for (var d in snapshot.data![2].docs) {
          if (d.id != widget.editDocId) occupied[d['resourceId']] = d['division'];
        }

        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              var r = rooms[i];
              bool isOcc = occupied.containsKey(r.id);
              bool isSel = _selectedResourceId == r.id;
              return _buildRoomCard(r['currentRoomNo']?.toString() ?? r.id, r.id, isOcc, isSel, occupied[r.id]);
            },
          ),
        );
      },
    );
  }

  Widget _buildRoomCard(String name, String id, bool isOcc, bool isSel, String? div) {
    return GestureDetector(
      onTap: isOcc ? null : () => setState(() => _selectedResourceId = id),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isOcc ? Colors.red[50] : (isSel ? Colors.indigo[50] : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOcc ? Colors.red : (isSel ? Colors.indigo : Colors.grey[300]!), width: isSel ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isOcc ? Icons.lock : Icons.meeting_room, color: isOcc ? Colors.red : (isSel ? Colors.indigo : Colors.green), size: 20),
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSel ? Colors.indigo : Colors.black87)),
          Text(isOcc ? "By Div $div" : "Available", style: TextStyle(fontSize: 10, color: isOcc ? Colors.red[800] : Colors.green[700])),
        ]),
      ),
    );
  }

  Widget _buildTimeSlotGrid() {
    return Wrap(
        spacing: 8,
        children: _timeSlots.map((slot) {
          bool isSel = _selectedSlot == slot;
          return ChoiceChip(
            label: Text(slot),
            selected: isSel,
            onSelected: (selected) {
              if (selected) setState(() {
                _selectedSlot = slot;
                _selectedResourceId = null;
              });
            },
            selectedColor: Colors.indigo,
            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
          );
        }).toList());
  }

  Widget _buildSubjectDropdown() => StreamBuilder<QuerySnapshot>(
        stream: _db.collection('subjects').snapshots(),
        builder: (context, snap) {
          var items = snap.data?.docs.map((d) => d['name'] as String).toList() ?? [];
          String? currentName;
          if (_selectedSubjectId != null && snap.hasData) {
            try {
              currentName = snap.data!.docs.firstWhere((d) => d.id == _selectedSubjectId)['name'];
            } catch (_) {}
          }
          return _buildGenericDropdown(items, currentName ?? "", (v) {
            final doc = snap.data?.docs.firstWhere((d) => d['name'] == v);
            setState(() => _selectedSubjectId = doc?.id);
          });
        },
      );

  Widget _buildYearDivRow() => Row(children: [
        Expanded(child: _buildGenericDropdown(_years, _selectedYear, (v) => setState(() => _selectedYear = v!))),
        const SizedBox(width: 15),
        Expanded(child: _buildGenericDropdown(_divisions.map((e) => "Div $e").toList(), "Div $_selectedDiv", (v) => setState(() => _selectedDiv = v!.replaceAll("Div ", "").replaceAll(" ", "_")))),
      ]);

  List<String> _getBatchesForDiv(String div) => ["All", "${div}1", "${div}2", "${div}3"];
  
  Widget _buildDragHandle() => Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))));
  
  Widget _buildTitle() => Text(widget.editDocId != null ? "Modify Booking" : "Book Extra Class", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  
  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.bold)));
  
  Widget _buildToggleCard() => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(Icons.video_call, color: Colors.indigo, size: 24), SizedBox(width: 8), Text("Online Mode", style: TextStyle(fontWeight: FontWeight.bold))]), Switch(value: _isOnline, activeColor: Colors.indigo, onChanged: (v) => setState(() => _isOnline = v))]));
  
  Widget _buildConfirmButton() => SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _confirmBooking, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Confirm Final Booking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
  
  void _showSnack(String msg, Color? bg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating));

  Widget _buildGenericDropdown(List<String> items, String current, Function(String?) onCh) => DropdownButtonFormField<String>(
        value: items.contains(current) ? current : (items.isNotEmpty ? items.first : null),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onCh,
        decoration: InputDecoration(filled: true, fillColor: Colors.grey[50], contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!))),
      );
}