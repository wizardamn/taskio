import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/profile/profile_screen.dart'; // Оставлено, если функционал профиля будет нужен позже

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({super.key});

  // --- Вспомогательный метод для стилизованных иконок ---
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
  }) {
    // Используем InkWell для красивого эффекта нажатия (Ripple effect)
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    // Используем listen: false, так как prov нужен только для вызова методов
    final prov = Provider.of<ProjectProvider>(context, listen: false);
    // Используем context.watch для обновления UI при смене темы
    final themeProv = context.watch<ThemeProvider>();
    final isGuest = user == null;

    // --- Лаконичный заголовок (без фото профиля) ---
    final simpleHeader = DrawerHeader(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            // Название вашего приложения (можно заменить)
            tr('app_name'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('main_menu_subtitle'), // Подзаголовок (например, "Система управления")
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 1. Лаконичный заголовок
          simpleHeader,

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // --- ОСНОВНЫЕ ПУНКТЫ ---
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.assignment,
                    title: tr('my_projects'),
                    onTap: () => Navigator.pop(context),
                  ),

                  // Переключение темы (Как обычный пункт)
                  _buildDrawerItem(
                    context: context,
                    icon: themeProv.isDarkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                    title: themeProv.isDarkMode ? tr('light_theme') : tr('dark_theme'),
                    onTap: () => themeProv.toggleTheme(),
                    // Добавляем индикатор текущей темы
                    trailing: Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                      // Отображаем, только если тема соответствует выбранной
                      // Здесь мы просто отображаем, чтобы показать, что это интерактивный элемент
                    ),
                  ),

                  // Выбор языка
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.language,
                    title: tr('choose_language'),
                    onTap: () => _showLanguageDialog(context),
                  ),

                  const Divider(height: 16, indent: 16, endIndent: 16),

                  // --- ПУНКТЫ ДЛЯ АВТОРИЗОВАННОГО ПОЛЬЗОВАТЕЛЯ ---
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
                      );
                    },
                    child: isGuest
                        ? const SizedBox.shrink(key: ValueKey('guest'))
                        : Column(
                      key: const ValueKey('user'),
                      children: [
                        // Обновление проектов
                        _buildDrawerItem(
                            context: context,
                            icon: Icons.refresh,
                            title: tr('refresh_projects'),
                            onTap: () async {
                              // Сначала вызываем загрузку
                              await prov.fetchProjects();
                              // Если это сработало, закрываем
                              if (context.mounted) Navigator.pop(context);
                            }
                        ),

                        // Кнопка профиля (перенесена в основные пункты, но только для авторизованных)
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.person_outline,
                          title: tr('profile'),
                          onTap: () => _navigateToProfile(context),
                        ),

                        // Кнопка отчетов
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.picture_as_pdf,
                          title: tr('generate_report'),
                          color: Colors.red.shade600,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('report_functionality_not_impl'))),
                            );
                            Navigator.pop(context);
                          },
                        ),

                        const Divider(height: 16, indent: 16, endIndent: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- ВЫХОД / ВХОД (Фиксированный внизу) ---
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0, left: 8.0, right: 8.0),
            child: _buildDrawerItem(
              context: context,
              icon: isGuest ? Icons.login : Icons.logout,
              title: isGuest ? tr('login') : tr('logout'),
              color: isGuest ? Colors.green.shade600 : Colors.red.shade600,
              onTap: () async {
                if (isGuest) {
                  // Навигация на логин
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                } else {
                  // Выход
                  await Supabase.instance.client.auth.signOut();
                  // Очистка данных провайдера
                  prov.clear(keepProjects: false);

                  if (context.mounted) {
                    // Переход на логин после выхода
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Функция для навигации на экран профиля
  void _navigateToProfile(BuildContext context) {
    Navigator.pop(context); // Закрываем Drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  // Диалог выбора языка
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