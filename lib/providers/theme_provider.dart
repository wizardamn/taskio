import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

const Color _primaryBlue = Color(0xFF2196F3);
const Color _accentGreen = Color(0xFF4CAF50);

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'taskio_theme_mode';

  // 🔥 Дефолт сразу светлая
  ThemeMode _themeMode = ThemeMode.light;

  bool _isInitialized = false;

  ThemeMode get currentTheme => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;

  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _init();
  }

  // ======================================================
  // INIT
  // ======================================================

  Future<void> _init() async {
    await _loadTheme();
    _isInitialized = true;
    notifyListeners();
  }

  // ======================================================
  // THEME CONTROL
  // ======================================================

  void setTheme(ThemeMode mode) {
    if (_themeMode == mode) return;

    _themeMode = mode;
    _saveTheme(mode);

    AppLogger.info('Theme changed to $mode');
    notifyListeners();
  }

  void toggleTheme() {
    setTheme(
      _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }

  // ======================================================
  // STORAGE
  // ======================================================

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);

    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
            (e) => e.name == saved,
        orElse: () => ThemeMode.light,
      );
      AppLogger.info('Theme loaded: $_themeMode');
    } else {
      // 🔥 Если ничего не сохранено — всегда светлая
      _themeMode = ThemeMode.light;
    }
  }

  // ======================================================
  // LIGHT THEME
  // ======================================================

  ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.grey.shade50,
      appBarTheme: const AppBarTheme(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // DARK THEME
  // ======================================================

  ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}