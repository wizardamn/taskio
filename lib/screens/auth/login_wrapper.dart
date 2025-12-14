import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

import '../home/project_list_screen.dart';
import 'login_screen.dart';

enum AuthStatus { loading, loggedIn, loggedOut, guest }

class LoginWrapper extends StatefulWidget {
  const LoginWrapper({super.key});

  @override
  State<LoginWrapper> createState() => _LoginWrapperState();
}

class _LoginWrapperState extends State<LoginWrapper> {
  late final StreamSubscription<AuthState> _authStateSubscription;
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.loading;

  @override
  void initState() {
    super.initState();

    final currentUser = Supabase.instance.client.auth.currentUser;
    final authProvider = context.read<AuthProvider>(); // Получаем провайдер

    // Проверяем, может быть, пользователь вошёл как гость
    if (authProvider.isGuest) {
      debugPrint("LoginWrapper: Статус провайдера - гость.");
      if (mounted) {
        setState(() => _status = AuthStatus.guest);
      }
    } else if (currentUser == null) {
      debugPrint("LoginWrapper: Сессия не найдена (signed out).");
      if (mounted) {
        setState(() => _status = AuthStatus.loggedOut);
      }
    } else {
      debugPrint("LoginWrapper: Сессия найдена. Загрузка профиля...");
      // Остаемся в 'loading', пока не загрузим профиль или не узнаем, что сессии нет.
    }

    _setupAuthListener();
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
        final authProvider = context.read<AuthProvider>();
        final projectProvider = context.read<ProjectProvider>();

        // Если статус в провайдере - гость, игнорируем любые изменения сессии.
        if (authProvider.isGuest) {
          debugPrint("LoginWrapper: Провайдер в статусе гость, игнорируем сессию.");
          return;
        }

        if (session != null) {
          // Сессия есть (вход или перезапуск приложения с сохранённой сессией)
          debugPrint("LoginWrapper: Сессия найдена. Загрузка профиля...");
          try {
            final profile = await _authService.getProfile();

            if (profile != null && mounted) {
              debugPrint("LoginWrapper: Профиль ${profile.fullName} загружен.");
              await projectProvider.setUser(profile.id, profile.fullName);
              if (mounted) {
                setState(() => _status = AuthStatus.loggedIn);
              }
            } else {
              debugPrint("LoginWrapper: Ошибка: Профиль не найден для ${session.user.id}");
              // Если профиль не найден, но сессия есть, это ошибка данных, НЕ выход.
              // Вместо _handleSignOut, можно показать сообщение пользователю или попытаться восстановить.
              // Для простоты, пока оставим как есть, но не вызываем signOut.
              if (mounted) {
                // Например, можно установить статус loggedOut и сообщить пользователю.
                // Или вызвать authProvider.signOut() для очистки сломанной сессии.
                // Но НЕ _handleSignOut, так как это не выход пользователя.
                // authProvider.signOut(); // <-- Это может быть вариантом, если сессия сломана.
              }
            }
          } catch (e) {
            debugPrint("LoginWrapper: Ошибка загрузки профиля: $e");
            // Ошибка загрузки профиля не означает, что пользователь вышел.
            // Не вызываем _handleSignOut. Это не сессия, это ошибка данных.
          }
        } else {
          // Сессии нет (пользователь действительно вышел)
          debugPrint("LoginWrapper: Сессия не найдена (signed out).");
          if (mounted) _handleSignOut(projectProvider, authProvider);
        }
      },
      onError: (error, stackTrace) {
        debugPrint("LoginWrapper: Ошибка в потоке аутентификации: $error\n$stackTrace");
        final authProvider = context.read<AuthProvider>();
        final projectProvider = context.read<ProjectProvider>();
        // Ошибка потока - это критическая ситуация. Лучше сбросить состояние.
        if (mounted) _handleSignOut(projectProvider, authProvider);
      },
    );
  }

  /// Обработчик выхода из системы (реальный выход или ошибка сессии)
  void _handleSignOut(ProjectProvider projectProvider, AuthProvider authProvider) {
    projectProvider.clear(keepProjects: false);
    authProvider.clear(); // Сбрасывает isGuest и другие поля

    if (mounted && _status != AuthStatus.loggedOut) {
      setState(() => _status = AuthStatus.loggedOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    switch (_status) {
      case AuthStatus.loading:
        currentScreen = const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Загрузка статуса пользователя...'),
              ],
            ),
          ),
        );
        break;
      case AuthStatus.loggedIn:
        currentScreen = const ProjectListScreen();
        break;
      case AuthStatus.loggedOut:
        currentScreen = const LoginScreen();
        break;
      case AuthStatus.guest:
        currentScreen = const ProjectListScreen();
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: SizedBox(key: UniqueKey(), child: currentScreen),
    );
  }
}