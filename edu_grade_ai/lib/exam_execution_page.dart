import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import 'services/api_service.dart';

class ExamExecutionPage extends StatefulWidget {
  final String examTitle;
  final List<Question> questions;
  final String studentId;
  final String studentName;
  final String examSubject;
  final String examId; // NEW
  final String classId; // NEW

  const ExamExecutionPage({
    super.key,
    required this.examTitle,
    required this.questions,
    required this.studentId,
    required this.studentName,
    required this.examSubject,
    required this.examId,
    required this.classId,
  });

  @override
  State<ExamExecutionPage> createState() => _ExamExecutionPageState();
}

class _ExamExecutionPageState extends State<ExamExecutionPage> {
  final Map<int, String> _studentAnswers = {};
  bool _isSubmitted = false;
  bool _isSaving = false;
  int _score = 0;

  final Color _primaryIndigo = const Color(0xFF6366F1);

  void _confirmSubmit() {
    if (_studentAnswers.length < widget.questions.length) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Chưa hoàn thành"),
          content: Text(
            "Bạn còn ${widget.questions.length - _studentAnswers.length} câu chưa làm. Bạn vẫn muốn nộp chứ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("LÀM TIẾP"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryIndigo),
              onPressed: () {
                Navigator.pop(context);
                _calculateScore();
              },
              child: const Text(
                "NỘP LUÔN",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      _calculateScore();
    }
  }

  Future<void> _calculateScore() async {
    if (_isSaving) return;

    int correctCount = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      String studentAns = (_studentAnswers[i] ?? "").trim().toUpperCase();
      String correctAns = (widget.questions[i].correctAnswer)
          .trim()
          .toUpperCase();
      if (studentAns == correctAns) correctCount++;
    }

    setState(() {
      _isSubmitted = true;
      _score = correctCount;
      _isSaving = true;
    });

    try {
      final Map<String, String> formattedAnswers = _studentAnswers.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      await apiService.submitExamResult({
        'examId': widget.examId,
        'examTitle': widget.examSubject,
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'score': _score.toDouble(),
        'totalQuestions': widget.questions.length,
        'correctCount': _score,
        'answers': formattedAnswers,
        'classId': widget.classId,
      });

      if (mounted) _showSnackBar("Đã nộp bài thành công!", isError: false);
    } catch (e) {
      if (mounted)
        _showSnackBar("Lỗi hệ thống khi lưu kết quả: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF131927)
        : const Color(0xFFE8F0FE);
    final Color cardColor = isDark ? const Color(0xFF1C2437) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: _isSubmitted,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _showExitWarning();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0.5,
          centerTitle: true,
          title: Text(
            widget.examTitle,
            style: TextStyle(
              color: isDark ? Colors.white : _primaryIndigo,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            if (!_isSubmitted)
              _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _confirmSubmit,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      label: const Text(
                        "NỘP BÀI",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
          ],
        ),
        body: Column(
          children: [
            if (_isSubmitted) _buildScoreBanner(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: widget.questions.length,
                itemBuilder: (context, index) =>
                    _buildQuestionCard(index, cardColor, textColor, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitWarning() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Thoát bài thi?"),
            content: const Text(
              "Kết quả của bạn sẽ không được lưu nếu bạn thoát bây giờ.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Ở LẠI"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("THOÁT"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildScoreBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryIndigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryIndigo.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            "KẾT QUẢ BÀI THI",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            "$_score / ${widget.questions.length}",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _primaryIndigo,
            ),
          ),
          Text(
            "Thí sinh: ${widget.studentName}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    int index,
    Color cardColor,
    Color textColor,
    bool isDark,
  ) {
    final q = widget.questions[index];
    final studentAns = (_studentAnswers[index] ?? "").trim().toUpperCase();
    final bool isCorrect = studentAns == q.correctAnswer.trim().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
        border: _isSubmitted
            ? Border.all(
                color: isCorrect
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
                width: 1.5,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${index + 1}. ${q.content}",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            if (q.type == 'trac_nghiem')
              _buildMultipleChoice(index, isDark, textColor)
            else
              _buildShortAnswer(index, isDark, textColor),
            if (_isSubmitted) ...[
              const Divider(height: 32),
              _buildResultBox(q, isCorrect, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoice(int index, bool isDark, Color textColor) {
    return Column(
      children: ['A', 'B', 'C', 'D'].map((option) {
        return RadioListTile<String>(
          title: Text(
            "Đáp án $option",
            style: TextStyle(fontSize: 14, color: textColor),
          ),
          value: option,
          groupValue: _studentAnswers[index],
          activeColor: _primaryIndigo,
          contentPadding: EdgeInsets.zero,
          onChanged: _isSubmitted
              ? null
              : (val) => setState(() => _studentAnswers[index] = val!),
        );
      }).toList(),
    );
  }

  Widget _buildShortAnswer(int index, bool isDark, Color textColor) {
    return TextField(
      enabled: !_isSubmitted,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: "Nhập câu trả lời...",
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) => _studentAnswers[index] = val,
    );
  }

  Widget _buildResultBox(Question q, bool isCorrect, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isCorrect ? "Chính xác" : "Chưa đúng",
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Đáp án đúng: ${q.correctAnswer}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        if (q.rubric != null && q.rubric != "N/A") ...[
          const SizedBox(height: 4),
          Text(
            "Giải thích: ${q.rubric}",
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}
