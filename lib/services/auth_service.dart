import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../utils/app_logger.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

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
          tag: 'AuthService',
        );

        return event.session?.user;
      },
    );
  }

  // =========================================================
  // VALIDATION
  // =========================================================

  static final RegExp _usernameRegex = RegExp(
    r'^[a-zA-Z0-9_]{3,20}$',
  );

  void _validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw const AuthException(
        'validation.empty_email',
      );
    }
  }

  void _validateAuthInputs({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw const AuthException(
        'errors.empty_credentials',
      );
    }
  }

  void _validateUsername(String username) {
    final cleanUsername = _normalizeUsername(username);

    if (cleanUsername.isEmpty) {
      throw const AuthException(
        'validation.empty_field',
      );
    }

    if (cleanUsername.length < 3) {
      throw const AuthException(
        'validation.short_username',
      );
    }

    if (!_usernameRegex.hasMatch(cleanUsername)) {
      throw const AuthException(
        'validation.invalid_username',
      );
    }
  }

  String _generateUsername(String email) {
    final cleanEmail = email.trim().toLowerCase();

    final base = cleanEmail.contains('@')
        ? cleanEmail.split('@').first
        : cleanEmail;

    final normalizedBase = base
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '')
        .trim();

    final safeBase = normalizedBase.isEmpty ? 'user' : normalizedBase;

    final timestamp = DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(8);

    return '${safeBase}_$timestamp';
  }

  String _normalizeUsername(String? value) {
    final username = value?.trim().toLowerCase() ?? '';

    if (username.startsWith('@')) {
      return username.substring(1);
    }

    return username;
  }

  String _normalizeRole(String? value) {
    return UserRoleExtension.fromString(value).value;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  Future<void> _ensureUsernameAvailable(
      String username, {
        String? exceptUserId,
      }) async {
    final cleanUsername = _normalizeUsername(username);

    final data = await _client
        .from('profiles')
        .select('id')
        .eq('username', cleanUsername)
        .maybeSingle();

    if (data == null) {
      return;
    }

    final existingUserId = data['id']?.toString();

    if (exceptUserId != null && existingUserId == exceptUserId) {
      return;
    }

    throw const AuthException(
      'validation.username_taken',
    );
  }

  // =========================================================
  // REGISTRATION
  // =========================================================

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String role,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanUsername = _normalizeUsername(username);
      final cleanRole = _normalizeRole(role);

      if (cleanEmail.isEmpty ||
          password.trim().isEmpty ||
          cleanUsername.isEmpty ||
          cleanRole.isEmpty) {
        throw const AuthException(
          'validation.empty_field',
        );
      }

      _validateUsername(cleanUsername);

      await _ensureUsernameAvailable(cleanUsername);

      final response = await _client.auth
          .signUp(
        email: cleanEmail,
        password: password,
        data: {
          'username': cleanUsername,
          'full_name': cleanUsername,
          'role': cleanRole,
          'email': cleanEmail,
        },
        emailRedirectTo: _emailRedirectTo,
      )
          .timeout(
        const Duration(seconds: 20),
      );

      final user = response.user;

      if (user == null) {
        throw const AuthException(
          'errors.auth_failed',
        );
      }

      await _createProfile(
        user,
        fallbackEmail: cleanEmail,
        fallbackUsername: cleanUsername,
        fallbackRole: cleanRole,
      );

      AppLogger.info(
        'User registered: ${user.id}',
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'SignUp failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
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

      final cleanEmail = email.trim().toLowerCase();

      final response = await _client.auth
          .signInWithPassword(
        email: cleanEmail,
        password: password,
      )
          .timeout(
        const Duration(seconds: 20),
      );

      if (response.user == null || response.session == null) {
        throw const AuthException(
          'errors.auth_failed',
        );
      }

      await _ensureProfileExists(response.user!);

      AppLogger.info(
        'User signed in: ${response.user!.id}',
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'SignIn failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
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
    UserRole? role,
    String? language,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'errors.not_authenticated',
      );
    }

    final cleanUsername = _normalizeUsername(username);

    if (cleanUsername.isEmpty) {
      throw const AuthException(
        'validation.empty_field',
      );
    }

    _validateUsername(cleanUsername);

    await _ensureUsernameAvailable(
      cleanUsername,
      exceptUserId: user.id,
    );

    final cleanFirstName = firstName?.trim() ?? '';
    final cleanLastName = lastName?.trim() ?? '';
    final cleanBio = bio?.trim();
    final cleanAvatarUrl = avatarUrl?.trim();
    final cleanLanguage = language?.trim();

    final cleanName = fullName.trim().isEmpty
        ? cleanUsername
        : fullName.trim();

    final roleValue = role?.value;

    try {
      final updateData = <String, dynamic>{
        'full_name': cleanName,
        'first_name': cleanFirstName.isEmpty ? null : cleanFirstName,
        'last_name': cleanLastName.isEmpty ? null : cleanLastName,
        'username': cleanUsername,
        'bio': cleanBio == null || cleanBio.isEmpty ? null : cleanBio,
        'avatar_url': cleanAvatarUrl == null || cleanAvatarUrl.isEmpty
            ? null
            : cleanAvatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (roleValue != null && roleValue.isNotEmpty) {
        updateData['role'] = roleValue;
      }

      if (cleanLanguage != null && cleanLanguage.isNotEmpty) {
        updateData['language'] = cleanLanguage;
      }

      await _client
          .from('profiles')
          .update(updateData)
          .eq('id', user.id);

      final metadata = <String, dynamic>{
        'full_name': cleanName,
        'first_name': cleanFirstName,
        'last_name': cleanLastName,
        'username': cleanUsername,
        'avatar_url': cleanAvatarUrl,
      };

      if (roleValue != null && roleValue.isNotEmpty) {
        metadata['role'] = roleValue;
      }

      await _client.auth.updateUser(
        UserAttributes(
          data: metadata,
        ),
      );

      AppLogger.info(
        'Profile updated',
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'updateProfile failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
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
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    final cleanLanguage = language.trim();

    if (cleanLanguage.isEmpty) {
      return;
    }

    try {
      await _client
          .from('profiles')
          .update({
        'language': cleanLanguage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', user.id);

      AppLogger.info(
        'Language updated: $cleanLanguage',
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'updateUserLanguage failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
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
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'SignOut failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
      );

      rethrow;
    }
  }

  // =========================================================
  // PROFILE
  // =========================================================

  Future<ProfileModel?> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final data = await _client
          .from('profiles')
          .select(
        '''
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
            ''',
      )
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        await _createProfile(user);

        final newData = await _client
            .from('profiles')
            .select(
          '''
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
              ''',
        )
            .eq('id', user.id)
            .single();

        return ProfileModel.fromJson(
          Map<String, dynamic>.from(newData),
          user: user,
        );
      }

      return ProfileModel.fromJson(
        Map<String, dynamic>.from(data),
        user: user,
      );
    } catch (e, st) {
      AppLogger.error(
        'getProfile failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
      );

      rethrow;
    }
  }

  Future<void> _ensureProfileExists(User user) async {
    final data = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (data != null) {
      return;
    }

    await _createProfile(user);
  }

  // =========================================================
  // CREATE PROFILE
  // =========================================================

  Future<void> _createProfile(
      User user, {
        String? fallbackEmail,
        String? fallbackUsername,
        String? fallbackRole,
      }) async {
    try {
      final metadata = user.userMetadata ?? {};

      final email = _firstNonEmpty([
        user.email,
        fallbackEmail,
        metadata['email'],
      ]);

      final emailName = email.contains('@')
          ? email.split('@').first
          : 'user';

      final username = _normalizeUsername(
        _firstNonEmpty([
          fallbackUsername,
          metadata['username'],
          emailName,
          _generateUsername(email.isEmpty ? 'user' : email),
        ]),
      );

      final fullName = _firstNonEmpty([
        metadata['full_name'],
        username,
        emailName,
        'User',
      ]);

      final firstName = _firstNonEmpty([
        metadata['first_name'],
      ]);

      final lastName = _firstNonEmpty([
        metadata['last_name'],
      ]);

      final role = _normalizeRole(
        _firstNonEmpty([
          fallbackRole,
          metadata['role'],
          'student',
        ]),
      );

      final avatarUrl = _firstNonEmpty([
        metadata['avatar_url'],
      ]);

      final language = _firstNonEmpty([
        metadata['language'],
        'ru',
      ]);

      final now = DateTime.now().toUtc().toIso8601String();

      await _client.from('profiles').upsert(
        {
          'id': user.id,
          'username': username,
          'first_name': firstName.isEmpty ? null : firstName,
          'last_name': lastName.isEmpty ? null : lastName,
          'avatar_url': avatarUrl.isEmpty ? null : avatarUrl,
          'full_name': fullName,
          'bio': null,
          'role': role,
          'language': language,
          'created_at': now,
          'updated_at': now,
        },
        onConflict: 'id',
      );

      AppLogger.info(
        'Profile created',
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'createProfile failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
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

      final cleanEmail = email.trim().toLowerCase();

      await _client.auth
          .resetPasswordForEmail(
        cleanEmail,
        redirectTo: _emailRedirectTo,
      )
          .timeout(
        const Duration(seconds: 20),
      );

      AppLogger.info(
        'Password reset email sent',
        tag: 'AuthService',
      );
    } catch (e, st) {
      AppLogger.error(
        'resetPassword failed',
        error: e,
        stackTrace: st,
        tag: 'AuthService',
      );

      rethrow;
    }
  }
}