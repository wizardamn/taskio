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

  bool get isLoading =>
      _status == AuthStatus.loading;

  bool get isGuest =>
      _status == AuthStatus.guest;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated;

  User? get user => _user;

  ProfileModel? get profile => _profile;

  String? get userId =>
      isGuest ? 'guest' : _user?.id;

  String get userName {
    if (isGuest) {
      return 'profile.guest'.tr();
    }

    return _profile?.fullName ??
        _user?.email?.split('@').first ??
        'User';
  }

  String? get username =>
      _profile?.username;

  String? get avatarUrl =>
      _profile?.avatarUrl;

  String get userRole =>
      _profile?.role.name ?? 'student';

  String? get userLanguage =>
      _profile?.language;

  AuthProvider() {
    _initialize();
  }

  // =========================================================
  // INIT
  // =========================================================

  Future<void> _initialize() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final savedGuest =
          prefs.getBool('guest_mode') ?? false;

      final currentUser =
          _supabase.auth.currentUser;

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
        final profile =
        await _authService.getProfile();

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

      _authSubscription = _supabase
          .auth.onAuthStateChange
          .listen(_handleAuthChange);
    } catch (e, s) {
      debugPrint(
        'AuthProvider init error: $e\n$s',
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
      AuthState data) async {
    if (!_initialized || _disposed) {
      return;
    }

    final sessionUser =
        data.session?.user;

    if (sessionUser == null) {
      _setState(
        AuthStatus.unauthenticated,
        user: null,
        profile: null,
      );
    } else {
      final profile =
      await _authService.getProfile();

      _setState(
        AuthStatus.authenticated,
        user: sessionUser,
        profile: profile,
      );
    }
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

    final profile =
    await _authService.getProfile();

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
  }) async {
    await _authService.updateProfile(
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      username: username,
      bio: bio,
      avatarUrl: avatarUrl,
    );

    await refreshProfile();
  }

  Future<void> updateLanguage(
      String language) async {
    await _authService.updateUserLanguage(
      language,
    );

    await refreshProfile();
  }

  // =========================================================
  // GUEST MODE
  // =========================================================

  Future<void> signInAsGuest() async {
    final prefs =
    await SharedPreferences.getInstance();

    try {
      if (_supabase.auth.currentSession !=
          null) {
        await _authService.signOut();
      }

      _setState(
        AuthStatus.loading,
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
    final prefs =
    await SharedPreferences.getInstance();

    _setState(
      AuthStatus.loading,
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
    final prefs =
    await SharedPreferences.getInstance();

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
      String fullName,
      String role,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

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
        fullName: fullName,
        role: role,
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
    final prefs =
    await SharedPreferences.getInstance();

    final wasGuest = isGuest;

    try {
      _setState(
        AuthStatus.loading,
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