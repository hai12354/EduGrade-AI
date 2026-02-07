import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../exam_execution_page.dart';
import '../../services/api_service.dart';

class StudentExamsPage extends StatefulWidget {
  final String uid;
  final String studentName;
  final List<String> registeredClassIds; // Changed from single String

  const StudentExamsPage({
    super.key,
    required this.uid,
    required this.studentName,
    required this.registeredClassIds,
  });

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  String? _selectedSubject;
  final Color _primaryIndigo = const Color(0xFF6366F1);
  List<String> _subjects = [];
  List<dynamic> _exams = [];
  bool _isLoadingSubjects = false;
  bool _isLoadingExams = false;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    setState(() => _isLoadingSubjects = true);
    try {
      // Fetch all exams and show subjects.
      // Multi-class filtering can be added here if specific subjects are bound to classIds.
      final exams = await apiService.getAllExams();
      final Set<String> sets = {};
      for (var e in exams) {
        if (e['subject'] != null) {
          sets.add(e['subject'].toString().trim());
        }
      }
      setState(() {
        _subjects = sets.toList()..sort();
      });
    } catch (e) {
      debugPrint("Lỗi tải môn học: $e");
    } finally {
      setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _fetchExams(String subject) async {
    setState(() => _isLoadingExams = true);
    try {
      final list = await apiService.getExamsBySubject(subject);
      setState(() => _exams = list);
    } catch (e) {
      debugPrint("Lỗi tải đề thi: $e");
    } finally {
      setState(() => _isLoadingExams = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF131927)
        : const Color(0xFFE8F0FE);
    final Color cardColor = isDark ? const Color(0xFF1C2437) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          "Chọn môn học & Đề thi",
          style: TextStyle(
            color: isDark ? Colors.white : _primaryIndigo,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : _primaryIndigo,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "Thí sinh: ${widget.studentName}",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ),

          _buildSubjectSelector(isDark, cardColor),

          Expanded(
            child: _selectedSubject == null
                ? _buildEmptyState("Vui lòng chọn môn học để xem đề thi")
                : _isLoadingExams
                ? const Center(child: CircularProgressIndicator())
                : _exams.isEmpty
                ? _buildEmptyState("Không có đề thi nào cho môn này")
                : _buildExamList(isDark, cardColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: _isLoadingSubjects
          ? const LinearProgressIndicator()
          : _subjects.isEmpty
          ? const Center(child: Text("Hiện chưa có môn học nào."))
          : DropdownButtonFormField<String>(
              value: _selectedSubject,
              hint: Text(
                "Chọn môn học",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              dropdownColor: cardColor,
              isExpanded: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.book, color: _primaryIndigo),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSubject = val);
                  _fetchExams(val);
                }
              },
            ),
    );
  }

  Widget _buildExamList(bool isDark, Color cardColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _exams.length,
      itemBuilder: (context, index) {
        var exam = _exams[index];

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF9C4),
              child: Icon(Icons.assignment_rounded, color: Colors.orange),
            ),
            title: Text(
              exam['title'] ?? "Đề thi không tên",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              "Cấu trúc: ${exam['structure'] ?? 'N/A'}",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryIndigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                List<dynamic> questionsRaw = exam['questions'] ?? [];
                List<Question> questionList = questionsRaw
                    .map((q) => Question.fromMap(q as Map<String, dynamic>))
                    .toList();

                if (questionList.isEmpty) {
                  _showSnackBar("Đề thi này chưa có câu hỏi!", isError: true);
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExamExecutionPage(
                      examTitle: exam['title'] ?? "Đề thi",
                      questions: questionList,
                      studentId: widget.uid,
                      studentName: widget.studentName,
                      examSubject: _selectedSubject ?? "subject",
                      examId: exam['id']?.toString() ?? '',
                      classId: widget.registeredClassIds.isNotEmpty
                          ? widget.registeredClassIds.first
                          : 'N/A', // Best effort choice
                    ),
                  ),
                );
              },
              child: const Text(
                "Làm bài",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 60,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
