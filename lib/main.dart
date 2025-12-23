import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

// Провайдеры
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';

// Сервисы
import 'services/project_service.dart';
import 'services/notification_service.dart';

// Экраны
import 'screens/auth/login_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[App] Application starting...');

  // 1. Загружаем переменные окружения
  await dotenv.load(fileName: ".env");
  debugPrint('[App] Environment variables loaded.');

  // 2. Инициализация локализации
  await EasyLocalization.ensureInitialized();
  debugPrint('[App] Localization initialized.');

  // 3. Инициализация Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('SUPABASE_URL или SUPABASE_ANON_KEY отсутствуют в .env!');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  debugPrint('[App] Supabase initialized successfully.');

  // 4. Инициализация уведомлений
  await NotificationService().init();
  debugPrint('[App] NotificationService initialized.');

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('en')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ru'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      themeMode: themeProv.currentTheme,
      theme: themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const LoginWrapper(),
    );
  }
}