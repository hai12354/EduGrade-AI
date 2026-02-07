// REMOVED: import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String uid;
  final String fullName;
  final String username;
  final String? classId;
  final String role;
  final String? department;
  final String? dateOfBirth; // Đổi từ Timestamp sang String (ISO8601)
  final List<String> registeredClassIds; // NEW: support multiple classes
  // BỔ SUNG: Danh sách các môn học học sinh đang theo học
  final List<String>? subjects;

  StudentModel({
    required this.uid,
    required this.fullName,
    required this.username,
    this.classId,
    required this.role,
    this.department,
    this.dateOfBirth,
    this.subjects,
    this.registeredClassIds = const [], // Default empty list
  });

  // 1. Chuyển từ Map (Firestore) sang Object (Dart)
  factory StudentModel.fromMap(Map<String, dynamic> data, String id) {
    // Xử lý dateOfBirth (có thể là String ISO hoặc Timestamp cũ)
    String? dobString;
    if (data['dateOfBirth'] is String) {
      dobString = data['dateOfBirth'];
    } else if (data['dateOfBirth'] != null) {
      // Nếu là Timestamp Firestore (chỉ gặp khi check cache hoặc mock)
      // Chuyển về ISO-8601 để đồng bộ
      try {
        dobString = data['dateOfBirth'].toDate().toIso8601String();
      } catch (_) {
        dobString = data['dateOfBirth'].toString();
      }
    }

    // List of classes
    List<String> registeredIds = [];
    if (data['registeredClassIds'] is List) {
      registeredIds = List<String>.from(data['registeredClassIds']);
    } else if (data['classId'] != null &&
        data['classId'].toString().isNotEmpty) {
      // Legacy migration
      registeredIds = [data['classId'].toString()];
    }

    return StudentModel(
      uid: id,
      fullName: data['fullName']?.toString() ?? 'N/A',
      username: data['username']?.toString() ?? '',
      classId: data['classId']?.toString(),
      role: data['role']?.toString() ?? 'student',
      department: data['department']?.toString(),
      dateOfBirth: dobString,
      registeredClassIds: registeredIds,
      subjects: data['subjects'] is List
          ? List<String>.from(data['subjects'])
          : [],
    );
  }

  // 2. Chuyển từ Object sang Map để ghi ngược lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'username': username,
      'classId': classId,
      'role': role,
      'department': department,
      'dateOfBirth': dateOfBirth,
      'subjects': subjects,
      'registeredClassIds': registeredClassIds,
    };
  }

  // 3. Hàm copyWith để cập nhật dữ liệu linh hoạt
  StudentModel copyWith({
    String? fullName,
    String? username,
    String? classId,
    String? role,
    String? department,
    String? dateOfBirth,
    List<String>? subjects,
    List<String>? registeredClassIds,
  }) {
    return StudentModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      classId: classId ?? this.classId,
      role: role ?? this.role,
      department: department ?? this.department,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      subjects: subjects ?? this.subjects,
      registeredClassIds: registeredClassIds ?? this.registeredClassIds,
    );
  }
}
