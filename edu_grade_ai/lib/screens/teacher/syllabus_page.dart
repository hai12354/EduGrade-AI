import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import '../../models/question_model.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class SyllabusPage extends StatefulWidget {
  final String uid;
  const SyllabusPage({super.key, required this.uid});

  @override
  State<SyllabusPage> createState() => _SyllabusPageState();
}

class _SyllabusPageState extends State<SyllabusPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _countController = TextEditingController(
    text: "10",
  );
  final TextEditingController _subjectController = TextEditingController();

  List<dynamic> _assignedClasses = [];
  String? _selectedClassId;
  String? _teacherFullName;

  bool _isLoading = false;
  bool _isSaving = false;
  List<Question> _questions = [];
  String? _fileName;

  String _selectedStructure = "70% Trắc nghiệm - 30% Tự luận";
  final List<String> _structures = [
    "100% Trắc nghiệm",
    "70% Trắc nghiệm - 30% Tự luận",
    "60% Trắc nghiệm - 40% Tự luận",
    "50% Trắc nghiệm - 50% Tự luận",
    "40% Trắc nghiệm - 60% Tự luận",
    "100% Tự luận",
  ];

  final Color _primaryIndigo = const Color(0xFF3F51B5);

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    try {
      final user = await apiService.getUser(widget.uid);
      if (user != null) {
        _teacherFullName = user['fullName'];
        if (_teacherFullName != null) {
          final classes = await apiService.getClassesByTeacher(
            _teacherFullName!,
          );
          setState(() {
            _assignedClasses = classes;
            if (_assignedClasses.isNotEmpty) {
              _selectedClassId = _assignedClasses.first['classId'];
              _subjectController.text = _assignedClasses.first['name'] ?? "";
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải thông tin giáo viên: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : _primaryIndigo,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "EduGrade AI Builder",
          style: TextStyle(
            color: isDark ? Colors.white : _primaryIndigo,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _buildInputArea(isDark, cardColor),
            const SizedBox(height: 16),
            _buildControlPanel(isDark, cardColor),
            const SizedBox(height: 24),
            _buildGenerateBtn(),
            if (_questions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSaveBtn(isDark),
              const SizedBox(height: 24),
              _buildQuestionList(isDark, cardColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Dán nội dung hoặc tải file...",
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              contentPadding: const EdgeInsets.all(18),
              border: InputBorder.none,
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          ListTile(
            onTap: _pickAndExtractFile,
            leading: Icon(
              Icons.attach_file,
              color: isDark ? Colors.indigoAccent : _primaryIndigo,
            ),
            title: Text(
              _fileName ?? "Tải tài liệu (PDF/DOCX)",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            trailing: const Icon(Icons.upload_file, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedClassId,
            dropdownColor: cardColor,
            isExpanded: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
            ),
            items: _assignedClasses
                .map(
                  (c) => DropdownMenuItem(
                    value: c['classId']?.toString(),
                    child: Text(
                      "${c['classId']} - ${c['name']}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedClassId = v;
                final selected = _assignedClasses.firstWhere(
                  (c) => c['classId'] == v,
                );
                _subjectController.text = selected['name'] ?? "";
              });
            },
            decoration: InputDecoration(
              labelText: "Chọn lớp giảng dạy",
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : _primaryIndigo,
              ),
              prefixIcon: Icon(
                Icons.class_rounded,
                color: isDark ? Colors.indigoAccent : _primaryIndigo,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey,
                ),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                "Số câu hỏi:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedStructure,
            dropdownColor: cardColor,
            isExpanded: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
            ),
            items: _structures
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedStructure = v!),
            decoration: InputDecoration(
              labelText: "Cấu trúc đề",
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : _primaryIndigo,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey,
                ),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateBtn() => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryIndigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _isLoading ? null : _generateQuestionsWithGemini,
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              "BẮT ĐẦU TẠO ĐỀ THI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    ),
  );

  Widget _buildSaveBtn(bool isDark) => SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isDark ? Colors.indigoAccent : _primaryIndigo,
          width: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _isSaving ? null : _saveToBackend,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            )
          : Icon(
              Icons.cloud_upload,
              color: isDark ? Colors.indigoAccent : _primaryIndigo,
            ),
      label: Text(
        "LƯU ĐỀ THI VÀO HỆ THỐNG",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.indigoAccent : _primaryIndigo,
        ),
      ),
    ),
  );

  Widget _buildQuestionList(bool isDark, Color cardColor) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            iconColor: isDark ? Colors.indigoAccent : _primaryIndigo,
            collapsedIconColor: Colors.grey,
            title: Text(
              "${index + 1}. ${q.content}",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🎯 ĐÁP ÁN: ${q.correctAnswer}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (q.rubric != null) ...[
                      Divider(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                      Text(
                        "📝 RUBRIC:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blueAccent : Colors.blue,
                        ),
                      ),
                      Text(
                        q.rubric!,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToBackend() async {
    final subject = _subjectController.text.trim();
    if (_questions.isEmpty) return;
    if (subject.isEmpty) {
      _showSnackBar("Vui lòng nhập tên môn học trước khi lưu!", isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final examData = {
        'title':
            _fileName ??
            "Đề thi AI - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
        'subject': subject,
        'structure': _selectedStructure,
        'questions': _questions.map((q) => q.toMap()).toList(),
      };

      await apiService.createExam(examData);
      _showSnackBar("Đã lưu dữ liệu môn $subject thành công!");

      setState(() {
        _questions = [];
        _subjectController.clear();
        _fileName = null;
        _controller.clear();
      });
    } catch (e) {
      _showSnackBar("Lỗi khi lưu: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndExtractFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        withData: true,
      );
      if (result != null) {
        setState(() => _isLoading = true);
        String extractedText = "";
        final file = result.files.single;
        if (file.extension == 'pdf') {
          final PdfDocument document = PdfDocument(inputBytes: file.bytes);
          extractedText = PdfTextExtractor(document).extractText();
          document.dispose();
        } else if (file.extension == 'docx') {
          extractedText = docxToText(file.bytes!);
        }
        setState(() {
          _fileName = file.name;
          _controller.text = extractedText;
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi đọc file: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateQuestionsWithGemini() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnackBar("Vui lòng nhập nội dung!", isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      String aiUrl =
          "${apiService.baseUrl.replaceFirst('/api', '')}/api/ai/generate-exam";
      final response = await http.post(
        Uri.parse(aiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "text": text,
          "count": int.tryParse(_countController.text) ?? 10,
          "structure": _selectedStructure,
          "subject": _subjectController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> qJson = data['questions'];
          setState(() {
            _questions = qJson
                .map(
                  (q) => Question(
                    type: q['type'],
                    content: q['content'],
                    correctAnswer: q['correct_answer'],
                    rubric: q['rubric'],
                  ),
                )
                .toList();
          });
          _showSnackBar(
            "Tạo đề thành công bằng ${data['model_used'].toString().toUpperCase()}!",
          );
        } else {
          _showSnackBar("Lỗi: ${data['message']}", isError: true);
        }
      } else {
        _showSnackBar("Lỗi Server: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Lỗi kết nối AI: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
