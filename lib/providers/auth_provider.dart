// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? get user => supabase.auth.currentUser;
  bool get isAuthenticated => user != null;

  // --- СОСТОЯНИЕ: Гость ---
  bool _isGuest = false;
  bool get isGuest => _isGuest;
  String _guestId = '';
  String _guestName = 'Гость';
  // --- КОНЕЦ СОСТОЯНИЯ ---

  /// Вход как гость
  Future<void> signInAsGuest() async {
    _setLoading(true);
    try {
      // 1. Сначала выходим из текущей сессии (если есть)
      await _authService.signOut(); // Вызываем метод из AuthService

      // 2. Устанавливаем гостевые данные
      _setGuestUser(true); // Устанавливаем флаг гостя

      // 3. Уведомляем слушателей об изменении состояния
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка входа как гость (AuthProvider): $e');
      rethrow; // Пробрасываем ошибку дальше для обработки в UI
    } finally {
      _setLoading(false);
    }
  }

  // --- ВСПОМОГАТЕЛЬНЫЙ МЕТОД: Установка гостевого состояния ---
  void _setGuestUser(bool isGuest) {
    _isGuest = isGuest;
    if (isGuest) {
      // Если это гость, устанавливаем уникальный ID и имя
      _guestId = 'guest_user_${DateTime.now().millisecondsSinceEpoch}';
      _guestName = 'Гость';
    } else {
      // Если не гость, сбрасываем на пустые значения
      _guestId = '';
      _guestName = 'Гость'; // Имя по умолчанию, если не гость
    }
    notifyListeners(); // Уведомляем слушателей об изменении состояния
  }
  // --- КОНЕЦ ВСПОМОГАТЕЛЬНОГО МЕТОДА ---

  /// Возвращает ID пользователя или гостя
  String? get userId => isGuest ? _guestId : user?.id;

  /// Возвращает имя пользователя или гостя
  String get userName => isGuest ? _guestName : (user?.userMetadata?['full_name'] ?? user?.email?.split('@').first ?? 'Пользователь');

  /// Вход в систему
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signIn(email, password);
      _setGuestUser(false); // Сбрасываем гостевой режим при входе
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка входа (AuthProvider): $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Регистрация
  Future<void> signUp(String email, String password, String fullName, String role) async {
    _setLoading(true);
    try {
      await _authService.signUp(email, password, fullName, role);
      _setGuestUser(false); // Сбрасываем гостевой режим при регистрации
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка регистрации (AuthProvider): $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Выход из системы
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _setGuestUser(false); // Сбрасываем гостевой режим при выходе
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Очистка состояния (например, при выходе или ошибке)
  void clear() {
    _setGuestUser(false); // Сбрасываем гостевой режим
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
}