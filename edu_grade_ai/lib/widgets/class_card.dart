import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../services/api_service.dart';

class ClassCard extends StatefulWidget {
  final ClassModel classData;
  final String userRole;
  final String? userId;
  final List<String>? registeredClassIds; // Changed from single String
  final String? userName;
  final VoidCallback? onTap;
  final Future<void> Function()? onRegisterPressed;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const ClassCard({
    super.key,
    required this.classData,
    required this.userRole,
    this.userId,
    this.registeredClassIds,
    this.userName,
    this.onTap,
    this.onRegisterPressed,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard> {
  bool _isLoading = false;

  Future<void> _handleAction() async {
    if (widget.onRegisterPressed != null) {
      setState(() => _isLoading = true);
      try {
        await widget.onRegisterPressed!();
      } catch (e) {
        debugPrint("Action Error: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMyClass =
        widget.registeredClassIds?.contains(widget.classData.classId) ?? false;
    final int currentCount = widget.classData.currentSlots;
    final bool isFull = currentCount >= widget.classData.maxSlots;
    const primaryColor = Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : const Color(0xFF64748B).withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isMyClass
              ? primaryColor
              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          width: isMyClass ? 2 : 1.2,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.classData.classId.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.classData.className,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.userRole == 'admin')
                    Row(
                      children: [
                        _buildCircleAction(
                          Icons.edit_rounded,
                          Colors.blueAccent,
                          () => _showEditSheet(context),
                        ),
                        const SizedBox(width: 8),
                        _buildCircleAction(
                          Icons.delete_outline_rounded,
                          Colors.redAccent,
                          () => _confirmDelete(context),
                        ),
                      ],
                    )
                  else if (isMyClass)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 28,
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.blueGrey[200],
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoTable(context, isDark),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSimpleInfo(
                      Icons.account_circle_outlined,
                      widget.classData.teacherName,
                      isDark: isDark,
                    ),
                  ),
                  _buildSlotBadge(
                    currentCount,
                    widget.classData.maxSlots,
                    isFull,
                    isMyClass,
                  ),
                ],
              ),
              if (widget.userRole == 'student') ...[
                const SizedBox(height: 20),
                _buildStudentButton(isMyClass, isFull, primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTable(BuildContext context, bool isDark) {
    final List<String> dateRanges = widget.classData.dateRange.isEmpty
        ? []
        : widget.classData.dateRange.split(',').map((e) => e.trim()).toList();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withAlpha(128)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildTableColumn(
              "THỨ / TIẾT",
              "${widget.classData.dayOfWeek}\n${widget.classData.periods}",
              isDark,
            ),
            _buildVerticalDivider(isDark),
            _buildTableColumn("PHÒNG", widget.classData.room, isDark),
            _buildVerticalDivider(isDark),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "LỊCH HỌC",
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF818CF8),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (dateRanges.isEmpty)
                    const Text(
                      "N/A",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF59E0B),
                      ),
                    )
                  else
                    ...dateRanges.map(
                      (date) => Text(
                        "(${date.replaceAll('-', ' → ')})",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF59E0B),
                          height: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableColumn(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) => VerticalDivider(
    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
    thickness: 1,
    width: 1,
  );

  Widget _buildCircleAction(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: color.withAlpha(25),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildSlotBadge(int current, int max, bool isFull, bool isMyClass) {
    final Color statusColor = isFull && !isMyClass
        ? const Color(0xFFEF4444)
        : (isMyClass ? const Color(0xFF6366F1) : const Color(0xFF10B981));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$current / $max",
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSimpleInfo(IconData icon, String text, {required bool isDark}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentButton(bool isMyClass, bool isFull, Color primaryColor) {
    final Color btnColor = isMyClass
        ? const Color(0xFFF43F5E)
        : (isFull ? Colors.grey : primaryColor);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || (isFull && !isMyClass))
            ? null
            : () => _handleAction(),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                isMyClass
                    ? "HỦY ĐĂNG KÝ"
                    : (isFull ? "LỚP ĐÃ ĐẦY" : "ĐĂNG KÝ NGAY"),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color labelColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final nameController = TextEditingController(
      text: widget.classData.className,
    );
    final teacherController = TextEditingController(
      text: widget.classData.teacherName,
    );
    final roomController = TextEditingController(text: widget.classData.room);
    final slotController = TextEditingController(
      text: widget.classData.periods.replaceAll("Tiết ", ""),
    );
    final dayController = TextEditingController(
      text: widget.classData.dayOfWeek,
    );
    final maxSlotsController = TextEditingController(
      text: widget.classData.maxSlots.toString(),
    );
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    List<String> dateRanges = widget.classData.dateRange.isEmpty
        ? []
        : widget.classData.dateRange.split(',').map((e) => e.trim()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Chỉnh sửa lớp học",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  "Mã lớp (ID)",
                  TextEditingController(text: widget.classData.classId),
                  labelColor,
                  Icons.vpn_key_rounded,
                  isDark,
                  readOnly: true,
                ),
                _buildTextField(
                  "Tên môn học",
                  nameController,
                  labelColor,
                  Icons.book_rounded,
                  isDark,
                ),
                _buildTextField(
                  "Giảng viên",
                  teacherController,
                  labelColor,
                  Icons.school_rounded,
                  isDark,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Thứ",
                        dayController,
                        labelColor,
                        Icons.calendar_today_rounded,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        "Tiết học",
                        slotController,
                        labelColor,
                        Icons.access_time_filled_rounded,
                        isDark,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Phòng",
                        roomController,
                        labelColor,
                        Icons.meeting_room_rounded,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        "Sĩ số",
                        maxSlotsController,
                        labelColor,
                        Icons.groups_rounded,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: Colors.white10),
                const Text(
                  "QUẢN LÝ ĐỢT HỌC",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF818CF8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDatePickerField(
                  "Bắt đầu",
                  startDateController,
                  Icons.event_note_rounded,
                  ctx,
                  setModalState,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildDatePickerField(
                  "Kết thúc",
                  endDateController,
                  Icons.event_available_rounded,
                  ctx,
                  setModalState,
                  isDark,
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      if (startDateController.text.isNotEmpty &&
                          endDateController.text.isNotEmpty) {
                        setModalState(() {
                          dateRanges.add(
                            "${startDateController.text}-${endDateController.text}",
                          );
                          startDateController.clear();
                          endDateController.clear();
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF818CF8),
                    ),
                    label: const Text(
                      "Xác nhận thêm đợt học",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ),
                ),
                if (dateRanges.isNotEmpty)
                  ...dateRanges.asMap().entries.map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.date_range_rounded,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        title: Text(
                          e.value,
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () =>
                              setModalState(() => dateRanges.removeAt(e.key)),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final String newDay = dayController.text.trim();
                      final String newPeriods =
                          "Tiết ${slotController.text.trim()}";
                      final String newRoom = roomController.text.trim();
                      final String newDates = dateRanges.join(', ');
                      final String finalSchedule =
                          "$newDay | $newPeriods | $newRoom | $newDates";
                      try {
                        await apiService.updateClass(widget.classData.classId, {
                          'className': nameController.text.trim(),
                          'teacherName': teacherController.text.trim(),
                          'maxSlots':
                              int.tryParse(maxSlotsController.text) ??
                              widget.classData.maxSlots,
                          'dayOfWeek': newDay,
                          'periods': newPeriods,
                          'room': newRoom,
                          'dateRange': newDates,
                          'schedule': finalSchedule,
                        });
                        if (context.mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("✅ Cập nhật dữ liệu thành công!"),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          if (widget.onEdit != null) widget.onEdit!();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("❌ Lỗi: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      "LƯU THAY ĐỔI",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Lớp ${widget.classData.classId} sẽ bị xóa vĩnh viễn?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await apiService.deleteClass(widget.classData.classId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🗑️ Đã xóa lớp thành công"),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (widget.onDelete != null) widget.onDelete!();
                }
              } catch (e) {
                debugPrint("Lỗi xóa: $e");
              }
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color labelColor,
    IconData icon,
    bool isDark, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.black45,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF818CF8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(
    String label,
    TextEditingController controller,
    IconData icon,
    BuildContext context,
    StateSetter setModalState,
    bool isDark,
  ) {
    return TextField(
      controller: controller,
      readOnly: true,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1E293B),
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1,
        ),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF818CF8)),
        filled: true,
        fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onTap: () async {
        if (!Navigator.of(context).mounted) return;
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: isDark ? ThemeData.dark() : ThemeData.light(),
            child: child!,
          ),
        );
        if (pickedDate != null) {
          setModalState(
            () => controller.text =
                "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}",
          );
        }
      },
    );
  }
}
