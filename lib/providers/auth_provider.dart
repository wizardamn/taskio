import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  authenticated,
  guest,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  SupabaseClient get _supabase => Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;

  AuthStatus _status = AuthStatus.loading;
  User? _user;
  ProfileModel? _profile;

  bool _initialized = false;
  bool _disposed = false;

  // =========================================================
  // GETTERS
  // =========================================================

  AuthStatus get status => _status;

  bool get isLoading {
    return _status == AuthStatus.loading;
  }

  bool get isGuest {
    return _status == AuthStatus.guest;
  }

  bool get isAuthenticated {
    return _status == AuthStatus.authenticated;
  }

  User? get user {
    return _user;
  }

  ProfileModel? get profile {
    return _profile;
  }

  String? get userId {
    if (isGuest) {
      return 'guest';
    }

    return _user?.id;
  }

  String get userName {
    if (isGuest) {
      return 'profile.guest'.tr();
    }

    final profile = _profile;

    if (profile != null) {
      return profile.displayName;
    }

    final email = _user?.email?.trim() ?? '';

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'common.user'.tr();
  }

  String? get username {
    return _profile?.username;
  }

  String? get avatarUrl {
    return _profile?.avatarUrl;
  }

  String get userRole {
    return _profile?.role.value ?? UserRole.student.value;
  }

  UserRole get userRoleEnum {
    return _profile?.role ?? UserRole.student;
  }

  String? get userLanguage {
    return _profile?.language;
  }

  String get email {
    return _profile?.email ?? _user?.email ?? '';
  }

  AuthProvider() {
    _initialize();
  }

  // =========================================================
  // INIT
  // =========================================================

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedGuest = prefs.getBool('guest_mode') ?? false;
      final currentUser = _supabase.auth.currentUser;

      if (savedGuest) {
        if (currentUser != null) {
          await _authService.signOut();
        }

        _setState(
          AuthStatus.guest,
          user: null,
          profile: null,
        );
      } else if (currentUser != null) {
        final profile = await _authService.getProfile();

        _setState(
          AuthStatus.authenticated,
          user: currentUser,
          profile: profile,
        );
      } else {
        _setState(
          AuthStatus.unauthenticated,
          user: null,
          profile: null,
        );
      }

      _initialized = true;

      _authSubscription = _supabase.auth.onAuthStateChange.listen(
        _handleAuthChange,
      );
    } catch (e, st) {
      debugPrint(
        'AuthProvider init error: $e\n$st',
      );

      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );
    }
  }

  // =========================================================
  // AUTH EVENTS
  // =========================================================

  Future<void> _handleAuthChange(
      AuthState data,
      ) async {
    if (!_initialized || _disposed) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedGuest = prefs.getBool('guest_mode') ?? false;

    if (savedGuest) {
      _setState(
        AuthStatus.guest,
        user: null,
        profile: null,
      );

      return;
    }

    final sessionUser = data.session?.user;

    if (sessionUser == null) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );

      return;
    }

    final profile = await _authService.getProfile();

    _setState(
      AuthStatus.authenticated,
      user: sessionUser,
      profile: profile,
    );
  }

  // =========================================================
  // STATE
  // =========================================================

  void _setState(
      AuthStatus status, {
        User? user,
        ProfileModel? profile,
      }) {
    if (_disposed) {
      return;
    }

    _status = status;
    _user = user;
    _profile = profile;

    notifyListeners();
  }

  // =========================================================
  // PROFILE
  // =========================================================

  Future<void> refreshProfile() async {
    if (!isAuthenticated || _user == null) {
      return;
    }

    final profile = await _authService.getProfile();

    _setState(
      AuthStatus.authenticated,
      user: _user,
      profile: profile,
    );
  }

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
    if (!isAuthenticated || _user == null) {
      return;
    }

    await _authService.updateProfile(
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      username: username,
      bio: bio,
      avatarUrl: avatarUrl,
      role: role,
      language: language,
    );

    await refreshProfile();
  }

  Future<void> updateLanguage(
      String language,
      ) async {
    if (!isAuthenticated || _user == null) {
      return;
    }

    await _authService.updateUserLanguage(
      language,
    );

    await refreshProfile();
  }

  // =========================================================
  // GUEST MODE
  // =========================================================

  Future<void> signInAsGuest() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      if (_supabase.auth.currentSession != null) {
        await _authService.signOut();
      }

      _setState(
        AuthStatus.loading,
        user: null,
        profile: null,
      );

      await prefs.setBool(
        'guest_mode',
        true,
      );

      await BadgeService.clear();

      _setState(
        AuthStatus.guest,
        user: null,
        profile: null,
      );
    } catch (_) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );

      rethrow;
    }
  }

  Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();

    _setState(
      AuthStatus.loading,
      user: null,
      profile: null,
    );

    try {
      await prefs.remove('guest_mode');

      await BadgeService.clear();

      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );
    } catch (_) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );

      rethrow;
    }
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> signIn(
      String email,
      String password,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.remove('guest_mode');

      _setState(
        AuthStatus.loading,
        user: null,
        profile: null,
      );

      await _authService.signIn(
        email: email.trim(),
        password: password,
      );

      final currentUser = _supabase.auth.currentUser;
      final profile = await _authService.getProfile();

      _setState(
        AuthStatus.authenticated,
        user: currentUser,
        profile: profile,
      );
    } catch (_) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );

      rethrow;
    }
  }

  // =========================================================
  // SIGN UP
  // =========================================================

  Future<void> signUp(
      String email,
      String password,
      String username,
      String role,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.remove('guest_mode');

      _setState(
        AuthStatus.loading,
        user: null,
        profile: null,
      );

      await _authService.signUp(
        email: email.trim(),
        password: password,
        username: username.trim(),
        role: role.trim(),
      );

      final currentUser = _supabase.auth.currentUser;

      if (currentUser == null) {
        _setState(
          AuthStatus.unauthenticated,
          user: null,
          profile: null,
        );

        return;
      }

      final profile = await _authService.getProfile();

      _setState(
        AuthStatus.authenticated,
        user: currentUser,
        profile: profile,
      );
    } catch (_) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );

      rethrow;
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();

    final wasGuest = isGuest;

    try {
      _setState(
        AuthStatus.loading,
        user: null,
        profile: null,
      );

      await prefs.remove('guest_mode');

      if (!wasGuest) {
        await _authService.signOut();
      }

      await BadgeService.clear();

      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );
    } catch (_) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );

      rethrow;
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _disposed = true;

    _authSubscription?.cancel();
    _authSubscription = null;

    super.dispose();
  }
}