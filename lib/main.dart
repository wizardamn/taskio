import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';

/// CONFIG
import 'config/env.dart';

/// Providers
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';

/// Services
import 'services/project_service.dart';
import 'services/notification_service.dart';

/// Core
import 'utils/snackbar_manager.dart';
import 'utils/app_logger.dart';
import 'utils/loading_overlay.dart';

/// Screens
import 'screens/auth/login_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Application starting...');

  try {
    /// 🔥 Localization
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();

    /// 🔥 SUPABASE (без dotenv)
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    AppLogger.info('Core initialization completed');

    runApp(const TaskioRoot());

  } catch (e, s) {
    AppLogger.error(
      'App initialization failed',
      error: e,
      stackTrace: s,
    );

    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Ошибка запуска:\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================
/// ROOT
/// =============================

class TaskioRoot extends StatelessWidget {
  const TaskioRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('ru'),
      saveLocale: true,
      useOnlyLangCode: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => ProjectProvider(
              ProjectService(),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => ChatProvider(),
          ),
        ],
        child: const TaskioApp(),
      ),
    );
  }
}

/// =============================
/// APP
/// =============================

class TaskioApp extends StatefulWidget {
  const TaskioApp({super.key});

  @override
  State<TaskioApp> createState() => _TaskioAppState();
}

class _TaskioAppState extends State<TaskioApp> {
  @override
  void initState() {
    super.initState();

    /// 🔥 безопасно (не ломает Web)
    Future.microtask(() async {
      try {
        await NotificationService().init();
        AppLogger.info('NotificationService initialized');
      } catch (e, s) {
        AppLogger.error(
          'NotificationService error',
          error: e,
          stackTrace: s,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Taskio',
      debugShowCheckedModeBanner: false,

      scaffoldMessengerKey: SnackbarManager.messengerKey,

      theme: themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      themeMode: themeProv.currentTheme,

      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      builder: (context, child) {
        return LoadingOverlay(
          child: child ?? const SizedBox(),
        );
      },

      home: const LoginWrapper(),
    );
  }
}