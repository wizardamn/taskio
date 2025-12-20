import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart'; // Импорт для перевода
import 'package:flutter_animate/flutter_animate.dart';
//import 'package:package_info_plus/package_info_plus.dart';

import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/calendar/calendar_screen.dart';

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({super.key});

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isDestructive = color == theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          splashColor: isDestructive
              ? color!.withAlpha(40)
              : theme.colorScheme.primary.withAlpha(20),
          highlightColor: isDestructive
              ? color!.withAlpha(20)
              : theme.colorScheme.primary.withAlpha(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color ?? theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontSize: 16,
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
    ).animate()
        .fadeIn(delay: (50 * index).ms, duration: 300.ms)
        .slideX(begin: 0.05, end: 0, delay: (50 * index).ms, duration: 300.ms);
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ProjectProvider>(
      builder: (context, prov, child) {
        final authProv = context.watch<AuthProvider>();
        final isGuest = authProv.isGuest;

        // Используем ключи перевода
        final displayName = isGuest ? 'guest'.tr() : prov.currentUserName;
        final displayEmail = isGuest
            ? 'guest_email'.tr()
            : authProv.user?.email ?? 'email_not_provided'.tr();

        return InkWell(
          onTap: isGuest ? null : () => _navigateToProfile(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.surface,
                    child: Icon(
                      isGuest ? Icons.person_off_rounded : Icons.person_rounded,
                      color: theme.colorScheme.primary,
                      size: 36,
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 16),

                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 4),

                Text(
                  displayEmail,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onPrimary.withAlpha(200),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final isGuest = authProv.isGuest;
    final prov = Provider.of<ProjectProvider>(context, listen: false);
    final themeProv = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: [
                // Секция: Настройки
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    "settings".tr(), // Ключ
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

                // Тема
                _buildDrawerItem(
                  context: context,
                  icon: themeProv.currentTheme == ThemeMode.dark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                  // Динамический ключ для темы
                  title: themeProv.currentTheme == ThemeMode.dark ? 'light_theme'.tr() : 'dark_theme'.tr(),
                  onTap: () => themeProv.toggleTheme(),
                  index: 0,
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: themeProv.currentTheme == ThemeMode.dark,
                      onChanged: (_) => themeProv.toggleTheme(),
                      activeColor: colorScheme.primary,
                    ),
                  ),
                ),

                // Язык
                _buildDrawerItem(
                  context: context,
                  icon: Icons.language_rounded,
                  title: 'language'.tr(), // Ключ
                  onTap: () => _showLanguageDialog(context),
                  index: 1,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.locale.languageCode.toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                const Divider(indent: 24, endIndent: 24, height: 24),

                // Секция: Управление
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    "management".tr(), // Ключ
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

                // Календарь
                _buildDrawerItem(
                  context: context,
                  icon: Icons.calendar_month_rounded,
                  title: 'calendar'.tr(), // Ключ
                  index: 2,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    );
                  },
                ),

                // Для авторизованных
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
                      // Обновить проекты
                      _buildDrawerItem(
                          context: context,
                          icon: Icons.sync_rounded,
                          title: 'refresh_projects'.tr(), // Ключ
                          index: 3,
                          onTap: () async {
                            Navigator.pop(context);
                            await prov.fetchProjects();
                          }
                      ),

                      // Отчеты
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.summarize_rounded,
                        title: 'reports'.tr(), // Ключ
                        index: 4,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('report_functionality_not_impl'.tr())), // Ключ
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(indent: 24, endIndent: 24, height: 24),

                // О приложении
                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'about_app'.tr(), // Ключ
                  index: 5,
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),

          // Вход / Выход
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 12.0, right: 12.0, top: 8.0),
            child: _buildDrawerItem(
              context: context,
              icon: isGuest ? Icons.login_rounded : Icons.logout_rounded,
              title: isGuest ? 'login'.tr() : 'logout'.tr(), // Ключи
              index: 6,
              color: isGuest ? colorScheme.primary : colorScheme.error,
              onTap: () async {
                final authProvider = context.read<AuthProvider>();
                if (isGuest) {
                  Navigator.pop(context);
                } else {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('logout_title'.tr()), // Ключ
                      content: Text('logout_confirmation'.tr()), // Ключ
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel'.tr())), // Ключ
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('logout'.tr(), style: TextStyle(color: colorScheme.error)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('choose_language'.tr()), // Ключ
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇷🇺', style: TextStyle(fontSize: 24)),
              title: const Text('Русский'), // Можно использовать 'language_ru'.tr()
              onTap: () {
                context.setLocale(const Locale('ru'));
                Navigator.pop(dialogContext);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English'), // Можно использовать 'language_en'.tr()
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(dialogContext);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) async {
    // В реальном приложении раскомментируйте package_info_plus:
    // PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // String version = packageInfo.version;
    const version = "1.0.0";

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Taskio',
      applicationVersion: 'v$version',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary),
      ),
      children: [
        Text('app_description'.tr()), // Ключ
        const SizedBox(height: 16),
        Text('copyright'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)), // Ключ
      ],
    );
  }
}