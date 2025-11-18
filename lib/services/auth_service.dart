import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // URL для редиректа (для веб/диплинков)
  final String _emailRedirectTo = 'https://yqcywpkkdwkmqposwyoz.supabase.co/auth/v1/callback';

  /// Регистрация нового пользователя.
  Future<bool> signUp(String email, String password, String fullName, String role) async {
    try {
      if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
        throw Exception('Все поля должны быть заполнены.');
      }
      if (role.isEmpty) {
        throw Exception('Роль не выбрана.');
      }

      // ✅ ИСПРАВЛЕНИЕ: В Supabase Flutter v2 параметры data и emailRedirectTo
      // передаются прямо в метод signUp, без обертки options.
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
        emailRedirectTo: _emailRedirectTo,
      );

      final user = response.user;

      // Если user == null, значит требуется подтверждение email.
      if (user == null) {
        return true;
      }

      // Триггер в БД создаст профиль автоматически.
      return true;
    } on AuthException catch (e) {
      throw Exception('Ошибка регистрации: ${e.message}');
    } catch (e) {
      throw Exception('Непредвиденная ошибка регистрации: $e');
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

      if (response.user == null) {
        throw Exception('Ошибка входа. Возможно, email не подтвержден.');
      }
      return true;
    } on AuthException catch (e) {
      throw Exception('Ошибка входа: ${e.message}');
    } catch (e) {
      throw Exception('Не удалось войти: $e');
    }
  }

  /// Выход из аккаунта.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Получить профиль текущего пользователя.
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
        // Попытка восстановить профиль из метаданных, если триггер не сработал
        final metadataRole = user.userMetadata?['role'] as String?;
        final metadataName = user.userMetadata?['full_name'] as String?;

        if (metadataRole != null && metadataName != null) {
          await _client.from('profiles').insert({
            'id': user.id,
            'full_name': metadataName,
            'role': metadataRole,
            'created_at': DateTime.now().toIso8601String(),
          });
          return getProfile(); // Рекурсивный вызов после создания
        }
        return null;
      }

      return ProfileModel.fromJson(data, user);
    } on PostgrestException catch (e) {
      throw Exception('Ошибка БД при загрузке профиля: ${e.message}');
    } catch (e) {
      throw Exception('Ошибка при загрузке профиля: $e');
    }
  }
}