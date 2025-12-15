import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // URL для перенаправления (Deep Link)
  final String _emailRedirectTo = 'https://yqcywpkkdwkmqposwyoz.supabase.co/auth/v1/callback';

  Stream<User?> get authStateChanges => _client.auth.onAuthStateChange.map((event) {
    return event.session?.user;
  });

  /// Регистрация нового пользователя.
  Future<bool> signUp(String email, String password, String fullName, String role) async {
    try {
      if (email.isEmpty || password.isEmpty || fullName.isEmpty || role.isEmpty) {
        throw Exception('Все поля должны быть заполнены.');
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
        emailRedirectTo: _emailRedirectTo,
      );

      if (response.session == null && response.user == null) {
        throw Exception('Неизвестная ошибка регистрации. Проверьте данные.');
      }

      return true;
    } on AuthException catch (e) {
      debugPrint('Supabase Auth Error (SignUp): ${e.message}');
      throw Exception(_mapAuthExceptionToRussian(e.message));
    } catch (e) {
      debugPrint('General Error (SignUp): $e');
      throw Exception('Непредвиденная ошибка регистрации. Попробуйте снова.');
    }
  }

  /// Вход пользователя по email и паролю.
  Future<bool> signIn(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email и пароль должны быть заполнены.');
      }

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw Exception('Вход не удался. Проверьте данные.');
      }

      return true;
    } on AuthException catch (e) {
      debugPrint('Supabase Auth Error (SignIn): ${e.message}');
      throw Exception(_mapAuthExceptionToRussian(e.message));
    } catch (e) {
      debugPrint('General Error (SignIn): $e');
      throw Exception('Не удалось войти: $e');
    }
  }

  /// Выход из аккаунта.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      debugPrint('Supabase Auth Error (SignOut): ${e.message}');
      throw Exception('Ошибка при выходе: ${_mapAuthExceptionToRussian(e.message)}');
    } catch (e) {
      throw Exception('Неизвестная ошибка при выходе.');
    }
  }

  /// Получение профиля текущего пользователя
  Future<ProfileModel?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select('id, full_name, role, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        debugPrint('[AuthService] Профиль не найден, создаем новый...');

        final metadataRole = user.userMetadata?['role'] as String?;
        final metadataName = user.userMetadata?['full_name'] as String?;

        final name = metadataName ?? user.email?.split('@').first ?? 'Пользователь';
        final role = metadataRole ?? 'student';

        // ИСПРАВЛЕНО: Убрано поле 'email', так как его нет в таблице profiles
        await _client.from('profiles').insert({
          'id': user.id,
          'full_name': name,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Рекурсивный вызов для получения созданного профиля
        return getProfile();
      }

      return ProfileModel.fromJson(data, user);
    } catch (e) {
      debugPrint('Error getting profile: $e');
      throw Exception('Ошибка при загрузке профиля: $e');
    }
  }

  String _mapAuthExceptionToRussian(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return 'Неверный логин или пароль.';
    }
    if (lower.contains('user already exists')) {
      return 'Пользователь уже существует.';
    }
    return 'Ошибка авторизации: $message';
  }
}