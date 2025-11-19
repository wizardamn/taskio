import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // URL для редиректа (для веб/диплинков)
  final String _emailRedirectTo = 'https://yqcywpkkdwkmqposwyoz.supabase.co/auth/v1/callback';

  // ------------------------------------------------
  // ✅ УПРАВЛЕНИЕ СОСТОЯНИЕМ
  // ------------------------------------------------

  /// Поток для отслеживания состояния авторизации пользователя.
  Stream<User?> get authStateChanges => _client.auth.onAuthStateChange.map((event) {
    // Возвращаем пользователя, если сессия существует
    return event.session?.user;
  });

  // ------------------------------------------------
  // ✅ АВТОРИЗАЦИЯ И РЕГИСТРАЦИЯ
  // ------------------------------------------------

  /// Регистрация нового пользователя.
  Future<bool> signUp(String email, String password, String fullName, String role) async {
    try {
      if (email.isEmpty || password.isEmpty || fullName.isEmpty || role.isEmpty) {
        throw Exception('Все поля должны быть заполнены.');
      }

      // Supabase Flutter SDK автоматически обрабатывает метаданные.
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
        emailRedirectTo: _emailRedirectTo,
      );

      // Если user == null, значит требуется подтверждение email.
      if (response.user == null) {
        return true;
      }

      // После успешной регистрации и авторизации (если не требуется подтверждение),
      // профиль либо будет создан триггером, либо мы его создадим в getProfile.

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

      if (response.user == null || response.session == null) {
        // Это должно быть обработано AuthException, но для надежности
        throw Exception('Вход не удался. Проверьте данные.');
      }

      // ✅ Надежный способ гарантировать сохранение сессии локально.
      // Хотя это обычно происходит автоматически, явное сохранение повышает стабильность.
      // await _client.auth.setSession(response.session!);

      return true;
    } on AuthException catch (e) {
      debugPrint('Supabase Auth Error (SignIn): ${e.message}');
      // ✅ Бросаем переведенную ошибку для лучшей диагностики проблемы
      throw Exception(_mapAuthExceptionToRussian(e.message));
    } catch (e) {
      debugPrint('General Error (SignIn): $e');
      throw Exception('Не удалось войти: $e');
    }
  }

  /// Выход из аккаунта.
  Future<void> signOut() async {
    try {
      // ✅ КРИТИЧЕСКИ ВАЖНО: Правильный вызов signOut, очищающий все сессии
      await _client.auth.signOut();
      debugPrint('User signed out successfully and session cleared.');
    } on AuthException catch (e) {
      debugPrint('Supabase Auth Error (SignOut): ${e.message}');
      throw Exception('Ошибка при выходе: ${_mapAuthExceptionToRussian(e.message)}');
    } catch (e) {
      debugPrint('General Error (SignOut): $e');
      throw Exception('Неизвестная ошибка при выходе. Попробуйте еще раз.');
    }
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
        // Если профиль не найден (например, при отложенном подтверждении email),
        // создаем его вручную, используя метаданные, сохраненные при регистрации.
        final metadataRole = user.userMetadata?['role'] as String?;
        final metadataName = user.userMetadata?['full_name'] as String?;

        if (metadataRole != null && metadataName != null) {
          await _client.from('profiles').insert({
            'id': user.id,
            'full_name': metadataName,
            'role': metadataRole,
            'email': user.email, // Добавляем email для надежности
            'created_at': DateTime.now().toIso8601String(),
          });
          return getProfile(); // Рекурсивный вызов после создания
        }
        return null; // Не удалось найти или восстановить
      }

      return ProfileModel.fromJson(data, user);
    } on PostgrestException catch (e) {
      throw Exception('Ошибка БД при загрузке профиля: ${e.message}');
    } catch (e) {
      throw Exception('Ошибка при загрузке профиля: $e');
    }
  }

  // ------------------------------------------------
  // ✅ ВСПОМОГАТЕЛЬНЫЕ
  // ------------------------------------------------

  /// Преобразует стандартные сообщения об ошибках Supabase в русский текст
  String _mapAuthExceptionToRussian(String message) {
    final lowerCaseMessage = message.toLowerCase();

    if (lowerCaseMessage.contains('invalid login credentials') || lowerCaseMessage.contains('invalid credentials')) {
      return 'Неверный адрес электронной почты или пароль.';
    }
    if (lowerCaseMessage.contains('user already exists')) {
      return 'Пользователь с таким адресом уже зарегистрирован.';
    }
    if (lowerCaseMessage.contains('email not confirmed')) {
      return 'Подтвердите свой адрес электронной почты для входа.';
    }
    if (lowerCaseMessage.contains('password should be at least 6 characters')) {
      return 'Пароль должен содержать не менее 6 символов.';
    }

    // Резервное сообщение с оригинальной ошибкой
    return 'Ошибка авторизации: $message';
  }
}