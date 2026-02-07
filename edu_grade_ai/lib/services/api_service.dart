import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _pcIp =
      "192.168.1.5"; // Change to your server IP if needed

  String get baseUrl {
    // Tất cả các môi trường đều phải trỏ về link Render kèm /api
    const String prodUrl = "https://edugrade-ai.onrender.com/api";

    if (kIsWeb) {
      return prodUrl;
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return prodUrl;
      }
    } catch (e) {
      // Tránh lỗi khi chạy trên các nền tảng không hỗ trợ dart:io
    }

    return prodUrl;
  }

  Map<String, String> get headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  // --- AUTH ---

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"username": username.trim(), "password": password}),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) return data;

      // Trả về data nếu yêu cầu xác thực Firebase (để UI xử lý)
      if (data['require_firebase_auth'] == true) return data;

      throw data['detail'] ?? "Đăng nhập thất bại";
    } catch (e) {
      if (e is String) rethrow;
      throw "Lỗi kết nối: $e";
    }
  }

  Future<Map<String, dynamic>> loginWithFirebase(String idToken) async {
    final url = Uri.parse('$baseUrl/auth/login-firebase');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"id_token": idToken}),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) return data;
      throw data['detail'] ?? "Xác thực Admin thất bại";
    } catch (e) {
      throw "Lỗi kết nối Admin: $e";
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
    String? classId,
    String role = "student",
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "username": username.trim(),
          "password": password,
          "fullName": fullName.trim(),
          "role": role,
          "classId": classId != null ? classId.toUpperCase().trim() : "",
        }),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) return data;
      throw data['detail'] ?? "Đăng ký thất bại";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<bool> checkUsernameExists(String username) async {
    final url = Uri.parse('$baseUrl/auth/check-username');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"username": username.trim()}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> updatePassword(String username, String newPassword) async {
    final url = Uri.parse('$baseUrl/auth/password/update');
    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({"username": username, "newPassword": newPassword}),
      );
      if (response.statusCode != 200) throw "Lỗi cập nhật mật khẩu";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  // --- USERS ---

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final url = Uri.parse('$baseUrl/users/$uid');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String uid,
    String? day,
    String? month,
    String? year,
    String? department,
  }) async {
    final url = Uri.parse('$baseUrl/users/$uid');
    String? birthDateIso;
    if (day != null && month != null && year != null) {
      birthDateIso = DateTime(
        int.parse(year),
        int.parse(month),
        int.parse(day),
      ).toIso8601String();
    }
    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({
          if (birthDateIso != null) "birthDate": birthDateIso,
          if (department != null) "department": department,
        }),
      );
      if (response.statusCode != 200) throw "Lỗi cập nhật profile";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<List<dynamic>> getTeachers() async {
    final url = Uri.parse('$baseUrl/users/teachers/list');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['teachers'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteUser(String uid) async {
    final url = Uri.parse('$baseUrl/users/$uid');
    try {
      final response = await http.delete(url, headers: headers);
      if (response.statusCode != 200) throw "Lỗi xóa người dùng";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  // --- CLASSES ---

  Future<List<dynamic>> getClasses(String semester) async {
    final url = Uri.parse('$baseUrl/classes/list/$semester');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['classes'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getClassesByTeacher(String teacherName) async {
    final url = Uri.parse('$baseUrl/classes/by-teacher/$teacherName');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['classes'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> createClass(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/classes/');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode != 200) throw "Lỗi tạo lớp";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<void> updateClass(String id, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/classes/$id');
    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode != 200) throw "Lỗi cập nhật lớp";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<void> deleteClass(String id) async {
    final url = Uri.parse('$baseUrl/classes/$id');
    try {
      final response = await http.delete(url, headers: headers);
      if (response.statusCode != 200) throw "Lỗi xóa lớp";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<void> registerClass({
    required String userId,
    required String classId,
    required String semester,
    required bool isRegister,
  }) async {
    final url = Uri.parse('$baseUrl/classes/register');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "userId": userId,
          "classId": classId,
          "semester": semester,
          "isRegister": isRegister,
        }),
      );
      if (response.statusCode != 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        throw data['detail'] ?? "Lỗi đăng ký lớp (${response.statusCode})";
      }
    } catch (e) {
      if (e is String) rethrow;
      throw "Lỗi kết nối: $e";
    }
  }

  Future<List<dynamic>> getStudentsInClass(String classId) async {
    final url = Uri.parse('$baseUrl/classes/$classId/students');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['students'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- EXAMS ---

  Future<List<dynamic>> getAllExams() async {
    final url = Uri.parse('$baseUrl/exams/list');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['exams'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getExamsBySubject(String subject) async {
    final url = Uri.parse('$baseUrl/exams/by-subject/$subject');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['exams'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> createExam(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/exams/');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode != 200) throw "Lỗi lưu đề thi";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<Map<String, dynamic>?> getExamDetail(String examId) async {
    final url = Uri.parse('$baseUrl/exams/$examId');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['exam'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> submitExamResult(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/exams/results');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode != 200) throw "Lỗi nộp bài";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<List<dynamic>> getExamResults({
    String? studentId,
    String? examId,
    String? teacherName,
  }) async {
    Uri url;
    if (studentId != null) {
      url = Uri.parse('$baseUrl/exams/results/by-student/$studentId');
    } else if (examId != null) {
      url = Uri.parse('$baseUrl/exams/results/by-exam/$examId');
    } else {
      String query = "";
      if (teacherName != null && teacherName.isNotEmpty) {
        query = "?teacher_name=$teacherName";
      }
      url = Uri.parse('$baseUrl/exams/results/list/all$query');
    }
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['results'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteExamResult(String id) async {
    final url = Uri.parse('$baseUrl/exams/results/$id');
    try {
      final response = await http.delete(url, headers: headers);
      if (response.statusCode != 200) throw "Lỗi xóa kết quả";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  // --- SETTINGS ---

  Future<Map<String, dynamic>> getDashboardStats() async {
    final url = Uri.parse('$baseUrl/settings/dashboard-stats');
    try {
      final response = await http.get(url, headers: headers);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) return data['stats'] ?? {};
      throw data['detail'] ?? "Lỗi thống kê";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<Map<String, dynamic>?> getRegistrationSettings(String semester) async {
    final url = Uri.parse('$baseUrl/settings/registration/$semester');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['settings'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateRegistrationSettings(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/settings/registration');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode != 200) throw "Lỗi cập nhật cấu hình";
    } catch (e) {
      throw "Lỗi kết nối: $e";
    }
  }

  Future<List<dynamic>> getAllSemesters() async {
    final url = Uri.parse('$baseUrl/settings/semesters');
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['semesters'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

final apiService = ApiService();
