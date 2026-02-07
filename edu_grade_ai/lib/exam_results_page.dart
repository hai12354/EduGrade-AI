import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as exc;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'services/api_service.dart';

class ExamResultsPage extends StatefulWidget {
  final String role;
  final String uid;

  const ExamResultsPage({super.key, required this.role, required this.uid});

  @override
  State<ExamResultsPage> createState() => _ExamResultsPageState();
}

class _EduResultData {
  final String id;
  final String examTitle;
  final String studentName;
  final String studentId;
  final double score;
  final int totalQuestions;
  final String submittedAt;
  final String? birthDate;
  final String? department;

  _EduResultData({
    required this.id,
    required this.examTitle,
    required this.studentName,
    required this.studentId,
    required this.score,
    required this.totalQuestions,
    required this.submittedAt,
    this.birthDate,
    this.department,
  });

  factory _EduResultData.fromMap(Map<String, dynamic> map) {
    return _EduResultData(
      id: map['id']?.toString() ?? '',
      examTitle: map['examTitle']?.toString() ?? 'N/A',
      studentName: map['studentName']?.toString() ?? 'Học sinh',
      studentId: map['studentId']?.toString() ?? '',
      score: (map['score'] ?? 0).toDouble(),
      totalQuestions: (map['totalQuestions'] ?? 0).toInt(),
      submittedAt: map['submittedAt']?.toString() ?? '',
      birthDate: map['birthDate']?.toString(), // NEW
      department: map['department']?.toString(), // NEW
    );
  }
}

class _ExamResultsPageState extends State<ExamResultsPage> {
  final Color _backgroundBlue = const Color(0xFFE3EDFD);
  final Color _primaryIndigo = const Color(0xFF6366F1);
  final TextEditingController _searchController = TextEditingController();

  String _searchText = "";
  String _selectedExam = "Tất cả đề thi";
  List<_EduResultData> _allResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      String? teacherName;
      if (widget.role == 'teacher') {
        final profile = await apiService.getUser(widget.uid);
        if (profile != null) {
          teacherName = profile['fullName'];
        }
      }

