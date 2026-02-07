// REMOVED: import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String content; // Nội dung câu hỏi (+ 4 đáp án nếu là trắc nghiệm)
  final String correctAnswer; // Đáp án đúng hoặc đáp án mẫu
  final String? rubric; // Tiêu chí chấm điểm (chỉ dành cho tự luận)
  final String? type; // 'trac_nghiem' hoặc 'tu_luan'

  Question({
    required this.content,
    required this.correctAnswer,
    this.rubric,
    this.type,
  });

  // Chuyển từ Object sang Map để lưu lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'correctAnswer': correctAnswer,
      'rubric': rubric,
      'type': type,
      // Timestamp xóa bỏ vì lưu qua API Backend ko hiểu object này
      // Backend sẽ tự thêm createdAt khi lưu vào Firestore
    };
  }

  // Chuyển từ Firestore Document sang Object để hiển thị
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      content: map['content']?.toString() ?? '',
      correctAnswer:
          map['correctAnswer']?.toString() ??
          '', // Ép kiểu string để so sánh ko lỗi
      rubric: map['rubric']?.toString(),
      type: map['type']?.toString(),
    );
  }
}
