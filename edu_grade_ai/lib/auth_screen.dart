import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthMode { login, signup, forgotPassword }

class AuthScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onLoginSuccess;
  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  AuthMode authMode = AuthMode.login;
  bool _isResettingStep2 = false;
  bool _isLoading = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  void _showStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handlePrimaryButton() async {
    if (_isLoading) return;
    final usernameOrEmail = _usernameController.text.trim();
    final password = _passwordController.text;

    if (authMode != AuthMode.forgotPassword || !_isResettingStep2) {
      if (usernameOrEmail.isEmpty ||
          (authMode != AuthMode.forgotPassword && password.isEmpty)) {
        _showStatus("Vui lòng nhập đầy đủ thông tin", isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (authMode == AuthMode.login) {
        // --- CHẾ ĐỘ ĐĂNG NHẬP HYBRID ---
        Map<String, dynamic>? result;
        bool shouldTryFirebase = false;

        try {
          // 1. Thử login thông thường qua Backend trước
          result = await apiService.login(usernameOrEmail, password);
          if (result['require_firebase_auth'] == true) {
            shouldTryFirebase = true;
          }
        } catch (e) {
          // Nếu Backend báo lỗi (ví dụ 401) NHƯNG username là Email -> Có thể là Admin mới tạo trên Auth tab
          if (usernameOrEmail.contains('@')) {
            shouldTryFirebase = true;
          } else {
            rethrow; // Lỗi thật cho Student/Teacher
          }
        }

        // 2. Chạy luồng Firebase Auth (Dành cho Admin)
        if (shouldTryFirebase) {
          try {
            final userCredential = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
                  email: usernameOrEmail.contains('@')
                      ? usernameOrEmail
                      : "$usernameOrEmail@edugrade.ai",
                  password: password,
                );

            final token = await userCredential.user?.getIdToken();
            if (token == null) throw "Không lấy được token xác thực";

            // Gửi token lên BE -> BE sẽ tự tạo hồ sơ Firestore nếu UID/Email này chưa có
            result = await apiService.loginWithFirebase(token);
          } on FirebaseAuthException catch (fe) {
            throw "Xác thực Firebase thất bại: ${fe.message}";
          }
        }

        // 3. Xử lý kết quả trả về cuối cùng
        if (result != null && result['success'] == true) {
          final userData = result['user'];
          final Map<String, dynamic> mappedData = {
            'uid': userData['uid'],
            'username': userData['username'],
            'role': userData['role'] ?? 'student',
            'fullName': userData['fullName'] ?? 'Người dùng',
            'classId': userData['classId'] ?? '',
          };
          _showStatus("Đăng nhập thành công!");
          widget.onLoginSuccess(mappedData);
        } else {
          throw result?['message'] ?? "Đăng nhập thất bại";
        }
      } else if (authMode == AuthMode.signup) {
        // --- REGISTER VIA BACKEND API ---
        final fullName = _fullNameController.text.trim();

        if (fullName.isEmpty) throw "Vui lòng nhập họ tên";

        final result = await apiService.register(
          username: usernameOrEmail,
          password: password,
          fullName: fullName,
        );

        if (result['success'] == true) {
          _showStatus("Đăng ký thành công!");
          setState(() => authMode = AuthMode.login);
        }
      } else if (authMode == AuthMode.forgotPassword) {
        // --- PASSWORD RESET VIA BACKEND API ---
        if (!_isResettingStep2) {
          bool exists = await apiService.checkUsernameExists(usernameOrEmail);
          if (!exists) throw "Username không tồn tại";
          setState(() => _isResettingStep2 = true);
        } else {
          if (_newPasswordController.text != _confirmPasswordController.text)
            throw "Mật khẩu không khớp";

          await apiService.updatePassword(
            usernameOrEmail,
            _newPasswordController.text,
          );

          _showStatus("Đổi mật khẩu thành công!");
          setState(() {
            authMode = AuthMode.login;
            _isResettingStep2 = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("Exception:"))
        errorMsg = errorMsg.split("Exception:").last.trim();
      _showStatus(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1);
    const textColor = Colors.black87;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 400,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                decoration: BoxDecoration(
                  color: Colors.white, // Trắng hoàn toàn theo ảnh
                  borderRadius: BorderRadius.circular(40), // Bo góc sâu hơn
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title
                    _buildTitle(textColor),
                    const SizedBox(height: 40),
                    // Form
                    _buildFormFields(primaryColor, textColor),
                    const SizedBox(height: 40),
                    // Button
                    _buildPrimaryButton(primaryColor),
                    const SizedBox(height: 24),
                    // Link
                    _buildSwitchModeLinks(primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(Color textColor) {
    String title = authMode == AuthMode.login
        ? "Welcome Back"
        : (authMode == AuthMode.signup ? "Create Account" : "Reset Password");
    return Text(
      title,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildFormFields(Color primaryColor, Color textColor) {
    return Column(
      children: [
        if (!_isResettingStep2)
          _textField(
            "Username / Email",
            Icons.person_outline,
            primaryColor,
            textColor,
            controller: _usernameController,
          ),
        if (authMode == AuthMode.signup) ...[
          const SizedBox(height: 20),
          _textField(
            "Full Name",
            Icons.badge_outlined,
            primaryColor,
            textColor,
            controller: _fullNameController,
          ),
        ],
        if (authMode != AuthMode.forgotPassword) ...[
          const SizedBox(height: 20),
          _textField(
            "Password",
            Icons.lock_outline,
            primaryColor,
            textColor,
            isPassword: true,
            obscure: _obscurePassword,
            controller: _passwordController,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ],
        if (_isResettingStep2) ...[
          _textField(
            "New Password",
            Icons.vpn_key,
            primaryColor,
            textColor,
            isPassword: true,
            obscure: _obscureNewPassword,
            controller: _newPasswordController,
            onToggle: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
          const SizedBox(height: 20),
          _textField(
            "Confirm Password",
            Icons.check_circle,
            primaryColor,
            textColor,
            isPassword: true,
            obscure: _obscureConfirmPassword,
            controller: _confirmPasswordController,
            onToggle: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
        ],
      ],
    );
  }

  Widget _textField(
    String label,
    IconData icon,
    Color primaryColor,
    Color textColor, {
    bool isPassword = false,
    bool obscure = false,
    TextEditingController? controller,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      cursorColor: primaryColor,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF6366F1),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF94A3B8),
                  size: 22,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // Màu xám cực nhạt như ảnh
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        // Border mặc định
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        // Border khi nhấn vào (Y chang ảnh image_12ff05.png)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(Color color) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePrimaryButton,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Continue",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _buildSwitchModeLinks(Color color) {
    return TextButton(
      onPressed: () => setState(() {
        authMode = authMode == AuthMode.login
            ? AuthMode.signup
            : AuthMode.login;
        _isResettingStep2 = false;
      }),
      child: Text(
        authMode == AuthMode.login
            ? "Don't have an account? Sign Up"
            : "Back to Login",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }
}
