import 'package:flutter/material.dart';
import 'main.dart';
import 'teacher_management_page.dart';
import 'screens/teacher/syllabus_page.dart';
import 'admin_classes_screen.dart';
import 'system_settings_page.dart';
import 'user_profile_update.dart';
import 'screens/student/student_exams_page.dart';
import 'exam_results_page.dart';
import 'services/api_service.dart';

class EduGradeApp extends StatefulWidget {
  final VoidCallback onLogout;
  final String role;
  final String uid;

  const EduGradeApp({
    super.key,
    required this.onLogout,
    required this.role,
    required this.uid,
  });

  @override
  State<EduGradeApp> createState() => _EduGradeAppState();
}

class _EduGradeAppState extends State<EduGradeApp> {
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    _loadUser(); // Load once on startup
  }

  Future<void> _loadUser() async {
    if (mounted) setState(() => _isLoadingUser = true);
    try {
      // Tải song song cả profile và stats
      final results = await Future.wait([
        apiService.getUser(widget.uid),
        apiService.getDashboardStats(),
      ]);

      if (mounted) {
        setState(() {
          _userData = results[0];
          // Stats are fetched but cached by apiService or handled by FutureBuilder below
          // (Adding this wait ensures we have the latest user data before rendering)
        });
      }
    } catch (e) {
      debugPrint("Lỗi API Dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = themeController.isDarkMode;
        double width = MediaQuery.of(context).size.width;
        bool isMobile = width < 850;

        // Hiển thị loader nếu đang tải lần đầu
        if (_isLoadingUser && _userData == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = _userData;
        final String fullName = data?['fullName'] ?? "Người dùng";
        final String userRole = data?['role'] ?? widget.role;
        final String classId = data?['classId'] ?? "";

        // Multi-class support
        List<String> registeredIds = [];
        if (data?['registeredClassIds'] is List) {
          registeredIds = List<String>.from(data?['registeredClassIds']);
        } else if (classId.isNotEmpty) {
          registeredIds = [classId];
        }
        final String avatarChar = fullName.isNotEmpty
            ? fullName[0].toUpperCase()
            : "?";

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: isMobile
              ? Drawer(
                  child: _buildSidebar(
                    context,
                    theme,
                    isDark,
                    fullName,
                    avatarChar,
                    userRole,
                    classId,
                    registeredIds, // Pass fresh list
                  ),
                )
              : null,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: theme.cardColor,
                  elevation: 0,
                  iconTheme: IconThemeData(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  title: const Text(
                    "EduGrade AI",
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile)
                _buildSidebar(
                  context,
                  theme,
                  isDark,
                  fullName,
                  avatarChar,
                  userRole,
                  classId,
                  registeredIds,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile, theme, fullName),
                      const SizedBox(height: 32),
                      _buildStatGrid(isMobile, theme),
                      const SizedBox(height: 32),
                      _buildMainContent(
                        isMobile,
                        theme,
                        isDark,
                        userRole,
                        classId,
                        fullName,
                        registeredIds,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String fullName,
    String avatarChar,
    String userRole,
    String classId,
    List<String> registeredIds,
  ) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFD1E2FF),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF6366F1),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                "EduGrade AI",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _sidebarMenuItem("Tổng quan", Icons.grid_view_rounded, true, theme),

          _sidebarMenuItem(
            "Lớp học",
            Icons.class_outlined,
            false,
            theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminClassesScreen(
                    userRole: userRole,
                    userClassId: classId, // Legacy
                    registeredClassIds: registeredIds, // NEW
                    userId: widget.uid,
                    userName: fullName,
                  ),
                ),
              ).then((_) => _loadUser()); // Reactive refresh on return
            },
          ),

          if (userRole == 'admin') ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                "QUẢN TRỊ",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _sidebarMenuItem(
              "Quản lý giáo viên",
              Icons.person_add_alt_1,
              false,
              theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TeacherManagementPage(),
                  ),
                );
              },
            ),
            _sidebarMenuItem(
              "Cài đặt hệ thống",
              Icons.settings_suggest,
              false,
              theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SystemSettingsPage(),
                  ),
                );
              },
            ),
          ],

          if (userRole == 'teacher' || userRole == 'admin')
            _sidebarMenuItem(
              "Kết quả bài thi",
              Icons.check_circle_outline,
              false,
              theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ExamResultsPage(role: userRole, uid: widget.uid),
                  ),
                );
              },
            ),

          if (userRole == 'student')
            _sidebarMenuItem(
              "Điểm của tôi",
              Icons.grade,
              false,
              theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ExamResultsPage(role: userRole, uid: widget.uid),
                  ),
                );
              },
            ),

          const Spacer(),
          ListTile(
            leading: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.orange,
            ),
            title: Text(
              isDark ? "Chế độ sáng" : "Chế độ tối",
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => themeController.toggleTheme(),
          ),
          const SizedBox(height: 10),
          _buildUserCard(theme, isDark, fullName, avatarChar, userRole),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    bool isMobile,
    ThemeData theme,
    bool isDark,
    String userRole,
    String classId,
    String fullName,
    List<String> registeredIds,
  ) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        Container(
          width: isMobile ? double.infinity : 550,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Thao tác nhanh",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  if (userRole == 'admin') ...[
                    _actionBtn(
                      "Thêm giáo viên",
                      Icons.person_add_rounded,
                      Colors.green,
                      theme,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TeacherManagementPage(),
                          ),
                        );
                      },
                    ),
                    _actionBtn(
                      "Quản lý lớp học",
                      Icons.class_outlined,
                      Colors.orange,
                      theme,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminClassesScreen(
                              userRole: userRole,
                              userClassId: classId,
                              registeredClassIds: registeredIds,
                              userId: widget.uid,
                              userName: fullName,
                            ),
                          ),
                        ).then((_) => _loadUser());
                      },
                    ),
                  ],
                  if (userRole == 'teacher')
                    _actionBtn(
                      "Tạo bài kiểm tra",
                      Icons.bolt_rounded,
                      Colors.indigo,
                      theme,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SyllabusPage(uid: widget.uid),
                        ),
                      ),
                    ),
                  if (userRole == 'student')
                    _actionBtn(
                      "Làm bài kiểm tra",
                      Icons.play_lesson_rounded,
                      classId.isEmpty ? Colors.grey : Colors.amber,
                      theme,
                      onTap: classId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentExamsPage(
                                    uid: widget.uid,
                                    studentName: fullName,
                                    registeredClassIds: registeredIds,
                                  ),
                                ),
                              );
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
        _buildTipCard(isMobile),
      ],
    );
  }

  Widget _buildUserCard(
    ThemeData theme,
    bool isDark,
    String fullName,
    String avatarChar,
    String userRole,
  ) {
    final String department = _userData?['department'] ?? "Chưa cập nhật khoa";
    String dobString = "Chưa cập nhật";
    if (_userData?['birthDate'] != null) {
      try {
        DateTime dob = DateTime.parse(_userData!['birthDate']);
        dobString = "${dob.day}/${dob.month}/${dob.year}";
      } catch (e) {
        // Fallback for logic if it was still a timestamp in some cache?
        dobString = "N/A";
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UserProfileUpdate(uid: widget.uid, fullName: fullName),
                ),
              ).then((_) => _loadUser()); // Reload after update
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    avatarChar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "Vai trò: ${userRole.toUpperCase()}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.business_center_outlined,
                      size: 14,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Khoa: $department",
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyLarge?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.cake_outlined,
                      size: 14,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Ngày sinh: $dobString",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyLarge?.color?.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onLogout,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Text(
                      "Đăng xuất",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, ThemeData theme, String fullName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Dashboard",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              "Chào mừng trở lại, $fullName!",
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatGrid(bool isMobile, ThemeData theme) {
    double width = MediaQuery.of(context).size.width;
    double cardWidth = isMobile ? (width - 60) / 2 : (width - 440) / 3;

    return FutureBuilder<Map<String, dynamic>>(
      future: apiService.getDashboardStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            if (widget.role != 'student') ...[
              _statBox(
                "GIÁO VIÊN",
                isLoading ? "..." : (stats['teacher']?.toString() ?? "0"),
                Icons.people_outline,
                cardWidth,
                theme,
              ),
              _statBox(
                "LỚP HỌC",
                isLoading ? "..." : (stats['classes_count']?.toString() ?? "0"),
                Icons.class_outlined,
                cardWidth,
                theme,
              ),
            ],
            _statBox(
              "HỌC SINH",
              isLoading ? "..." : (stats['student']?.toString() ?? "0"),
              Icons.school_outlined,
              cardWidth,
              theme,
            ),
          ],
        );
      },
    );
  }

  Widget _statBox(
    String title,
    String value,
    IconData icon,
    double width,
    ThemeData theme,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: const Color(0xFF6366F1)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey[300],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarMenuItem(
    String title,
    IconData icon,
    bool active,
    ThemeData theme, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: active ? const Color(0xFF6366F1) : Colors.blueGrey[300],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: active
              ? const Color(0xFF6366F1)
              : theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: active
          ? const Color(0xFF6366F1).withOpacity(0.1)
          : Colors.transparent,
      onTap: onTap,
    );
  }

  Widget _actionBtn(
    String title,
    IconData icon,
    Color color,
    ThemeData theme, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.white, size: 30),
          SizedBox(height: 16),
          Text(
            "Mẹo Pro",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Sử dụng EduGrade AI để tối ưu hóa việc quản lý và học tập.",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
