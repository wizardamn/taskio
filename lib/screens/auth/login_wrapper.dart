import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

import '../home/project_list_screen.dart';
import 'login_screen.dart';

enum AuthStatus { loading, loggedIn, loggedOut }

class LoginWrapper extends StatefulWidget {
  const LoginWrapper({super.key});

  @override
  State<LoginWrapper> createState() => _LoginWrapperState();
}

class _LoginWrapperState extends State<LoginWrapper> {
  late final StreamSubscription<AuthState> _authStateSubscription;
  final AuthService _authService = AuthService();

  // Состояние аутентификации для реального пользователя
  AuthStatus _status = AuthStatus.loading;

  @override
  void initState() {
    super.initState();
    // Начальная проверка сессии Supabase
    _checkInitialSession();
    _setupAuthListener();
  }

  void _checkInitialSession() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _status = AuthStatus.loggedOut);
    }
    // Если сессия есть, слушатель потока обработает её
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
          (data) async {
        final session = data.session;
        final projectProvider = context.read<ProjectProvider>();
        final authProvider = context.read<AuthProvider>();

        // Если мы в режиме гостя, Supabase сессия может отсутствовать или быть неактуальной,
        // но мы даем приоритет флагу isGuest в методе build.
        if (authProvider.isGuest) return;

        if (session != null) {
          debugPrint("LoginWrapper: Сессия найдена. Загрузка профиля...");
          try {
            final profile = await _authService.getProfile();

            if (profile != null && mounted) {
              // Инициализируем ProjectProvider реальным пользователем
              await projectProvider.setUser(profile.id, profile.fullName);

              if (mounted) {
                setState(() => _status = AuthStatus.loggedIn);
              }
            } else {
              debugPrint("LoginWrapper: Профиль не найден. Выход.");
              _handleSignOut(projectProvider, authProvider);
            }
          } catch (e) {
            debugPrint("LoginWrapper: Ошибка загрузки профиля: $e");
            if (mounted) _handleSignOut(projectProvider, authProvider);
          }
        } else {
          debugPrint("LoginWrapper: Сессия не найдена.");
          if (mounted) _handleSignOut(projectProvider, authProvider);
        }
      },
      onError: (error) {
        debugPrint("LoginWrapper Error: $error");
        // Safe fail
        if (mounted) {
          setState(() => _status = AuthStatus.loggedOut);
        }
      },
    );
  }

  void _handleSignOut(ProjectProvider projectProvider, AuthProvider authProvider) {
    projectProvider.clear(keepProjects: false);
    authProvider.clear();
    if (mounted && _status != AuthStatus.loggedOut) {
      setState(() => _status = AuthStatus.loggedOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем AuthProvider, чтобы мгновенно реагировать на вход гостя
    final authProvider = context.watch<AuthProvider>();

    // 1. Приоритет: Гостевой режим
    if (authProvider.isGuest) {
      return const ProjectListScreen();
    }

    // 2. Реальная авторизация
    switch (_status) {
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Загрузка...'),
              ],
            ),
          ),
        );
      case AuthStatus.loggedIn:
        return const ProjectListScreen();
      case AuthStatus.loggedOut:
        return const LoginScreen();
    }
  }
}