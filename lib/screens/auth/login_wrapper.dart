import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/project_provider.dart';
import '../../services/auth_service.dart';

import '../home/project_list_screen.dart';
import 'login_screen.dart';

// Внутреннее состояние для LoginWrapper
enum AuthStatus { loading, loggedIn, loggedOut }

class LoginWrapper extends StatefulWidget {
  const LoginWrapper({super.key});

  @override
  State<LoginWrapper> createState() => _LoginWrapperState();
}

class _LoginWrapperState extends State<LoginWrapper> {
  late final StreamSubscription<AuthState> _authStateSubscription;
  final _authService = AuthService();

  // Храним текущее состояние аутентификации
  AuthStatus _status = AuthStatus.loading;

  @override
  void initState() {
    super.initState();

    // Проверяем синхронно при запуске
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      // Если пользователя точно нет, сразу ставим loggedOut, чтобы не показывать
      // стандартный спиннер, если нет сохраненной сессии.
      setState(() => _status = AuthStatus.loggedOut);
    }
    // Если пользователь ЕСТЬ, мы оставляем 'loading', пока не загрузим профиль.

    _setupAuthListener();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  /// Настраивает слушатель событий Supabase
  void _setupAuthListener() {
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final session = data.session;
          // Используем context.read(), так как мы ВНУТРИ initState/listener
          final prov = context.read<ProjectProvider>();

          if (session != null) {
            // СЕССИЯ ЕСТЬ (Пользователь вошел ИЛИ приложение запустилось с сохраненной сессией)
            debugPrint("LoginWrapper: Сессия найдена. Загрузка профиля...");
            try {
              final profile = await _authService.getProfile();

              if (profile != null && mounted) {
                debugPrint("LoginWrapper: Профиль ${profile.fullName} загружен.");
                await prov.setUser(profile.id, profile.fullName);

                // Меняем состояние на loggedIn
                setState(() => _status = AuthStatus.loggedIn);
              } else {
                throw Exception(
                    "Профиль не найден для пользователя ${session.user.id}");
              }
            } catch (e) {
              debugPrint("LoginWrapper: Ошибка загрузки профиля: $e");
              if (mounted) _handleSignOut(prov);
            }
          } else {
            // СЕССИИ НЕТ (Пользователь вышел)
            debugPrint("LoginWrapper: Сессия не найдена (signed out).");
            if (mounted) _handleSignOut(prov);
          }
        });
  }

  // Обработчик выхода
  void _handleSignOut(ProjectProvider prov) {
    prov.clear(keepProjects: false);

    // Меняем состояние на loggedOut
    if (_status != AuthStatus.loggedOut) {
      setState(() => _status = AuthStatus.loggedOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    // Определяем, какой экран нужно показать
    switch (_status) {
      case AuthStatus.loading:
      // Показываем загрузку с русским текстом
        currentScreen = const Scaffold( // Добавлена const, так как виджеты внутри константны
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                // ✅ ИСПРАВЛЕНО: Заменена ключ локализации на русскую строку
                Text('Загрузка статуса пользователя...'),
              ],
            ),
          ),
        );
        break;
      case AuthStatus.loggedIn:
      // Показываем главный экран
        currentScreen = const ProjectListScreen();
        break;
      case AuthStatus.loggedOut:
      // Показываем экран входа
        currentScreen = const LoginScreen();
        break;
    }

    // ✅ АНИМАЦИИ: Используем AnimatedSwitcher для плавного перехода между экранами
    return AnimatedSwitcher(
      // Длительность анимации
      duration: const Duration(milliseconds: 400),
      // Тип перехода: плавное исчезновение/появление
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Используем FadeTransition для более гладкого кроссфейда
        return FadeTransition(opacity: animation, child: child);
      },
      child: currentScreen,
    );
  }
}