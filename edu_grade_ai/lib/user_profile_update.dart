import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';

class UserProfileUpdate extends StatefulWidget {
  final String uid;
  final String fullName;

  const UserProfileUpdate({
    super.key,
    required this.uid,
    required this.fullName,
  });

  @override
  State<UserProfileUpdate> createState() => _UserProfileUpdateState();
}

class _UserProfileUpdateState extends State<UserProfileUpdate> {
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  String? _selectedDepartment;
  bool _isUpdating = false;

  final List<String> _departments = [
    'Công nghệ thông tin',
    'Kinh tế & Quản trị',
    'Ngoại ngữ',
    'Kỹ thuật ô tô',
    'Điện - Điện tử',
    'Du lịch & Khách sạn',
  ];

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final String day = _dayController.text.trim();
    final String month = _monthController.text.trim();
    final String year = _yearController.text.trim();

    if (day.isEmpty ||
        month.isEmpty ||
        year.isEmpty ||
        _selectedDepartment == null) {
      _showSnackBar("Vui lòng nhập đầy đủ thông tin!", Colors.orange);
      return;
    }

    int d = int.parse(day);
    int m = int.parse(month);
    int y = int.parse(year);
    if (d < 1 ||
        d > 31 ||
        m < 1 ||
        m > 12 ||
        y < 1950 ||
        y > DateTime.now().year) {
      _showSnackBar("Ngày tháng năm sinh không hợp lệ!", Colors.redAccent);
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await apiService.updateProfile(
        uid: widget.uid,
        day: day,
        month: month,
        year: year,
        department: _selectedDepartment,
      );

      if (mounted) {
        _showSnackBar("✅ Cập nhật thành công!", Colors.blue);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Lỗi cập nhật: $e");
      _showSnackBar("❌ $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // --- Hệ thống màu Sky Blue ---
    final Color primaryColor = const Color(0xFF3B82F6); // Xanh Sky Blue chủ đạo
    final Color backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF0F7FF);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E3A8A);
    final Color subTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color inputBgColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFF8FAFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Cập nhật thông tin",
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : primaryColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile Section
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: primaryColor,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.fullName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Vui lòng hoàn thiện hồ sơ của bạn",
                        style: TextStyle(fontSize: 14, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 35),

                // Ngày sinh section
                _buildLabel("Ngày tháng năm sinh", textColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDateInput(
                      _dayController,
                      "Ngày",
                      2,
                      inputBgColor,
                      primaryColor,
                    ),
                    const SizedBox(width: 12),
                    _buildDateInput(
                      _monthController,
                      "Tháng",
                      2,
                      inputBgColor,
                      primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateInput(
                        _yearController,
                        "Năm",
                        4,
                        inputBgColor,
                        primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Khoa section
                _buildLabel("Khoa / Bộ môn", textColor),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  dropdownColor: cardColor,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _inputDecoration(
                    inputBgColor,
                    isDark,
                    primaryColor,
                  ),
                  hint: Text(
                    "Chọn khoa của bạn",
                    style: TextStyle(color: subTextColor.withOpacity(0.7)),
                  ),
                  items: _departments
                      .map(
                        (dept) =>
                            DropdownMenuItem(value: dept, child: Text(dept)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedDepartment = val),
                ),
                const SizedBox(height: 35),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: primaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Xác nhận lưu",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
    );
  }

  Widget _buildDateInput(
    TextEditingController controller,
    String hint,
    int maxLength,
    Color bgColor,
    Color primary,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: hint == "Năm" ? null : 85,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _inputDecoration(bgColor, isDark, primary).copyWith(
          hintText: hint,
          counterText: "",
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(Color bgColor, bool isDark, Color primary) {
    return InputDecoration(
      filled: true,
      fillColor: bgColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : primary.withOpacity(0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}
