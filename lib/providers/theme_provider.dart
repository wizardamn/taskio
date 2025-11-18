import 'package:flutter/material.dart';

// Цвета, вдохновленные вашей иконкой (синий и зеленый)
const Color _primaryBlue = Color(0xFF2196F3); // Яркий синий
const Color _accentGreen = Color(0xFF4CAF50); // Зеленый для акцента

class ThemeProvider extends ChangeNotifier {
  // 💡 Используем более точное имя переменной
  bool _isDark = false;
  bool get isDark => _isDark;
  bool get isDarkMode => _isDark;

  ThemeMode get currentTheme => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // ✅ СВЕТЛАЯ ТЕМА (LIGHT THEME)
  // ------------------------------------------------------------------
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Основная цветовая схема
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryBlue,
        primary: _primaryBlue,
        secondary: _accentGreen,
        background: Colors.grey.shade50, // Очень светлый фон
        surface: Colors.white, // Поверхности/Карточки белые
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        color: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Card Theme (Плавные, закругленные карточки)
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),

      // Input Decoration (для полей ввода)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),

      // ✅ Анимации и переходы
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ✅ Детализация: кнопки с акцентом
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // ✅ ТЕМНАЯ ТЕМА (DARK THEME)
  // ------------------------------------------------------------------
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Основная цветовая схема
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryBlue,
        primary: _primaryBlue,
        secondary: _accentGreen,
        brightness: Brightness.dark,
        background: const Color(0xFF121212), // Очень темный фон
        surface: const Color(0xFF1E1E1E), // Темные поверхности/Карточки
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.black,
        onBackground: Colors.white70,
        onSurface: Colors.white,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        color: const Color(0xFF1E1E1E), // Темнее, чем primary
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Card Theme
      cardTheme: CardTheme(
        elevation: 4,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C), // Светлее, чем фон
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: TextStyle(color: Colors.grey.shade400),
        hintStyle: TextStyle(color: Colors.grey.shade600),
      ),

      // ✅ Анимации и переходы
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ✅ Детализация: кнопки с акцентом
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}