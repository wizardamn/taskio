import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

// ✅ Провайдеры
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';

// ✅ Сервисы
import 'services/project_service.dart';
import 'services/notification_service.dart'; // <-- ДОБАВЛЕН ИМПОРТ

// ✅ Экраны
import 'screens/auth/login_wrapper.dart';
// import 'screens/auth/login_screen.dart'; // Убран, так как не используется напрямую в routes
// import 'screens/home/project_list_screen.dart'; // Убран, так как не используется напрямую в routes

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // ИНИЦИАЛИЗАЦИЯ EasyLocalization
  await EasyLocalization.ensureInitialized();

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('SUPABASE_URL или SUPABASE_ANON_KEY отсутствуют в .env!');
  }

  // ИНИЦИАЛИЗАЦИЯ Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // ИНИЦИАЛИЗАЦИЯ NotificationService
  await NotificationService().init(); // <-- ДОБАВЛЕНО

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('en')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ru'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          // Инициализируем ProjectProvider с новым сервисом
          ChangeNotifierProvider(
            create: (_) => ProjectProvider(
              ProjectService(),
            ),
          ),
        ],
        child: const TaskioApp(), // <-- ИСПРАВЛЕНО: Имя класса
      ),
    ),
  );
}

class TaskioApp extends StatelessWidget { // <-- ИСПРАВЛЕНО: Имя класса
  const TaskioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Taskio', // Обновили название
      debugShowCheckedModeBanner: false,
      themeMode: themeProv.currentTheme,
      theme: themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // Убраны routes, так как навигация через ProjectListScreen и LoginWrapper
      home: const LoginWrapper(),
    );
  }
}