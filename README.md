# EduGrade AI - Nền tảng Quản lý Giáo dục & Khảo thí Thông minh

**EduGrade AI** không chỉ là một ứng dụng quản lý lớp học thông thường, mà là một hệ sinh thái giáo dục hiện đại tích hợp Trí tuệ Nhân tạo (AI). Được thiết kế để tối ưu hóa quy trình dạy và học, ứng dụng giúp giảng viên giải phóng khỏi các tác vụ thủ công và giúp sinh viên tiếp cận bài thi một cách chuyên nghiệp, nhanh chóng.

---

## 💡 Dự án này có gì và làm được gì?

Dự án này giải quyết bài toán cốt lõi trong giáo dục: **Tạo đề thi chất lượng cao và quản lý đào tạo tập trung.**

### 1. Tự động hóa soạn đề với "AI Multi-Fallback"
- **Làm được gì:** Thay vì mất hàng giờ để soạn câu hỏi, giảng viên chỉ cần tải tài liệu lên. Hệ thống sẽ bóc tách kiến thức và tạo ra đề thi 10 điểm hoàn chỉnh.
- **Có gì đặc biệt:** Tích hợp bộ 3 quyền lực **Gemini 2.5 Flash, Grok-2 và GPT-4o**. Nếu một AI bị quá tải, hệ thống tự động chuyển sang AI khác để đảm bảo quy trình không bị ngắt quãng.

### 2. Quản lý đào tạo 360 độ
- **Làm được gì:** Quản lý từ khâu cấp tài khoản giáo viên, đăng ký lớp học cho đến khi sinh viên nộp bài và nhận điểm.
- **Có gì đặc biệt:** Hệ thống tính điểm thời gian thực và lưu trữ chi tiết từng câu trả lời của sinh viên để giảng viên có thể đánh giá năng lực chính xác nhất.

### 3. Trải nghiệm người dùng cao cấp
- **Giao diện:** Modern UI với hiệu ứng Glassmorphism, hỗ trợ **Dark Mode** hoàn hảo giúp giảm mỏi mắt khi làm bài thi ban đêm.
- **Tính di động:** Chạy mượt mà trên cả Android, iOS và Web, cho phép làm bài thi mọi lúc, mọi nơi.

---

## 👑 Chi tiết các tính năng cốt lõi

### � Dành cho Quản trị viên (Admin)
- **Kiểm soát nhân sự:** Cấp quyền và quản trị danh sách Giảng viên toàn hệ thống.
- **Lập kế hoạch đào tạo:** Tạo danh mục lớp học theo học kỳ (Semester), cấu hình sĩ số tối đa và phòng học.
- **Cấu hình "registration_lock":** Đặt deadline đăng ký học phần. Hệ thống sẽ tự động khóa hoặc mở cổng đăng ký dựa trên cài đặt thời gian thực.

### 👨‍🏫 Dành cho Giảng viên (Teacher)
- **AI Syllabus Processor:** Đọc hiểu các file PDF/DOCX phức tạp để trích xuất nội dung trọng tâm.
- **Thiết kế đề thi đa dạng:** Tùy chỉnh tỷ lệ Trắc nghiệm/Tự luận (ví dụ: 70/30, 50/50) và số lượng câu hỏi mong muốn.
- **Quản lý điểm số:** Xem bảng điểm danh sách lớp, tìm kiếm sinh viên theo tên và xuất file Excel báo cáo chỉ với 1 click.

### 🎓 Dành cho Sinh viên (Student)
- **Đăng ký môn học thông minh:** Xem danh sách lớp khả dụng, kiểm tra sĩ số thời gian thực trước khi đăng ký.
- **Digital Exam Hall:** Giao diện làm bài chuyên nghiệp, có cảnh báo khi cố tình thoát trang để đảm bảo tính nghiêm túc của kỳ thi.
- **Cập nhật hồ sơ:** Tự cập nhật thông tin cá nhân, khoa ngành và theo dõi tiến độ học tập qua các kỳ thi đã tham gia.

---

## 🛠 Công nghệ đột phá trong dự án

- **AI Model:** Gemini 2.5 Flash/Pro, Grok AI API, OpenAI API.
- **Backend:** Google Cloud Firebase (Firestore Transactions đảm bảo không bao giờ bị lỗi đăng ký vượt sĩ số).
- **Security:** Mã hóa mật khẩu và phân quyền User Roles nghiêm ngặt.
- **Export System:** Data Processing Engine giúp chuyển đổi dữ liệu từ Firestore sang định dạng Excel mượt mà trên cả trình duyệt và mobile.
