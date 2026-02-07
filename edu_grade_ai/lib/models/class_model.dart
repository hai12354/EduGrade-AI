// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String classId;
  final String className;
  final String teacherName;
  final int maxSlots;
  final int currentSlots;
  final String dayOfWeek;
  final String periods;
  final String room;
  final String dateRange;
  final String semester; // THÊM TRƯỜNG NÀY

  ClassModel({
    required this.classId,
    required this.className,
    required this.teacherName,
    required this.maxSlots,
    required this.currentSlots,
    required this.dayOfWeek,
    required this.periods,
    required this.room,
    required this.dateRange,
    required this.semester, // THÊM TRƯỜNG NÀY
  });

  String get schedule => "$dayOfWeek | $periods | $room | $dateRange";

  factory ClassModel.fromMap(Map<String, dynamic> data) {
    String rawSchedule = data['schedule'] ?? '';
    List<String> parts = rawSchedule.split('|');

    return ClassModel(
      classId: data['classId'] ?? '',
      // Backend returns 'name', Firestore returned 'className'
      className: data['name'] ?? data['className'] ?? 'N/A',
      // Backend returns 'teacher', Firestore returned 'teacherName'
      teacherName: data['teacher'] ?? data['teacherName'] ?? 'Chưa phân công',
      maxSlots: (data['maxSlots'] as num?)?.toInt() ?? 0,
      currentSlots: (data['currentSlots'] as num?)?.toInt() ?? 0,
      dayOfWeek:
          data['dayOfWeek'] ?? (parts.isNotEmpty ? parts[0].trim() : 'N/A'),
      periods: data['periods'] ?? (parts.length > 1 ? parts[1].trim() : 'N/A'),
      room: data['room'] ?? (parts.length > 2 ? parts[2].trim() : 'N/A'),
      dateRange:
          data['dateRange'] ?? (parts.length > 3 ? parts[3].trim() : 'N/A'),
      semester: data['semester'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'name': className, // Backend expects 'name'
      'className': className, // Keep for legacy/UI
      'teacher': teacherName, // Backend expects 'teacher'
      'teacherName': teacherName,
      'maxSlots': maxSlots,
      'currentSlots': currentSlots,
      'dayOfWeek': dayOfWeek,
      'periods': periods,
      'room': room,
      'dateRange': dateRange,
      'schedule': schedule, // Send constructed schedule string
      'semester': semester,
    };
  }

  bool get isFull => currentSlots >= maxSlots;
}
