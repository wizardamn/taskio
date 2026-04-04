import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

import '../screens/profile/profile_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/auth/login_screen.dart';

import '../utils/app_logger.dart';
import '../utils/snackbar_manager.dart';
import '../utils/localization_helper.dart';
import '../utils/loading_overlay.dart';

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({super.key});

  // ======================================================
  // Drawer Item
  // ======================================================

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required int index,
    Color? color,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  color: color ?? theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (50 * index).ms)
        .slideX(begin: 0.05);
  }

  // ======================================================
  // HEADER
  // ======================================================

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<ProjectProvider, AuthProvider>(
      builder: (_, projectProv, authProv, __) {
        final isGuest = authProv.isGuest;

        final displayName =
        isGuest ? 'profile.guest'.tr() : projectProv.currentUserName;

        final displayEmail = isGuest
            ? 'profile.guest_email'.tr()
            : authProv.user?.email ?? 'auth.email_not_provided'.tr();

        return InkWell(
          onTap: isGuest
              ? null
              : () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ProfileScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            padding:
            const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.surface,
                  child: Icon(
                    isGuest
                        ? Icons.person_off_rounded
                        : Icons.person_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(displayName,
                    style: theme.textTheme.headlineSmall!
                        .copyWith(color: theme.colorScheme.onPrimary)),
                const SizedBox(height: 4),
                Text(displayEmail,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.onPrimary)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final projectProv = context.read<ProjectProvider>();

    final isGuest = authProv.isGuest;
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          _buildHeader(context),

          Expanded(
            child: ListView(
              children: [
                _sectionTitle(context, 'navigation.settings'.tr()),

                // THEME SWITCH
                _buildDrawerItem(
                  context: context,
                  icon: themeProv.isDark
                      ? Icons.wb_sunny
                      : Icons.dark_mode,
                  title: themeProv.isDark
                      ? 'profile.light_theme'.tr()
                      : 'profile.dark_theme'.tr(),
                  onTap: () {
                    themeProv.toggleTheme();
                  },
                  index: 0,
                ),

                // LANGUAGE
                _buildDrawerItem(
                  context: context,
                  icon: Icons.language,
                  title: 'profile.choose_language'.tr(),
                  onTap: () => _showLanguageDialog(context),
                  index: 1,
                ),

                const Divider(),

                _sectionTitle(context, 'navigation.management'.tr()),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.calendar_month,
                  title: 'navigation.calendar'.tr(),
                  index: 2,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CalendarScreen()),
                    );
                  },
                ),

                if (!isGuest)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.sync,
                    title: 'projects.refresh'.tr(),
                    index: 3,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await projectProv.fetchProjects();
                    },
                  ),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'app.about'.tr(),
                  index: 4,
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),

          // ================= LOGIN / LOGOUT =================

          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildDrawerItem(
              context: context,
              icon: isGuest ? Icons.login : Icons.logout,
              title: isGuest
                  ? 'auth.login'.tr()
                  : 'auth.logout'.tr(),
              index: 5,
              color: isGuest
                  ? colorScheme.primary
                  : colorScheme.error,
              onTap: () async {
                Navigator.of(context).pop();

                if (isGuest) {
                  // 🔥 Гость → перейти на экран входа
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                  );
                } else {
                  await authProv.signOut();
                  SnackbarManager.showSuccess(
                      'auth.logout_success'.tr());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // SECTION TITLE
  // ======================================================

  Widget _sectionTitle(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ======================================================
  // LANGUAGE DIALOG
  // ======================================================

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final current = context.locale.languageCode;

        return AlertDialog(
          title: Text('profile.choose_language'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _languageTile(context,
                  code: 'ru',
                  label: 'Русский',
                  selected: current == 'ru'),
              _languageTile(context,
                  code: 'en',
                  label: 'English',
                  selected: current == 'en'),
            ],
          ),
        );
      },
    );
  }

  Widget _languageTile(
      BuildContext context, {
        required String code,
        required String label,
        required bool selected,
      }) {
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () async {
        LoadingOverlay.show();

        await LocalizationHelper.changeLanguage(context, code);

        AppLogger.info('Language changed to $code');

        if (context.mounted) {
          Navigator.of(context).pop();
          SnackbarManager.showSuccess('profile.language_changed'.tr());
        }

        LoadingOverlay.hide();
      },
    );
  }

  // ======================================================
  // ABOUT
  // ======================================================

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Taskio',
      applicationVersion: '1.0.0',
      children: [
        Text('app.description'.tr()),
        const SizedBox(height: 8),
        Text('app.copyright'.tr()),
      ],
    );
  }
}