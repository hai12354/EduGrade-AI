import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../widgets/class_card.dart';
import '../services/api_service.dart';

class AdminClassesScreen extends StatefulWidget {
  final String userRole;
  final String? userId;
  final String? userClassId;
  final List<String>? registeredClassIds; // NEW
  final String? userName;

  const AdminClassesScreen({
    super.key,
    required this.userRole,
    this.userId,
    this.userClassId,
    this.registeredClassIds,
    this.userName,
  });

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  // REMOVED: final ClassService _classService = ClassService();

  // Controllers
  final TextEditingController _classIdController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _maxSlotsController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _semesterInputController =
      TextEditingController();

  // Search & Filter
  String _searchSemester = "";
  final TextEditingController _semesterSearchController = TextEditingController(
    text: "",
  );

  String? _selectedTeacherName;
  final Color primaryColor = const Color(0xFF6366F1);

  // --- STATE VARIABLES (REPLACING STREAMS) ---
  List<ClassModel> _classes = [];
  Map<String, dynamic>? _registrationSettings;
  List<String> _registeredClassIds = []; // NEW: changed from single String
  List<dynamic> _teachers = [];
  bool _isLoadingClasses = false;
  bool _isLoadingSettings = false;

  @override
  void initState() {
    super.initState();
    // Initialize data
    _registeredClassIds =
        widget.userClassId != null && widget.userClassId!.isNotEmpty
        ? [widget.userClassId!]
        : [];
    _fetchTeachers();
  }

