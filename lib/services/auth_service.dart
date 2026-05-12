import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../utils/app_logger.dart';

class AuthService {
  final SupabaseClient _client =
      Supabase.instance.client;

  // =========================================================
  // REDIRECT URL
  // =========================================================

  String get _emailRedirectTo {
    if (kIsWeb) {
      return Uri.base.origin;
    }

    return 'taskio://login-callback';
  }

  // =========================================================
  // AUTH STREAM
  // =========================================================

  Stream<User?> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
          (event) {
        AppLogger.info(
          'Auth state changed: ${event.event.name}',
        );

        return event.session?.user;
      },
    );
  }

  // =========================================================
  // VALIDATION
  // =========================================================

  void _validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw const AuthException(
        'errors.empty_email',
      );
    }
  }

  void _validateAuthInputs({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty ||
        password.trim().isEmpty) {
      throw const AuthException(
        'errors.empty_credentials',
      );
    }
  }

  String _generateUsername(String email) {
    final base =
    email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    final timestamp =
    DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(8);

    return '${base}_$timestamp';
  }

  // =========================================================
  // REGISTRATION
  // =========================================================

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      final cleanEmail =
      email.trim().toLowerCase();

      final cleanName =
      fullName.trim();

      if (cleanEmail.isEmpty ||
          password.isEmpty ||
          cleanName.isEmpty ||
          role.isEmpty) {
        throw const AuthException(
          'errors.empty_fields',
        );
      }

      final username =
      _generateUsername(cleanEmail);

      final response =
      await _client.auth
          .signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': cleanName,
          'role': role,
          'username': username,
        },
        emailRedirectTo:
        _emailRedirectTo,
      )
          .timeout(
        const Duration(
          seconds: 20,
        ),
      );

      if (response.user == null) {
        throw const AuthException(
          'errors.registration_failed',
        );
      }

      AppLogger.info(
        'User registered: ${response.user!.id}',
      );
    } catch (e, st) {
      AppLogger.error(
        'SignUp failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _validateAuthInputs(
        email: email,
        password: password,
      );

      final cleanEmail =
      email.trim().toLowerCase();

      final response =
      await _client.auth
          .signInWithPassword(
        email: cleanEmail,
        password: password,
      )
          .timeout(
        const Duration(
          seconds: 20,
        ),
      );

      if (response.user == null ||
          response.session == null) {
        throw const AuthException(
          'errors.login_failed',
        );
      }

      AppLogger.info(
        'User signed in: ${response.user!.id}',
      );
    } catch (e, st) {
      AppLogger.error(
        'SignIn failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<void> updateProfile({
    required String fullName,
    String? firstName,
    String? lastName,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final user =
        _client.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'errors.not_authenticated',
      );
    }

    final cleanName =
    fullName.trim();

    if (cleanName.isEmpty) {
      throw const AuthException(
        'errors.invalid_name',
      );
    }

    try {
      await _client
          .from('profiles')
          .update({
        'full_name': cleanName,
        'first_name':
        firstName?.trim(),
        'last_name':
        lastName?.trim(),
        'username':
        username?.trim(),
        'bio': bio?.trim(),
        'avatar_url': avatarUrl,
        'updated_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      })
          .eq('id', user.id);

      await _client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': cleanName,
          },
        ),
      );

      AppLogger.info(
        'Profile updated',
      );
    } catch (e, st) {
      AppLogger.error(
        'updateProfile failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // LANGUAGE
  // =========================================================

  Future<void> updateUserLanguage(
      String language,
      ) async {
    final user =
        _client.auth.currentUser;

    if (user == null) return;

    if (language.trim().isEmpty) {
      return;
    }

    try {
      await _client
          .from('profiles')
          .update({
        'language': language,
        'updated_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      })
          .eq('id', user.id);

      AppLogger.info(
        'Language updated: $language',
      );
    } catch (e, st) {
      AppLogger.error(
        'updateUserLanguage failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> signOut() async {
    try {
      await _client.removeAllChannels();

      await _client.auth.signOut();

      AppLogger.info(
        'User signed out',
      );
    } catch (e, st) {
      AppLogger.error(
        'SignOut failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // PROFILE
  // =========================================================

  Future<ProfileModel?> getProfile() async {
    final user =
        _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final data =
      await _client
          .from('profiles')
          .select('''
                id,
                username,
                first_name,
                last_name,
                avatar_url,
                full_name,
                bio,
                role,
                created_at,
                updated_at,
                language
              ''')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        await _createProfile(user);

        final newData =
        await _client
            .from('profiles')
            .select('''
                  id,
                  username,
                  first_name,
                  last_name,
                  avatar_url,
                  full_name,
                  bio,
                  role,
                  created_at,
                  updated_at,
                  language
                ''')
            .eq('id', user.id)
            .single();

        return ProfileModel.fromJson(newData);
      }

      return ProfileModel.fromJson(data);
    } catch (e, st) {
      AppLogger.error(
        'getProfile failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // CREATE PROFILE
  // =========================================================

  Future<void> _createProfile(
      User user,
      ) async {
    try {
      final metadata =
          user.userMetadata ?? {};

      final fullName =
          metadata['full_name']
          as String? ??
              user.email
                  ?.split('@')
                  .first ??
              'User';

      final username =
          metadata['username']
          as String? ??
              _generateUsername(
                user.email ?? 'user',
              );

      final role =
          metadata['role']
          as String? ??
              'student';

      await _client
          .from('profiles')
          .upsert({
        'id': user.id,
        'username': username,
        'first_name': null,
        'last_name': null,
        'avatar_url': null,
        'full_name': fullName,
        'bio': null,
        'role': role,
        'language': 'ru',
        'created_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
        'updated_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      });

      AppLogger.info(
        'Profile created',
      );
    } catch (e, st) {
      AppLogger.error(
        'createProfile failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // RESET PASSWORD
  // =========================================================

  Future<void> resetPassword(
      String email,
      ) async {
    try {
      _validateEmail(email);

      final cleanEmail =
      email.trim().toLowerCase();

      await _client.auth
          .resetPasswordForEmail(
        cleanEmail,
        redirectTo:
        _emailRedirectTo,
      )
          .timeout(
        const Duration(
          seconds: 20,
        ),
      );

      AppLogger.info(
        'Password reset email sent',
      );
    } catch (e, st) {
      AppLogger.error(
        'resetPassword failed',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }
}