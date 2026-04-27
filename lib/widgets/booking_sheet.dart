// booking_sheet.dart
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
  final String? originalLectureId;

  const BookingSheet({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.selectedDate,
    required this.selectedDay,
    this.editDocId,
    this.initialData,
    this.originalLectureId,
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

  bool _isSaving = false;

  final List<String> _timeSlots = [
    "08:00", "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00",
  ];

  final List<String> _years = ["FY", "SY", "TY", "BTech"];

  final List<String> _divisions = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "SEDA_A", "SEDA_B",
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    _isOnline = data?['isOnline'] ?? false;
    _selectedSubjectId = data?['subjectId'];
    _selectedResourceId = data?['resourceId'] == "ONLINE" ? null : data?['resourceId'];
    _selectedSlot = data?['startTime'] ?? "08:00";
    _selectedDiv = (data?['division'] ?? "A").replaceAll("Div ", "").replaceAll(" ", "_");
    _selectedBatch = data?['batch'] ?? "All";
    _selectedYear = data?['year'] ?? "TY";
  }

  String getSemester(String year) {
    switch (year) {
      case "FY": return "Sem 2";
      case "SY": return "Sem 4";
      case "TY": return "Sem 6";
      case "BTech": return "Sem 8";
      default: return "Sem";
    }
  }

  Future<void> _confirmBooking() async {
    if (_isSaving) return;

    if (_selectedSubjectId == null || (!_isOnline && _selectedResourceId == null)) {
      _showSnack("Please select subject and room", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentSem = getSemester(_selectedYear);

      final error = await _conflictHelper.checkAllConflicts(
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
        _showSnack(error, Colors.red);
        setState(() => _isSaving = false);
        return;
      }

      final subDoc = await _db.collection('subjects').doc(_selectedSubjectId).get();
      final subName = subDoc.data()?['name'] ?? "Lecture";
      String roomName = "ONLINE";

      if (!_isOnline && _selectedResourceId != null) {
        final rDoc = await _db.collection('resources').doc(_selectedResourceId).get();
        roomName = rDoc.data()?['currentRoomNo'] ?? _selectedResourceId!;
      }

      final startHour = int.parse(_selectedSlot.split(':')[0]);
      final endTime = "${(startHour + 1).toString().padLeft(2, '0')}:00";

      Map<String, dynamic> data = {
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
        'semester': currentSem,
        'activeSem': currentSem,
        'academicYear': "2025-26",
        'isOnline': _isOnline,
        'type': 'Extra',
        'originalLectureId': widget.originalLectureId,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (widget.editDocId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('extra_bookings').add(data);
      } else {
        await _db.collection('extra_bookings').doc(widget.editDocId).update(data);
      }

      if (widget.originalLectureId != null) {
        await _db.collection('cancelled_lectures').doc("${widget.originalLectureId}_${widget.selectedDate}").set({
          'lectureId': widget.originalLectureId,
          'date': widget.selectedDate,
        });
      }

      await NotificationService.send(
        title: "✨ Extra Lecture Added",
        body: "$subName for $_selectedYear Div $_selectedDiv at $_selectedSlot in $roomName.",
        topics: ["${_selectedYear}_Div_$_selectedDiv"],
        category: "Lecture Update",
        senderName: widget.teacherName,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            _buildTitle(),
            const SizedBox(height: 20),
            _buildToggleCard(),
            const SizedBox(height: 20),
            _buildYearDivRow(),
            const SizedBox(height: 18),
            _buildLabel("Select Subject"),
            
            _buildSubjectDropdown(),
            const SizedBox(height: 18),
            _buildLabel("Select Time Slot"),
            _buildTimeSlotGrid(),
            const SizedBox(height: 18),
            _buildLabel("Select Batch"),
            _buildGenericDropdown(
              _getBatchesForDiv(_selectedDiv),
              _selectedBatch,
              (v) => setState(() => _selectedBatch = v!),
            ),
            if (!_isOnline) ...[
              const SizedBox(height: 22),
              _buildLabel("Live Room Availability"),
              _buildLiveRoomMonitor(),
            ],
            const SizedBox(height: 28),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.editDocId == null ? "Book Extra Lecture" : "Edit Booking",
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.indigo.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isOnline ? Colors.indigo.shade100 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, color: _isOnline ? Colors.indigo : Colors.grey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Online Lecture", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Switch.adaptive(
            value: _isOnline,
            activeColor: Colors.indigo,
            onChanged: (v) {
              setState(() {
                _isOnline = v;
                if (v) _selectedResourceId = null;
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildYearDivRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Year"),
              _buildGenericDropdown(_years, _selectedYear, (v) => setState(() => _selectedYear = v!)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Division"),
              _buildGenericDropdown(_divisions, _selectedDiv, (v) => setState(() => _selectedDiv = v!)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('subjects').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        return DropdownButtonFormField<String>(
          isExpanded: true, 
          value: _selectedSubjectId,
          hint: const Text("Select Subject"),
          items: docs.map((e) => DropdownMenuItem(
            value: e.id, 
            child: Text(e['name'], overflow: TextOverflow.ellipsis)
          )).toList(),
          onChanged: (v) => setState(() => _selectedSubjectId = v),
          decoration: _inputDecoration(),
        );
      },
    );
  }

  Widget _buildTimeSlotGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _timeSlots.map((slot) {
        final isSel = _selectedSlot == slot;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedSlot = slot;
            _selectedResourceId = null; 
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? Colors.indigo : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSel ? Colors.indigo : Colors.grey.shade300),
            ),
            child: Text(
              slot,
              style: TextStyle(
                color: isSel ? Colors.white : Colors.black87,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveRoomMonitor() {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        _db.collection('resources').snapshots(),
        _db.collection('timetable')
            .where('day', isEqualTo: widget.selectedDay)
            .where('startTime', isEqualTo: _selectedSlot)
            .snapshots(),
        _db.collection('extra_bookings')
            .where('date', isEqualTo: widget.selectedDate)
            .where('startTime', isEqualTo: _selectedSlot)
            .snapshots(),
      ]),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: LinearProgressIndicator());

        final rooms = snap.data![0].docs;
        final masterOcc = snap.data![1].docs;
        final extraOcc = snap.data![2].docs;

        final Map<String, String> occupiedReasons = {};
        for (var d in masterOcc) { occupiedReasons[d['resourceId']] = "Regular: ${d['division']}"; }
        for (var d in extraOcc) {
          if (d.id != widget.editDocId) occupiedReasons[d['resourceId']] = "Booked: ${d['division']}";
        }

        return SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rooms.length,
            itemBuilder: (_, i) {
              final r = rooms[i];
              final reason = occupiedReasons[r.id];
              final busy = reason != null;
              final selected = _selectedResourceId == r.id;

              return GestureDetector(
                onTap: busy ? null : () => setState(() => _selectedResourceId = r.id),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12, bottom: 5),
                  decoration: BoxDecoration(
                    color: busy ? Colors.red.shade50 : selected ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: busy ? Colors.red : selected ? Colors.green : Colors.grey.shade300, width: selected ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(busy ? Icons.lock_outline : Icons.meeting_room_outlined, color: busy ? Colors.red : Colors.green),
                      const SizedBox(height: 6),
                      Text(r['currentRoomNo'] ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(busy ? reason : "Available", style: TextStyle(fontSize: 10, color: busy ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _confirmBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A237E), 
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("Confirm Final Booking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGenericDropdown(List<String> items, String current, Function(String?) onCh) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: items.contains(current) ? current : items.first,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onCh,
      decoration: _inputDecoration(),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    );
  }

  List<String> _getBatchesForDiv(String div) => ["All", "${div}1", "${div}2", "${div}3"];

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}