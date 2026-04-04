import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Providers
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';

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
    await dotenv.load(fileName: ".env");

    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();

    /// SUPABASE
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        'SUPABASE_URL or SUPABASE_ANON_KEY missing in .env',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    /// NOTIFICATIONS
    await NotificationService().init();

    AppLogger.info('Initialization completed successfully.');

  } catch (e, s) {
    AppLogger.error('App initialization failed', e, s);
  }

  runApp(
    EasyLocalization(
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
        ],
        child: const TaskioApp(),
      ),
    ),
  );
}

class TaskioApp extends StatelessWidget {
  const TaskioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Taskio',
      debugShowCheckedModeBanner: false,

      /// 🔥 Snackbar
      scaffoldMessengerKey: SnackbarManager.messengerKey,

      /// 🔥 Themes
      theme: themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      themeMode: themeProv.currentTheme,

      /// 🔥 Localization
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      /// 🔥 Global overlay
      builder: (context, child) {
        return LoadingOverlay(
          child: child ?? const SizedBox(),
        );
      },

      home: const LoginWrapper(),
    );
  }
}