  @override
  void dispose() {
    for (var controller in [
      _classIdController,
      _classNameController,
      _maxSlotsController,
      _dayController,
      _periodController,
      _roomController,
      _startDateController,
      _endDateController,
      _semesterSearchController,
      _semesterInputController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- DATA FETCHING ---

  Future<void> _fetchClasses() async {
    if (_searchSemester.isEmpty) return;

    setState(() => _isLoadingClasses = true);
    try {
      final rawClasses = await apiService.getClasses(_searchSemester);
      setState(() {
        _classes = rawClasses.map((json) => ClassModel.fromMap(json)).toList();
      });
    } catch (e) {
      _showSnackBar("Lỗi tải lớp học: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _fetchSettings() async {
    if (_searchSemester.isEmpty) return;

    setState(() => _isLoadingSettings = true);
    try {
      final settings = await apiService.getRegistrationSettings(
        _searchSemester,
      );
      setState(() {
        _registrationSettings = settings;
      });
    } catch (e) {
      // Ignore error or log
      print("Error loading settings: $e");
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _fetchUserClass() async {
    if (widget.userId == null) return;
    try {
      final user = await apiService.getUser(widget.userId!);
      if (user != null) {
        setState(() {
          if (user['registeredClassIds'] is List) {
            _registeredClassIds = List<String>.from(user['registeredClassIds']);
          } else if (user['classId'] != null) {
            _registeredClassIds = [user['classId'].toString()];
          } else {
            _registeredClassIds = [];
          }
        });
      }
    } catch (e) {
      print("Error loading user class: $e");
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchClasses(), _fetchSettings(), _fetchUserClass()]);
  }

  Future<void> _fetchTeachers() async {
    try {
      final teachers = await apiService.getTeachers();
      setState(() {
        _teachers = teachers;
      });
    } catch (e) {
      print("Error loading teachers: $e");
    }
  }

  // --- WIDGETS ---

  Widget _buildRegistrationDeadlineBanner(String semester) {
    if (_registrationSettings == null && !_isLoadingSettings) {
      if (semester.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Học kỳ '$semester' chưa được thiết lập hạn chót.",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingSettings) return const LinearProgressIndicator();

    // Parse Settings
    // Backend returns ISO string for deadline
    String? deadlineStr = _registrationSettings?['deadline'];
    bool isManualLock =
        _registrationSettings?['manualLock'] ??
        false; // BE sends manualLock, FE expected isManualLock. Check settings_router.
    // settings_router.py sends: isLocked, deadline, manualLock.

    DateTime? deadline;
    if (deadlineStr != null) {
      deadline = DateTime.tryParse(deadlineStr);
    }

    // Logic fallback
    deadline ??= DateTime.now();
    bool isExpired =
        DateTime.now().isAfter(deadline) ||
        isManualLock; // Or isLocked? BE logic is separate.

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withOpacity(0.1)
            : primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpired
              ? Colors.red.withOpacity(0.5)
              : primaryColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.lock_clock_rounded : Icons.timer_outlined,
            color: isExpired ? Colors.red : primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Học kỳ $semester: ${isExpired ? "CỔNG ĐANG ĐÓNG" : "CỔNG ĐANG MỞ"}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isExpired ? Colors.red : primaryColor,
                  ),
                ),
                Text(
                  isExpired
                      ? "Vui lòng liên hệ giáo vụ để biết thêm chi tiết."
                      : "Hạn chót: ${DateFormat('HH:mm - dd/MM/yyyy').format(deadline)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red[700] : primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterSearchInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _semesterSearchController,
        onSubmitted: (value) {
          setState(() {
            _searchSemester = value.trim();
          });
          _loadData(); // Load data on submit
        },
        decoration: InputDecoration(
          hintText: "Nhập mã học kỳ (vd: hk1_2024) rồi nhấn Enter...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(
                () => _searchSemester = _semesterSearchController.text.trim(),
              );
              _loadData();
            },
          ),
          filled: true,
          fillColor: isDark ? Colors.white10 : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Quản lý lớp học",
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
          ),
        ),
        actions: [
          if (widget.userRole == 'admin')
            IconButton(
              onPressed: _showAddClassDialog,
              icon: const Icon(
                Icons.add_circle_rounded,
                color: Colors.blue,
                size: 30,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            _buildSemesterSearchInput(isDark),
            _buildRegistrationDeadlineBanner(_searchSemester),

            Expanded(
              child: _isLoadingClasses
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                      itemCount: _classes.length,
                      itemBuilder: (context, index) {
                        final classData = _classes[index];
                        return ClassCard(
                          classData: classData,
                          userRole: widget.userRole,
                          userId: widget.userId,
                          registeredClassIds:
                              _registeredClassIds, // Matches ClassCard def
                          userName: widget.userName,
                          onTap: () => _handleViewStudentList(classData),
                          onRegisterPressed: () =>
                              _handleRegistration(classData),
                          onDelete: () => _deleteClass(
                            classData.classId,
                            classData.className,
                          ),
                          onEdit: () => _showEditDialog(classData),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---

  Future<void> _addClass() async {
    final String cId = _classIdController.text.trim().toUpperCase();
    final String sem = _semesterInputController.text.trim();
    final String day = _dayController.text.trim();
    final String periods = "Tiết ${_periodController.text.trim()}";
    final String room = _roomController.text.trim();
    final String dateRange =
        "${_startDateController.text} - ${_endDateController.text}";
    // No longer construct 'schedule' manually if Backend expects atomic fields?
    // ClassModel expects split fields. But Backend expects schedule string?
    // I can send schedule string to match ClassModel logic.
    // ignore: unused_local_variable
    final String schedule = "$day | $periods | $room | $dateRange";

    if (cId.isEmpty ||
        sem.isEmpty ||
        _classNameController.text.isEmpty ||
        _selectedTeacherName == null) {
      _showSnackBar(
        "Vui lòng điền đầy đủ thông tin (bao gồm cả Học kỳ)",
        isError: true,
      );
      return;
    }

    try {
      final newClass = ClassModel(
        classId: cId,
        className: _classNameController.text.trim(),
        teacherName: _selectedTeacherName!,
        maxSlots: int.tryParse(_maxSlotsController.text) ?? 40,
        currentSlots: 0,
        dayOfWeek: day,
        periods: periods,
        room: room,
        dateRange: dateRange,
        semester: sem,
      );

      await apiService.createClass(newClass.toMap());

      if (mounted) {
        Navigator.pop(context);
        _clearControllers();
        _showSnackBar("Tạo lớp học thành công cho học kỳ $sem");
        // Reload if current semester matches
        if (_searchSemester == sem) _fetchClasses();
      }
    } catch (e) {
      if (mounted) _showSnackBar("Lỗi khi thêm: $e", isError: true);
    }
  }

  Future<void> _deleteClass(String classId, String className) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn có chắc muốn xóa lớp $className không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await apiService.deleteClass(classId);
        if (mounted) {
          _showSnackBar("Đã xóa lớp học thành công");
          _fetchClasses();
        }
      } catch (e) {
        if (mounted) _showSnackBar("Lỗi khi xóa: $e", isError: true);
      }
    }
  }

  Future<void> _updateClassName(ClassModel oldData, String newName) async {
    if (newName.isEmpty) return;
    try {
      // Create new object with Updated Name
      final updatedClass = ClassModel(
        classId: oldData.classId,
        className: newName,
        teacherName: oldData.teacherName,
        maxSlots: oldData.maxSlots,
        currentSlots: oldData.currentSlots,
        dayOfWeek: oldData.dayOfWeek,
        periods: oldData.periods,
        room: oldData.room,
        dateRange: oldData.dateRange,
        semester: oldData.semester,
      );

      await apiService.createClass(
        updatedClass.toMap(),
      ); // Re-use create for update

      if (mounted) {
        _showSnackBar("Cập nhật tên lớp thành công");
        _fetchClasses();
      }
    } catch (e) {
      if (mounted) _showSnackBar("Lỗi: $e", isError: true);
    }
  }

  Future<void> _handleRegistration(ClassModel classData) async {
    if (widget.userId == null) return;

    if (_registrationSettings != null) {
      // ... settings check remains the same ...
      String? deadlineStr = _registrationSettings?['deadline'];
      bool isManualLock = _registrationSettings?['manualLock'] ?? false;
      DateTime? deadline;
      if (deadlineStr != null) deadline = DateTime.tryParse(deadlineStr);

      if (isManualLock) {
        _showSnackBar("Học kỳ này đã đóng đăng ký!", isError: true);
        return;
      }
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        _showSnackBar(
          "Đã hết thời gian đăng ký học cho học kỳ này!",
          isError: true,
        );
        return;
      }
    }

    final bool isAlreadyRegistered = _registeredClassIds.contains(
      classData.classId,
    );

    if (isAlreadyRegistered) {
      _showConfirmDialog(
        title: "Hủy đăng ký",
        content: "Bạn muốn hủy đăng ký lớp ${classData.className}?",
        onConfirm: () => _unregisterClass(classData.classId),
      );
    } else {
      _registerClass(classData.classId);
    }
  }

  Future<void> _registerClass(String classId) async {
    try {
      await apiService.registerClass(
        userId: widget.userId!,
        classId: classId,
        semester: _searchSemester,
        isRegister: true,
      );
      if (mounted) {
        _showSnackBar("Đăng ký lớp thành công");
        await _loadData(); // REFRESH ALL IN PARALLEL
      }
    } catch (e) {
      String errMsg = e.toString().replaceFirst("Exception: ", "");
      if (errMsg.contains("unregister")) {
        errMsg = "Bạn phải hủy đăng ký lớp hiện tại trước khi đăng ký lớp mới!";
      } else if (errMsg.contains("full")) {
        errMsg = "Lớp này hiện đã đủ số lượng sinh viên!";
      } else if (errMsg.contains("semester")) {
        errMsg = "Lỗi học kỳ không khớp. Vui lòng thử lại!";
      }
      _showSnackBar(errMsg, isError: true);
    }
  }

  Future<void> _unregisterClass(String classId) async {
    try {
      await apiService.registerClass(
        userId: widget.userId!,
        classId: classId,
        semester: _searchSemester,
        isRegister: false,
      );
      if (mounted) {
        _showSnackBar("Đã hủy đăng ký thành công");
        await _loadData();
      }
    } catch (e) {
      String errMsg = e.toString().replaceFirst("Exception: ", "");
      _showSnackBar("Lỗi hủy đăng ký: $errMsg", isError: true);
    }
  }

  // --- UI HELPERS ---

  void _showEditDialog(ClassModel classData) {
    final TextEditingController editCtrl = TextEditingController(
      text: classData.className,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Chỉnh sửa tên lớp"),
        content: TextField(
          controller: editCtrl,
          decoration: const InputDecoration(hintText: "Nhập tên lớp mới"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("HỦY"),
          ),
          ElevatedButton(
            onPressed: () {
              String name = editCtrl.text.trim();
              Navigator.pop(ctx);
              _updateClassName(classData, name);
            },
            child: const Text("LƯU"),
          ),
        ],
      ),
    );
  }

  void _showAddClassDialog() {
    _fetchTeachers(); // Load teachers when opening dialog
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final screenWidth = MediaQuery.of(context).size.width;
          final Color dialogBg = isDark
              ? const Color(0xFF0F172A)
              : Colors.white;
          final Color inputFill = isDark
              ? const Color(0xFF334155)
              : const Color(0xFFF1F5F9);
          final Color textColor = isDark
              ? Colors.white
              : const Color(0xFF1E293B);
          final Color hintColor = isDark ? Colors.white54 : Colors.black45;

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Tạo lớp học mới",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: textColor,
                  ),
                ),
                Icon(Icons.add_chart_rounded, color: primaryColor, size: 28),
              ],
            ),
            content: SizedBox(
              width: screenWidth < 600 ? screenWidth * 0.95 : 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInput(
                      _semesterInputController,
                      "Mã học kỳ (vd: hk1_2024)",
                      Icons.calendar_today_rounded,
                      inputFill,
                      textColor,
                      hintColor,
                    ),
                    _buildInput(
                      _classIdController,
                      "Mã lớp",
                      Icons.vpn_key_rounded,
                      inputFill,
                      textColor,
                      hintColor,
                    ),
                    _buildInput(
                      _classNameController,
                      "Tên môn học",
                      Icons.book_rounded,
                      inputFill,
                      textColor,
                      hintColor,
                    ),
                    _buildTeacherDropdown(
                      isDark,
                      setDialogState,
                      inputFill,
                      textColor,
                      hintColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            _dayController,
                            "Thứ",
                            Icons.calendar_view_week_rounded,
                            inputFill,
                            textColor,
                            hintColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInput(
                            _periodController,
                            "Tiết",
                            Icons.access_time_filled_rounded,
                            inputFill,
                            textColor,
                            hintColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            _roomController,
                            "Phòng",
                            Icons.meeting_room_rounded,
                            inputFill,
                            textColor,
                            hintColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInput(
                            _maxSlotsController,
                            "Sĩ số",
                            Icons.groups_3_rounded,
                            inputFill,
                            textColor,
                            hintColor,
                            isNum: true,
                          ),
                        ),
                      ],
                    ),
                    _buildDateInput(
                      _startDateController,
                      "Ngày bắt đầu",
                      inputFill,
                      textColor,
                      hintColor,
                    ),
                    _buildDateInput(
                      _endDateController,
                      "Ngày kết thúc",
                      inputFill,
                      textColor,
                      hintColor,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "HỦY",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addClass,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "TẠO LỚP",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTeacherDropdown(
    bool isDark,
    StateSetter setDialogState,
    Color fill,
    Color text,
    Color hintCol,
  ) {
    if (_teachers.isEmpty) {
      // Try fetch if not loaded? Already called in _showAddClassDialog
      return const SizedBox(
        height: 50,
        child: Center(child: Text("Đang tải danh sách giáo viên...")),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _selectedTeacherName,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        hint: Text(
          "Chọn giáo viên",
          style: TextStyle(color: hintCol, fontSize: 14),
        ),
        items: _teachers
            .map(
              (doc) => DropdownMenuItem(
                value: doc['fullName'].toString(),
                child: Text(doc['fullName']),
              ),
            )
            .toList(),
        onChanged: (val) => setDialogState(() => _selectedTeacherName = val),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.school_rounded, color: primaryColor),
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // --- STUDENT LIST BOTTOM SHEET ---
  void _handleViewStudentList(ClassModel classData) {
    bool canView = false;
    if (widget.userRole == 'admin')
      canView = true;
    else if (widget.userRole == 'teacher' &&
        widget.userName == classData.teacherName)
      canView = true;
    else if (widget.userRole == 'student' &&
        _registeredClassIds.contains(classData.classId))
      canView = true;

    if (canView)
      _showStudentListBottomSheet(classData);
    else
      _showSnackBar("Bạn không có quyền xem danh sách lớp này", isError: true);
  }

  void _showStudentListBottomSheet(ClassModel classData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _StudentListSheet(
          classId: classData.classId,
          className: classData.className,
        );
      },
    );
  }

  // --- HELPERS ---
  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    Color fill,
    Color text,
    Color hintCol, {
    bool isNum = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: hintCol, fontSize: 14),
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDateInput(
    TextEditingController ctrl,
    String hint,
    Color fill,
    Color text,
    Color hintCol,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _selectDate(context, ctrl),
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.date_range_rounded,
            color: primaryColor,
            size: 20,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: hintCol, fontSize: 14),
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Đồng ý"),
          ),
        ],
      ),
    );
  }

  void _clearControllers() {
    for (var c in [
      _classIdController,
      _classNameController,
      _maxSlotsController,
      _dayController,
      _periodController,
      _roomController,
      _startDateController,
      _endDateController,
      _semesterInputController,
    ]) {
      c.clear();
    }
    setState(() => _selectedTeacherName = null);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildEmptyState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.folder_open_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          "Không có lớp học nào cho học kỳ này",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// Separate widget for Student List to handle its own loading state
class _StudentListSheet extends StatefulWidget {
  final String classId;
  final String className;
  const _StudentListSheet({required this.classId, required this.className});

  @override
  State<_StudentListSheet> createState() => _StudentListSheetState();
}

class _StudentListSheetState extends State<_StudentListSheet> {
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await apiService.getStudentsInClass(widget.classId);
      if (mounted) {
        setState(() {
          _students = students;
        });
      }
    } catch (e) {
      print("Error fetching students: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ... UI code ...
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.className,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            "Mã lớp: ${widget.classId}",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                ? const Center(
                    child: Text("Hệ thống đang cập nhật API danh sách..."),
                  )
                : ListView.separated(
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) =>
                        Text(_students[i]['fullName']), // Placeholder
                  ),
          ),
        ],
      ),
    );
  }
}
