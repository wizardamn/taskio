import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  // Инициализируем наш сервис
  final AuthService _authService = AuthService();
  final supabase = Supabase.instance.client;

  // Геттер для получения текущего пользователя
  User? get user => supabase.auth.currentUser;

  // Геттер, указывающий, авторизован ли пользователь
  bool get isAuthenticated => user != null;

  /// Вход в систему
  Future<void> signIn(String email, String password) async {
    try {
      // Вызываем метод сервиса.
      await _authService.signIn(email, password);
      // Уведомляем слушателей об изменении состояния
      notifyListeners();
    } catch (e) {
      // ✅ ДОБАВЛЕНО: Явное логирование ошибки в консоль
      debugPrint('Ошибка входа (AuthProvider): $e');
      // Обязательно пробрасываем ошибку дальше, чтобы ее мог обработать UI
      rethrow;
    }
  }

  /// Регистрация
  Future<void> signUp(String email, String password, String fullName, String role) async {
    try {
      await _authService.signUp(
        email,
        password,
        fullName,
        role,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка регистрации (AuthProvider): $e');
      rethrow;
    }
  }

  /// Выход из системы
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}