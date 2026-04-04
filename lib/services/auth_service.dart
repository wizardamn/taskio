import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  final String _emailRedirectTo =
      'https://yqcywpkkdwkmqposwyoz.supabase.co/auth/v1/callback';

  /// Stream авторизации
  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) {
        AppLogger.info(
            'Auth state changed: ${event.event.name}');
        return event.session?.user;
      });

  /// ===========================
  /// REGISTRATION
  /// ===========================
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      if (email.isEmpty ||
          password.isEmpty ||
          fullName.isEmpty ||
          role.isEmpty) {
        throw Exception('errors.empty_fields');
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

      if (response.user == null) {
        throw Exception('errors.registration_failed');
      }

      AppLogger.info(
          'User registered successfully: ${response.user!.id}');
    } on AuthException catch (e) {
      AppLogger.error('SignUp AuthException', e);
      throw Exception(ErrorMapper.map(e.message));
    } catch (e) {
      AppLogger.error('SignUp failed', e);
      throw Exception(ErrorMapper.map(e));
    }
  }

  /// ===========================
  /// LOGIN
  /// ===========================
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('errors.empty_credentials');
      }

      final response =
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('errors.login_failed');
      }

      AppLogger.info(
          'User signed in: ${response.user?.id}');
    } on AuthException catch (e) {
      AppLogger.error('SignIn AuthException', e);
      throw Exception(ErrorMapper.map(e.message));
    } catch (e) {
      AppLogger.error('SignIn failed', e);
      throw Exception(ErrorMapper.map(e));
    }
  }

  Future<void> updateFullName(String newName) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Обновляем public.profiles
    await Supabase.instance.client
        .from('profiles')
        .update({
      'full_name': newName,
    })
        .eq('id', user.id);

    // Обновляем metadata в auth
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {'full_name': newName},
      ),
    );
  }

  /// ===========================
  /// LOGOUT
  /// ===========================
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();

      AppLogger.info('User signed out');
    } catch (e) {
      AppLogger.error('SignOut failed', e);
      throw Exception(ErrorMapper.map(e));
    }
  }

  /// ===========================
  /// PROFILE
  /// ===========================
  Future<ProfileModel?> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      AppLogger.warning('getProfile: user is null');
      return null;
    }

    try {
      final data = await _client
          .from('profiles')
          .select(
          'id, full_name, role, created_at, language')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        AppLogger.warning(
            'Profile not found. Creating new profile.');

        await _createProfile(user);
        return getProfile();
      }

      AppLogger.info(
          'Profile loaded: ${data['full_name']}');

      return ProfileModel.fromJson(data, user);
    } catch (e) {
      AppLogger.error('getProfile failed', e);
      throw Exception(ErrorMapper.map(e));
    }
  }

  /// ===========================
  /// CREATE PROFILE
  /// ===========================
  Future<void> _createProfile(User user) async {
    final metadataRole =
    user.userMetadata?['role'] as String?;
    final metadataName =
    user.userMetadata?['full_name'] as String?;

    final name =
        metadataName ?? user.email?.split('@').first ?? 'User';
    final role = metadataRole ?? 'student';

    await _client.from('profiles').insert({
      'id': user.id,
      'full_name': name,
      'role': role,
      'language': 'ru',
      'created_at': DateTime.now().toIso8601String(),
    });

    AppLogger.info('Profile created');
  }

  /// ===========================
  /// UPDATE LANGUAGE
  /// ===========================
  Future<void> updateUserLanguage(String language) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('profiles')
          .update({'language': language})
          .eq('id', user.id);

      AppLogger.info(
          'User language updated: $language');
    } catch (e) {
      AppLogger.error(
          'Failed to update language', e);
    }
  }
}