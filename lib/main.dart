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

  // 1. Загружаем переменные окружения
  await dotenv.load(fileName: ".env");

  // 2. Инициализация локализации
  await EasyLocalization.ensureInitialized();

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

  // 4. Инициализация уведомлений
  await NotificationService().init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('en')],
      path: 'assets/lang', // Убедитесь, что папка существует и добавлена в pubspec.yaml
      fallbackLocale: const Locale('ru'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          // Инициализируем ProjectProvider с ProjectService
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
      // Темы из ThemeProvider
      themeMode: themeProv.currentTheme,
      theme: themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      // Локализация
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // Начальный экран - Обертка авторизации
      home: const LoginWrapper(),
    );
  }
}