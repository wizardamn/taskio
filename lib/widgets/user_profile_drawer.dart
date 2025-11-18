import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/profile/profile_screen.dart'; // 💡 Для перехода к редактированию профиля

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({super.key});

  // 💡 Функция для получения отображаемого имени
  String _getDisplayName(User? user) {
    // Проверяем метаданные сначала, затем fallback на 'Гость'
    return user?.userMetadata?['full_name'] ?? tr('guest');
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    // 💡 Используем watch для themeProv, чтобы UI обновлялся при смене темы
    final prov = Provider.of<ProjectProvider>(context, listen: false);
    final themeProv = context.watch<ThemeProvider>();

    final isGuest = user == null;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            // ✅ Используем вспомогательную функцию
            accountName: Text(_getDisplayName(user)),
            accountEmail: Text(user?.email ?? tr('guest_email')), // 💡 Предполагаем, что есть перевод для email гостя
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person, size: 36)),
            // 💡 onDetailsPressed ведет на экран профиля (если не гость)
            onDetailsPressed: isGuest ? null : () => _navigateToProfile(context),
          ),

          // Основные пункты
          ListTile(leading: const Icon(Icons.assignment), title: Text(tr('my_projects')), onTap: () => Navigator.pop(context)),

          // Выбор языка
          ListTile(leading: const Icon(Icons.language), title: Text(tr('choose_language')), onTap: () => _showLanguageDialog(context)),

          // Переключение темы
          ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(themeProv.isDarkMode ? 'Темная тема' : 'Светлая тема'),
              onTap: () => themeProv.toggleTheme()
          ),

          // Обновление проектов (доступно только для авторизованных)
          if (!isGuest)
            ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(tr('refresh_projects')),
                onTap: () async {
                  await prov.fetchProjects();
                  if (context.mounted) Navigator.pop(context);
                }
            ),

          // Кнопка отчетов (для примера, доступна только для авторизованных)
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Сформировать отчет'),
              onTap: () {
                // 💡 Здесь будет вызов ReportService.generateAndPrint(prov.view);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Функция отчетов будет реализована')),
                );
                Navigator.pop(context);
              },
            ),

          const Divider(),

          // Выход / Вход
          ListTile(
            leading: Icon(isGuest ? Icons.login : Icons.logout),
            title: Text(isGuest ? 'Войти' : tr('logout')),
            onTap: () async {
              if (isGuest) {
                // Если гость, просто переходим на логин
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              } else {
                // ✅ ИСПРАВЛЕНО: используем prov.clear(keepProjects: false)
                // Очищаем состояние в провайдере и выходим из Supabase
                await Supabase.instance.client.auth.signOut();
                prov.clear(keepProjects: false);

                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // 💡 Функция для навигации на экран профиля
  void _navigateToProfile(BuildContext context) {
    Navigator.pop(context); // Закрываем Drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('choose_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Русский'), onTap: () { context.setLocale(const Locale('ru')); Navigator.pop(context); }),
            ListTile(title: const Text('English'), onTap: () { context.setLocale(const Locale('en')); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }
}