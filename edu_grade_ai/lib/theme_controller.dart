import 'package:flutter/material.dart';

class ThemeController with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // Thông báo cho toàn bộ app cập nhật giao diện
  }

  // Màu sắc tùy chỉnh cho Light Mode (Pastel Blue)
  ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFE6F0FF),
        primaryColor: const Color(0xFF6366F1),
        cardColor: Colors.white,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1E293B)),
        ),
      );

  // Màu sắc tùy chỉnh cho Dark Mode
  ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Xanh đen đậm
        primaryColor: const Color(0xFF818CF8),
        cardColor: const Color(0xFF1E293B),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E293B)),
      );
}