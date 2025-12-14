import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart'; // <-- КЛЮЧЕВОЙ ИМПОРТ
import '../screens/profile/profile_screen.dart'; // <-- Проверьте путь к ProfileScreen

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({super.key});

  // --- Вспомогательный метод для стилизованных иконок с анимацией ---
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
    required int index, // Для задержки анимации
  }) {
    final theme = Theme.of(context);
    final isDestructive = color == theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      // Оборачиваем в ClipRRect для соблюдения закругленных углов InkWell
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: isDestructive ? color!.withAlpha(20) : Colors.transparent, // Фон для деструктивных действий (0.08 * 255 ≈ 20)
          child: InkWell(
            onTap: onTap,
            // Красивый эффект нажатия
            splashColor: isDestructive ? color!.withAlpha(51) : theme.colorScheme.primary.withAlpha(26),
            highlightColor: isDestructive ? color!.withAlpha(26) : theme.colorScheme.primary.withAlpha(13),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: color ?? theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontSize: 15,
                        color: color ?? theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: (100 * index).ms, duration: 300.ms) // Плавное появление
        .slideX(begin: 0.1, end: 0, delay: (100 * index).ms, duration: 300.ms); // Плавный сдвиг
  }

  // Функция для навигации на экран профиля
  void _navigateToProfile(BuildContext context) {
    Navigator.pop(context); // Закрываем Drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  // --- Персонализированный Header (Сплошной, кликабельный) ---
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ProjectProvider>(
      builder: (context, prov, child) {
        // --- ИСПРАВЛЕНО: Используем AuthProvider для проверки isGuest ---
        final authProv = context.watch<AuthProvider>();
        final isGuest = authProv.isGuest; // <-- Проверяем isGuest из AuthProvider
        final displayName = isGuest ? 'Гость' : prov.currentUserName; // <-- Убран tr(), используем строку
        // Используем Supabase для получения email, если пользователь не гость
        final displayEmail = isGuest
            ? 'Войдите в аккаунт'
            : Supabase.instance.client.auth.currentUser?.email ?? 'N/A'; // <-- Убран tr()


        // Используем цвет primary для более яркого акцента на шапке
        return InkWell(
          onTap: isGuest ? null : () => _navigateToProfile(context), // Только если не гость
          splashColor: theme.colorScheme.onPrimary.withAlpha(51),
          highlightColor: theme.colorScheme.onPrimary.withAlpha(26),
          child: Container(
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 20),
            // Убраны BorderRadius, чтобы цвет был сплошным по ширине Drawer
            color: theme.colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Аватар / Иконка профиля
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.onPrimary,
                  child: Icon(
                    isGuest ? Icons.person_off : Icons.person,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), // Анимация увеличения

                const SizedBox(height: 12),
                // Имя пользователя
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Email / Приглашение
                Text(
                  displayEmail,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onPrimary.withAlpha(179), // 0.7 * 255 ≈ 179
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- ИСПРАВЛЕНО: Удалена неиспользуемая переменная 'user' ---
    // final user = Supabase.instance.client.auth.currentUser;

    // --- ИСПРАВЛЕНО: Используем AuthProvider для получения состояния ---
    final authProv = context.watch<AuthProvider>();
    final isGuest = authProv.isGuest;

    // --- ИСПРАВЛЕНО: Используем Provider.of с listen: false для ProjectProvider ---
    final prov = Provider.of<ProjectProvider>(context, listen: false);
    // --- ИСПРАВЛЕНО: Используем ThemeProvider ---
    final themeProv = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      // Закругленные края Drawer'а остались, чтобы он выглядел современно
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 1. Персонализированная кликабельная шапка (сплошной цвет)
          _buildHeader(context),

          // 2. Основное содержимое с отступами
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // --- ОСНОВНЫЕ ПУНКТЫ (Index 0, 1) ---

                  // Переключение темы (Index 0)
                  _buildDrawerItem(
                    context: context,
                    icon: themeProv.currentTheme == ThemeMode.dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined, // <-- Исправлены иконки
                    title: themeProv.currentTheme == ThemeMode.dark ? 'Светлая тема' : 'Тёмная тема',
                    onTap: () => themeProv.toggleTheme(),
                    index: 0,
                    trailing: Switch(
                      value: themeProv.currentTheme == ThemeMode.dark,
                      onChanged: (_) => themeProv.toggleTheme(),
                      activeColor: colorScheme.primary,
                    ),
                  ),

                  // Выбор языка (Index 1)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.language,
                    title: 'Выбрать язык', // <-- Убран tr(), используем строку
                    onTap: () => _showLanguageDialog(context),
                    index: 1,
                    trailing: Text(
                      context.locale.languageCode.toUpperCase(),
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Убран разделитель

                  // --- ПУНКТЫ ДЛЯ АВТОРИЗОВАННОГО ПОЛЬЗОВАТЕЛЯ (Index 2+) ---
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
                      );
                    },
                    child: isGuest // <-- Используем isGuest из authProv
                        ? const SizedBox.shrink(key: ValueKey('guest'))
                        : Column(
                      key: const ValueKey('user'),
                      children: [
                        // Обновление проектов (Index 2)
                        _buildDrawerItem(
                            context: context,
                            icon: Icons.refresh,
                            title: 'Обновить проекты', // <-- Убран tr(), используем строку
                            index: 2,
                            onTap: () async {
                              Navigator.pop(context); // Закрываем, чтобы показать прогресс
                              // Сначала вызываем загрузку
                              await prov.fetchProjects();
                            }
                        ),

                        // Отчеты (Index 3)
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.picture_as_pdf,
                          title: 'Сформировать отчет', // <-- Убран tr(), используем строку
                          index: 3,
                          color: colorScheme.secondary,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Функция отчетов не реализована')), // <-- Убран tr(), используем строку
                            );
                            Navigator.pop(context);
                          },
                        ),

                        // Убран разделитель
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- ВЫХОД / ВХОД (Фиксированный внизу, Index 4) ---
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0, left: 8.0, right: 8.0),
            child: _buildDrawerItem(
              context: context,
              icon: isGuest ? Icons.login : Icons.logout, // <-- Используем isGuest из authProv
              title: isGuest ? 'Войти' : 'Выйти', // <-- Убран tr(), используем строку
              index: isGuest ? 2 : 4,
              color: isGuest ? colorScheme.primary : colorScheme.error,
              onTap: () async {
                // ИСПРАВЛЕНО: Используем AuthProvider для signOut
                final authProvider = context.read<AuthProvider>();
                if (isGuest) {
                  // Навигация на логин
                  // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false); // <-- Предполагается, что маршрут '/login' существует
                  // Для упрощения, можно просто закрыть Drawer и оставить пользователя на LoginScreen, если он уже там
                  Navigator.pop(context); // Закрываем Drawer
                } else {
                  // Выход через AuthProvider
                  await authProvider.signOut(); // <-- Вызываем signOut через AuthProvider
                  // Очистка данных провайдера теперь происходит в AuthProvider.clear() и ProjectProvider.clear()

                  if (context.mounted) {
                    // Переход на логин после выхода (предполагается, что LoginWrapper перехватит состояние)
                    // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    // Или просто закрываем Drawer, и LoginWrapper переключится на LoginScreen
                    Navigator.pop(context); // Закрываем Drawer
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Диалог выбора языка
  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выберите язык'), // <-- Убран tr(), используем строку
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Русский'), onTap: () { context.setLocale(const Locale('ru')); Navigator.pop(dialogContext); }),
            ListTile(title: const Text('English'), onTap: () { context.setLocale(const Locale('en')); Navigator.pop(dialogContext); }),
          ],
        ),
      ),
    );
  }
}