import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  authenticated,
  guest,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;

  AuthStatus _status = AuthStatus.loading;
  AuthStatus get status => _status;

  bool get isLoading => _status == AuthStatus.loading;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  User? _user;
  User? get user => _user;

  String? get userId => isGuest ? 'guest' : _user?.id;

  String get userName {
    if (isGuest) return 'profile.guest'.tr();

    return _user?.userMetadata?['full_name'] ??
        _user?.email?.split('@').first ??
        'User';
  }

  AuthProvider() {
    _initialize();
  }

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final savedGuest = prefs.getBool('guest_mode') ?? false;
    final currentUser = _supabase.auth.currentUser;

    if (savedGuest) {
      _status = AuthStatus.guest;
    } else if (currentUser != null) {
      _user = currentUser;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();

    _authSubscription =
        _supabase.auth.onAuthStateChange.listen(_handleAuthChange);
  }

  void _handleAuthChange(AuthState data) {
    if (isGuest) return;

    final sessionUser = data.session?.user;

    if (sessionUser == null) {
      _user = null;
      _status = AuthStatus.unauthenticated;
    } else {
      _user = sessionUser;
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  // ============================================
  // GUEST MODE
  // ============================================

  Future<void> signInAsGuest() async {
    final prefs = await SharedPreferences.getInstance();

    if (_supabase.auth.currentSession != null) {
      await _authService.signOut();
    }

    await prefs.setBool('guest_mode', true);

    _user = null;
    _status = AuthStatus.guest;

    notifyListeners();
  }

  Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('guest_mode');

    _status = AuthStatus.unauthenticated;

    notifyListeners();
  }

  // ============================================
  // LOGIN
  // ============================================

  Future<void> signIn(
      String email,
      String password,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await prefs.remove('guest_mode');

      await _authService.signIn(
        email: email,
        password: password,
      );

      _user = _supabase.auth.currentUser;
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  // ============================================
  // REGISTRATION
  // ============================================

  Future<void> signUp(
      String email,
      String password,
      String fullName,
      String role,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await prefs.remove('guest_mode');

      await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );

      _user = _supabase.auth.currentUser;
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  // ============================================
  // LOGOUT
  // ============================================

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();

    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await prefs.remove('guest_mode');

      if (!isGuest) {
        await _authService.signOut();
      }

      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  // ============================================
  // DISPOSE
  // ============================================

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}