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
    // Вызываем метод сервиса. Если будет ошибка, она пробросится в UI.
    await _authService.signIn(email, password);
    // Уведомляем слушателей (например, LoginWrapper) об изменении состояния
    notifyListeners();
  }

  /// Регистрация
  // ✅ ИСПРАВЛЕНО: Теперь принимает все 4 параметра, чтобы передать их в сервис
  Future<void> signUp(String email, String password, String fullName, String role) async {
    await _authService.signUp(
      email,
      password,
      fullName,
      role,
    );
    notifyListeners();
  }

  /// Выход из системы
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}