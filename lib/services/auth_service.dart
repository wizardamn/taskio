import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  final String _emailRedirectTo = 'https://yqcywpkkdwkmqposwyoz.supabase.co/auth/v1/callback';

  Stream<User?> get authStateChanges => _client.auth.onAuthStateChange.map((event) {
    debugPrint('[AuthService] Auth State Changed: ${event.event}');
    return event.session?.user;
  });

  /// Регистрация
  Future<bool> signUp(String email, String password, String fullName, String role) async {
    debugPrint('[AuthService] Attempting SignUp for: $email, role: $role');
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
        throw Exception('Неизвестная ошибка регистрации.');
      }

      debugPrint('[AuthService] SignUp successful. User ID: ${response.user?.id}');
      return true;
    } on AuthException catch (e) {
      debugPrint('[AuthService] Supabase Auth Error (SignUp): ${e.message}');
      throw Exception(_mapAuthExceptionToRussian(e.message));
    } catch (e) {
      debugPrint('[AuthService] General Error (SignUp): $e');
      throw Exception('Непредвиденная ошибка регистрации.');
    }
  }

  /// Вход
  Future<bool> signIn(String email, String password) async {
    debugPrint('[AuthService] Attempting SignIn for: $email');
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email и пароль должны быть заполнены.');
      }

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw Exception('Вход не удался.');
      }

      debugPrint('[AuthService] SignIn successful. User ID: ${response.user?.id}');
      return true;
    } on AuthException catch (e) {
      debugPrint('[AuthService] Supabase Auth Error (SignIn): ${e.message}');
      throw Exception(_mapAuthExceptionToRussian(e.message));
    } catch (e) {
      debugPrint('[AuthService] General Error (SignIn): $e');
      throw Exception('Не удалось войти: $e');
    }
  }

  /// Выход
  Future<void> signOut() async {
    debugPrint('[AuthService] Signing out...');
    try {
      await _client.auth.signOut();
      debugPrint('[AuthService] SignOut successful.');
    } on AuthException catch (e) {
      debugPrint('[AuthService] Error (SignOut): ${e.message}');
      throw Exception('Ошибка при выходе.');
    }
  }

  /// Получение профиля
  Future<ProfileModel?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[AuthService] getProfile: User is null.');
      return null;
    }

    debugPrint('[AuthService] Fetching profile for: ${user.id}...');
    try {
      final data = await _client
          .from('profiles')
          .select('id, full_name, role, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        debugPrint('[AuthService] Profile not found in DB. Creating new profile...');

        final metadataRole = user.userMetadata?['role'] as String?;
        final metadataName = user.userMetadata?['full_name'] as String?;

        final name = metadataName ?? user.email?.split('@').first ?? 'Пользователь';
        final role = metadataRole ?? 'student';

        await _client.from('profiles').insert({
          'id': user.id,
          'full_name': name,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('[AuthService] New profile created. Retrying fetch...');
        return getProfile();
      }

      debugPrint('[AuthService] Profile loaded: ${data['full_name']} (${data['role']})');
      return ProfileModel.fromJson(data, user);
    } catch (e) {
      debugPrint('[AuthService] Error getting profile: $e');
      throw Exception('Ошибка при загрузке профиля: $e');
    }
  }

  String _mapAuthExceptionToRussian(String message) {
    // ... (код маппинга ошибок без изменений) ...
    return 'Ошибка авторизации: $message';
  }
}