import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Убран лишний пробел в конце URL
  final String _emailRedirectTo = 'https://yqcywpkkdwkmqposwyoz.supabase.co/auth/v1/callback';

  /// Поток для отслеживания состояния авторизации пользователя.
  Stream<User?> get authStateChanges => _client.auth.onAuthStateChange.map((event) {
    return event.session?.user;
  });

  /// Регистрация нового пользователя.
  Future<bool> signUp(String email, String password, String fullName, String role) async {
    try {
      if (email.isEmpty || password.isEmpty || fullName.isEmpty || role.isEmpty) {
        throw Exception('Все поля должны быть заполнены.');
      }

      await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
        emailRedirectTo: _emailRedirectTo,
      );

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

      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

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
      // Проверяем, существует ли профиль в таблице profiles
      final data = await _client
          .from('profiles')
          .select('id, full_name, role, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        // Если профиль найден, преобразуем его в модель ProfileModel
        return ProfileModel.fromJson(data, user);
      }

      // Если профиль не найден, создаем его из метаданных пользователя или email
      debugPrint('[AuthService] Профиль для ${user.id} не найден в profiles. Создаю из userMetadata или email.');

      // 1. Извлекаем данные из userMetadata
      String? metadataName = user.userMetadata?['full_name'] as String?;
      String? metadataRole = user.userMetadata?['role'] as String?;

      // 2. Если metadataName или metadataRole отсутствуют, используем fallback
      final name = metadataName ?? user.email?.split('@').first ?? 'Пользователь';
      final role = metadataRole ?? 'user'; // Установите роль по умолчанию

      // 3. Вставляем новый профиль
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': name,
        'role': role,
        'email': user.email,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[AuthService] Профиль для ${user.id} создан автоматически.');

      // 4. Возвращаем новый профиль, не вызывая рекурсивно getProfile
      // Вместо этого, просто возвращаем созданный объект на основе вставленных данных
      // или делаем один повторный запрос, чтобы получить созданный объект целиком.
      // Повторный запрос надёжнее, так как вставляемые данные могут отличаться от возвращаемых (например, из-за триггеров в БД).
      final newData = await _client
          .from('profiles')
          .select('id, full_name, role, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (newData != null) {
        return ProfileModel.fromJson(newData, user);
      } else {
        // Это крайне маловероятно, но если сразу после вставки не нашли - ошибка
        debugPrint('[AuthService] ERROR: Не удалось загрузить только что созданный профиль для ${user.id}');
        return null;
      }

    } on PostgrestException catch (e) {
      debugPrint('Supabase DB Error (getProfile): ${e.message}');
      throw Exception('Ошибка БД при загрузке профиля: ${e.message}');
    } catch (e) {
      debugPrint('General Error (getProfile): $e');
      throw Exception('Ошибка при загрузке профиля: $e');
    }
  }

  /// Преобразует стандартные сообщения об ошибках Supabase в русский текст.
  String _mapAuthExceptionToRussian(String message) {
    final lowerCaseMessage = message.toLowerCase();

    if (lowerCaseMessage.contains('invalid login credentials') ||
        lowerCaseMessage.contains('invalid credentials') ||
        lowerCaseMessage.contains('user not found')) {
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
    if (lowerCaseMessage.contains('email rate limit exceeded')) {
      return 'Слишком много попыток. Попробуйте позже.';
    }

    return 'Ошибка авторизации: $message';
  }
}