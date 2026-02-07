import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final TextEditingController _semesterController = TextEditingController();

  DateTime? _selectedDeadline;
  bool _isManualLock = false;
  bool _isFetching = false;
  bool _isSaving = false;

  final Color primaryColor = const Color(0xFF6366F1);

  @override
  void dispose() {
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    String semesterID = _semesterController.text.trim();
    if (semesterID.isEmpty) return;

    setState(() => _isFetching = true);
    try {
      final settings = await apiService.getRegistrationSettings(semesterID);
      if (settings != null) {
        setState(() {
          if (settings['deadline'] != null) {
            _selectedDeadline = DateTime.parse(settings['deadline']);
          } else {
            _selectedDeadline = null;
          }
          _isManualLock = settings['manualLock'] ?? false;
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi tải cấu hình: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _saveConfig() async {
    String semesterID = _semesterController.text.trim();
    if (semesterID.isEmpty) {
      _showSnackBar("Vui lòng nhập mã học kỳ trước khi lưu", isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await apiService.updateRegistrationSettings({
        'semester': semesterID,
        'deadline': _selectedDeadline?.toIso8601String(),
        'manualLock': _isManualLock,
        'isLocked': _isManualLock, // Backend also uses this field
      });
      _showSnackBar("✅ Đã cập nhật cấu hình $semesterID");
    } catch (e) {
      _showSnackBar("❌ Lỗi khi lưu: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDateTime() async {
    if (_semesterController.text.isEmpty) {
      _showSnackBar("Vui lòng nhập mã học kỳ trước", isError: true);
      return;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
                colorScheme: ColorScheme.dark(
                  primary: primaryColor,
                  surface: const Color(0xFF111C2E),
                ),
              )
            : ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(primary: primaryColor),
              ),
        child: child!,
      ),
    );

    if (date == null || !mounted) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDeadline ?? DateTime.now()),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDeadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A1221) : const Color(0xFFE8F1FF);
    final cardColor = isDark ? const Color(0xFF111C2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "CẤU HÌNH HỆ THỐNG",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.1,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSectionTitle("HỌC KỲ ĐANG XỬ LÝ", isDark),
            const SizedBox(height: 12),
            _buildDecoratedContainer(
              isDark: isDark,
              cardColor: cardColor,
              child: TextField(
                controller: _semesterController,
                onSubmitted: (_) => _fetchConfig(),
                textInputAction: TextInputAction.search,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Nhập mã học kỳ (VD: HK241)...",
                  hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.auto_awesome_motion_rounded,
                    color: primaryColor,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: _fetchConfig,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 25),

            Expanded(
              child: _isFetching
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSectionTitle("THIẾT LẬP THỜI GIAN", isDark),
                        const SizedBox(height: 12),
                        _buildDecoratedContainer(
                          isDark: isDark,
                          cardColor: cardColor,
                          child: ListTile(
                            leading: _buildIconFrame(
                              Icons.timer_outlined,
                              primaryColor,
                            ),
                            title: Text(
                              "Hạn chót đăng ký",
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              _selectedDeadline == null
                                  ? "Chưa thiết lập"
                                  : DateFormat(
                                      'HH:mm • dd/MM/yyyy',
                                    ).format(_selectedDeadline!),
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.edit_calendar_rounded,
                                color: primaryColor,
                              ),
                              onPressed: _pickDateTime,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle("QUẢN TRỊ VIÊN", isDark),
                        const SizedBox(height: 12),
                        _buildDecoratedContainer(
                          isDark: isDark,
                          cardColor: cardColor,
                          child: SwitchListTile(
                            secondary: _buildIconFrame(
                              Icons.lock_clock,
                              Colors.amber,
                            ),
                            title: Text(
                              "Khóa đăng ký thủ công",
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "Dừng tất cả hoạt động đăng ký",
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                            value: _isManualLock,
                            activeColor: primaryColor,
                            onChanged: _semesterController.text.isEmpty
                                ? null
                                : (val) {
                                    setState(() => _isManualLock = val);
                                    _saveConfig();
                                  },
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildStatusInfo(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark
              ? Colors.white54
              : const Color(0xFF6366F1).withOpacity(0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDecoratedContainer({
    required Widget child,
    required bool isDark,
    required Color cardColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIconFrame(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildStatusInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Cấu hình này áp dụng riêng cho học kỳ được chọn. Hãy đảm bảo mã học kỳ chính xác.",
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF6366F1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}
