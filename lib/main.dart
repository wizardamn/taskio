import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

/// ==========================================================
/// BACKGROUND FCM HANDLER
/// ==========================================================
///
/// Этот обработчик вызывается, когда Android-приложение находится
/// в фоне или закрыто, а Firebase Cloud Messaging получает push.
///
/// Важно:
/// - функция должна быть top-level;
/// - обязательно нужен @pragma('vm:entry-point');
/// - Firebase нужно инициализировать внутри background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    }

    AppLogger.info(
      'Background FCM message received: ${message.messageId}',
      tag: 'FCM',
    );
  } catch (e, st) {
    AppLogger.error(
      'Background FCM handler error',
      error: e,
      stackTrace: st,
      tag: 'FCM',
    );
  }
}

/// ==========================================================
/// MAIN
/// ==========================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.info(
    'Application starting...',
    tag: 'Main',
  );

  try {
    /// Localization
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();

    /// Supabase
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    /// Firebase
    await _initializeFirebase();

    AppLogger.info(
      'Core initialization completed',
      tag: 'Main',
    );

    runApp(
      const TaskioRoot(),
    );
  } catch (e, st) {
    AppLogger.error(
      'App initialization failed',
      error: e,
      stackTrace: st,
      tag: 'Main',
    );

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: SnackbarManager.messengerKey,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Ошибка запуска:\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ==========================================================
/// FIREBASE INIT
/// ==========================================================

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    AppLogger.info(
      'Firebase initialization skipped for Web',
      tag: 'Firebase',
    );

    return;
  }

  try {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    AppLogger.info(
      'Firebase initialized successfully',
      tag: 'Firebase',
    );
  } catch (e, st) {
    AppLogger.error(
      'Firebase initialization failed',
      error: e,
      stackTrace: st,
      tag: 'Firebase',
    );
  }
}

/// ==========================================================
/// ROOT
/// ==========================================================

class TaskioRoot extends StatelessWidget {
  const TaskioRoot({
    super.key,
  });

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
            create: (_) {
              return ThemeProvider();
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              return AuthProvider();
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              return ProjectProvider(
                ProjectService(),
              );
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              return ChatProvider();
            },
          ),
        ],
        child: const TaskioApp(),
      ),
    );
  }
}

/// ==========================================================
/// APP
/// ==========================================================

class TaskioApp extends StatefulWidget {
  const TaskioApp({
    super.key,
  });

  @override
  State<TaskioApp> createState() {
    return _TaskioAppState();
  }
}

class _TaskioAppState extends State<TaskioApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      try {
        await NotificationService().init();

        AppLogger.info(
          'NotificationService initialized',
          tag: 'NotificationService',
        );
      } catch (e, st) {
        AppLogger.error(
          'NotificationService error',
          error: e,
          stackTrace: st,
          tag: 'NotificationService',
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