import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? get user => supabase.auth.currentUser;
  bool get isAuthenticated => user != null;

  // --- Гостевой режим ---
  bool _isGuest = false;
  bool get isGuest => _isGuest;
  String _guestId = '';
  String _guestName = 'Гость';

  /// Вход как гость
  Future<void> signInAsGuest() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _setGuestUser(true);
    } catch (e) {
      debugPrint('AuthProvider Error (Guest Login): $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setGuestUser(bool isGuest) {
    _isGuest = isGuest;
    if (isGuest) {
      _guestId = 'guest_user_${DateTime.now().millisecondsSinceEpoch}';
      _guestName = 'Гость';
    } else {
      _guestId = '';
      _guestName = 'Гость';
    }
    notifyListeners();
  }

  String? get userId => isGuest ? _guestId : user?.id;

  String get userName {
    if (isGuest) return _guestName;
    return user?.userMetadata?['full_name'] ??
        user?.email?.split('@').first ??
        'Пользователь';
  }

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signIn(email, password);
      _setGuestUser(false);
    } catch (e) {
      debugPrint('AuthProvider Error (SignIn): $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Регистрация. Важно: role передается для создания записи в profiles
  Future<void> signUp(String email, String password, String fullName, String role) async {
    _setLoading(true);
    try {
      await _authService.signUp(email, password, fullName, role);
      _setGuestUser(false);
    } catch (e) {
      debugPrint('AuthProvider Error (SignUp): $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _setGuestUser(false);
    } finally {
      _setLoading(false);
    }
  }

  void clear() {
    _setGuestUser(false);
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
}