import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Đảm bảo các dịch vụ hệ thống Flutter đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi động Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi động ứng dụng (Xác thực sẽ được xử lý tập trung qua Backend API)
  runApp(const MyApp());
}

final themeController = ThemeController();

// Notifier quản lý User đăng nhập (Nhận dữ liệu JSON từ Backend)
final ValueNotifier<Map<String, dynamic>?> currentUserNotifier = ValueNotifier(
  null,
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeController.lightTheme,
          darkTheme: themeController.darkTheme,
          themeMode: themeController.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const MainNavigation(),
        );
      },
    );
  }
}

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe trạng thái đăng nhập từ Backend response
    return ListenableBuilder(
      listenable: currentUserNotifier,
      builder: (context, _) {
        final userData = currentUserNotifier.value;

        if (userData != null) {
          // Đã đăng nhập: Chuyển vào Dashboard
          return EduGradeApp(
            uid: userData['uid'] ?? userData['username'] ?? 'unknown',
            role: userData['role'] ?? 'student',
            onLogout: () {
              // Xử lý Logout: Reset state về null để quay về trang Auth
              currentUserNotifier.value = null;
            },
          );
        } else {
          // Chưa đăng nhập: Hiện màn hình xác thực
          return AuthScreen(
            onLoginSuccess: (data) {
              // Lưu thông tin từ Backend vào state
              currentUserNotifier.value = data;
            },
          );
        }
      },
    );
  }
}
