import 'package:flutter/material.dart';
import 'services/api_service.dart';

class TeacherManagementPage extends StatefulWidget {
  const TeacherManagementPage({super.key});

  @override
  State<TeacherManagementPage> createState() => _TeacherManagementPageState();
}

class _TeacherManagementPageState extends State<TeacherManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  List<dynamic> _teachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    setState(() => _isLoading = true);
    try {
      final list = await apiService.getTeachers();
      setState(() => _teachers = list);
    } catch (e) {
      debugPrint("Lỗi tải giáo viên: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Hàm thêm giáo viên qua Backend API
  Future<void> _addTeacher() async {
    if (_formKey.currentState!.validate()) {
      try {
        final exists = await apiService.checkUsernameExists(
          _usernameController.text.trim(),
        );
        if (exists) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Username này đã tồn tại!")),
            );
          return;
        }

        await apiService.register(
          username: _usernameController.text.trim(),
          password: '123',
          fullName: _nameController.text.trim(),
          classId: '',
          role: 'teacher',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã tạo tài khoản giáo viên thành công!"),
            ),
          );
          _nameController.clear();
          _usernameController.clear();
          Navigator.pop(context);
          _fetchTeachers(); // Refresh list
        }
      } catch (e) {
        debugPrint("Lỗi khi lưu: $e");
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  Future<void> _deleteTeacher(String uid) async {
    try {
      await apiService.deleteUser(uid);
      _fetchTeachers(); // Refresh
    } catch (e) {
      debugPrint("Lỗi khi xóa: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Quản lý giáo viên",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        actions: [
          IconButton(
            onPressed: _fetchTeachers,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => _showAddTeacherDialog(context),
              icon: const Icon(
                Icons.person_add_alt_1,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _teachers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _teachers.isEmpty
          ? const Center(
              child: Text(
                "Chưa có giáo viên nào",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _teachers.length,
              itemBuilder: (context, index) {
                var data = _teachers[index];
                String name = data['fullName'] ?? "Không tên";
                String uid = data['uid'] ?? "";

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: isDark ? theme.cardColor : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("@${data['username']}"),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _showDeleteConfirm(uid),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddTeacherDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? theme.cardColor : const Color(0xFFEFEFF4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                width: 400,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Tạo tài khoản",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Thêm giáo viên mới",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black45,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _usernameController,
                        label: "Username",
                        icon: Icons.person_outline,
                        theme: theme,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _nameController,
                        label: "Full Name",
                        icon: Icons.badge_outlined,
                        theme: theme,
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 20),
                          child: Text(
                            "Mật khẩu mặc định là: 123",
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setDialogState(() => _isLoading = true);
                                  await _addTeacher();
                                  if (mounted)
                                    setDialogState(() => _isLoading = false);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Create Account",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Hủy bỏ",
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      cursorColor: const Color(0xFF6366F1),
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF6366F1),
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 22),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
      ),
      validator: (v) => v!.isEmpty ? "Vui lòng nhập $label" : null,
    );
  }

  void _showDeleteConfirm(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xác nhận xóa?"),
        content: const Text("Tài khoản giáo viên này sẽ bị xóa vĩnh viễn."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              _deleteTeacher(uid);
              Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