      final results = await apiService.getExamResults(
        studentId: widget.role == 'student' ? widget.uid : null,
        teacherName: teacherName,
      );
      if (mounted) {
        setState(() {
          _allResults = results.map((e) => _EduResultData.fromMap(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải kết quả: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel(List<_EduResultData> results) async {
    try {
      var excel = exc.Excel.createExcel();
      String sheetName = "KetQuaThi";
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, sheetName);
      exc.Sheet sheetObject = excel[sheetName];

      sheetObject.appendRow([
        exc.TextCellValue('Tên học sinh'),
        exc.TextCellValue('Ngày sinh'),
        exc.TextCellValue('Khoa/Bộ môn'),
        exc.TextCellValue('Tên bài thi'),
        exc.TextCellValue('Số câu đúng'),
        exc.TextCellValue('Tổng số câu'),
        exc.TextCellValue('Thời gian nộp'),
      ]);

      for (var res in results) {
        String dob = "N/A";
        if (res.birthDate != null) {
          try {
            DateTime d = DateTime.parse(res.birthDate!);
            dob = "${d.day}/${d.month}/${d.year}";
          } catch (_) {}
        }

        sheetObject.appendRow([
          exc.TextCellValue(res.studentName),
          exc.TextCellValue(dob),
          exc.TextCellValue(res.department ?? "N/A"),
          exc.TextCellValue(res.examTitle),
          exc.IntCellValue(res.score.toInt()),
          exc.IntCellValue(res.totalQuestions),
          exc.TextCellValue(res.submittedAt),
        ]);
      }

      final List<int>? fileBytes = excel.encode();
      if (fileBytes == null) return;

      String safeExamName = _selectedExam
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(' ', '_');
      String fileName = "KetQua_$safeExamName.xlsx";

      if (kIsWeb) {
        final content = base64Encode(fileBytes);
        final dataUrl =
            "data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$content";
        html.AnchorElement(href: dataUrl)
          ..setAttribute("download", fileName)
          ..click();
      } else {
        final directory = await getTemporaryDirectory();
        final String filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        if (await file.exists()) await file.delete();
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Báo cáo kết quả: $_selectedExam');
      }
    } catch (e) {
      debugPrint("Lỗi khi xuất file: $e");
    }
  }

  Future<void> _deleteResult(String docId) async {
    if (widget.role == 'student') return;
    final bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Xác nhận xóa"),
            content: const Text("Bạn có chắc muốn xóa kết quả thi này không?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("HỦY"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("XÓA", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await apiService.deleteExamResult(docId);
        _fetchResults(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : _backgroundBlue;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    Set<String> exams = {"Tất cả đề thi"};
    for (var res in _allResults) {
      exams.add(res.examTitle);
    }

    final filteredResults = _allResults.where((res) {
      final matchesSearch = res.studentName.toLowerCase().contains(_searchText);
      final matchesExam =
          _selectedExam == "Tất cả đề thi" || res.examTitle == _selectedExam;
      return matchesSearch && matchesExam;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.role == 'student' ? "Điểm của tôi" : "Quản lý kết quả thi",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(onPressed: _fetchResults, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchText = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Tìm kiếm theo tên học sinh...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedExam,
                              isExpanded: true,
                              items: exams
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        e,
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedExam = val!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (widget.role != 'student' &&
                          filteredResults.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _exportToExcel(filteredResults),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.file_download),
                          label: const Text("Xuất Excel"),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredResults.isEmpty
                      ? const Center(child: Text("Không tìm thấy kết quả nào"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredResults.length,
                          itemBuilder: (context, index) {
                            final res = filteredResults[index];
                            final double percent = res.totalQuestions > 0
                                ? (res.score / res.totalQuestions)
                                : 0;

                            Widget card = Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: _buildScoreCircle(
                                  res.score.toInt(),
                                  res.totalQuestions,
                                  percent,
                                ),
                                title: Text(
                                  widget.role == 'student'
                                      ? res.examTitle
                                      : res.studentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "Bài thi: ${res.examTitle}",
                                      style: TextStyle(
                                        color: _primaryIndigo,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      res.submittedAt.split('.').first,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final userInfo = await apiService.getUser(
                                    res.studentId,
                                  );
                                  if (context.mounted) {
                                    _showDetails(
                                      context,
                                      res,
                                      userInfo,
                                      isDark,
                                    );
                                  }
                                },
                              ),
                            );

                            if (widget.role != 'student') {
                              return Dismissible(
                                key: Key(res.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (dir) async {
                                  await _deleteResult(res.id);
                                  return false; // We redraw manually
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                child: card,
                              );
                            }
                            return card;
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildScoreCircle(int score, int total, double percent) {
    Color color = percent >= 0.8
        ? Colors.green
        : (percent >= 0.5 ? Colors.orange : Colors.red);
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: "$score", style: const TextStyle(fontSize: 18)),
              TextSpan(text: "\n/$total", style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    _EduResultData res,
    Map<String, dynamic>? userInfo,
    bool isDark,
  ) {
    String dob = "N/A";
    if (userInfo?['birthDate'] != null) {
      try {
        DateTime d = DateTime.parse(userInfo!['birthDate']);
        dob = "${d.day}/${d.month}/${d.year}";
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          "Chi tiết kết quả",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.role != 'student') ...[
              _rowInfo(Icons.person, "Học sinh", res.studentName),
              _rowInfo(Icons.cake, "Ngày sinh", dob),
              _rowInfo(
                Icons.business,
                "Khoa",
                userInfo?['department'] ?? "N/A",
              ),
              const Divider(),
            ],
            _rowInfo(Icons.assignment, "Đề thi", res.examTitle),
            _rowInfo(
              Icons.check_circle,
              "Kết quả",
              "${res.score.toInt()}/${res.totalQuestions} câu đúng",
            ),
            _rowInfo(
              Icons.calendar_today,
              "Thời gian",
              res.submittedAt.split('.').first,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ĐÓNG"),
          ),
        ],
      ),
    );
  }

  Widget _rowInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryIndigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
