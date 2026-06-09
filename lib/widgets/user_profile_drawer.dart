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
import '../screens/export/export_screen.dart';

import '../services/notification_service.dart';
import '../services/supabase_service.dart';

import '../utils/app_logger.dart';
import '../utils/snackbar_manager.dart';
import '../utils/localization_helper.dart';
import '../utils/loading_overlay.dart';
import '../utils/error_mapper.dart';

class UserProfileDrawer extends StatefulWidget {
  const UserProfileDrawer({
    super.key,
  });

  @override
  State<UserProfileDrawer> createState() => _UserProfileDrawerState();
}

class _UserProfileDrawerState extends State<UserProfileDrawer> {
  final NotificationService _notificationService = NotificationService();

  String? _avatarUrl;
  String? _loadedUserId;

  bool _isAvatarLoading = false;

  String? _notificationUserId;
  bool _isNotificationSettingsLoading = false;

  bool _allNotificationsEnabled = true;
  bool _chatNotificationsEnabled = true;
  bool _projectUpdatesEnabled = true;


  // ======================================================
  // DRAWER NAVIGATION
  // ======================================================

  Future<void> _closeDrawerAndWait(BuildContext context) async {
    final scaffoldState = Scaffold.maybeOf(context);

    if (scaffoldState?.isDrawerOpen ?? false) {
      scaffoldState!.closeDrawer();

      await Future<void>.delayed(
        const Duration(milliseconds: 180),
      );

      return;
    }

    final navigator = Navigator.maybeOf(context);

    if (navigator != null && navigator.canPop()) {
      navigator.pop();

      await Future<void>.delayed(
        const Duration(milliseconds: 180),
      );
    }
  }

  Future<void> _openProfileScreen({
    required BuildContext context,
    required String? userId,
  }) async {
    final navigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    await _closeDrawerAndWait(context);

    if (!navigator.mounted) {
      return;
    }

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );

    if (!mounted || userId == null || userId.isEmpty) {
      return;
    }

    await _reloadAvatar(userId);
  }

  Future<void> _openCalendarScreen(BuildContext context) async {
    final navigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    await _closeDrawerAndWait(context);

    if (!navigator.mounted) {
      return;
    }

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => const CalendarScreen(),
      ),
    );
  }

  Future<void> _openAboutAppDialog(BuildContext context) async {
    final navigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    await _closeDrawerAndWait(context);

    if (!navigator.mounted) {
      return;
    }

    _showAboutDialog(navigator.context);
  }

  // ======================================================
  // AVATAR LOADING
  // ======================================================

  Future<void> _loadAvatar(String userId) async {
    if (_isAvatarLoading || _loadedUserId == userId) {
      return;
    }

    _isAvatarLoading = true;
    _loadedUserId = userId;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final rawAvatar = response?['avatar_url']?.toString().trim();

      final normalizedAvatar = _normalizeAvatarUrl(
        rawAvatar,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarUrl = normalizedAvatar;
      });
    } catch (e, st) {
      AppLogger.error(
        'Avatar loading failed',
        error: e,
        stackTrace: st,
        tag: 'Drawer',
      );
    } finally {
      _isAvatarLoading = false;
    }
  }

  Future<void> _reloadAvatar(String userId) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarUrl = null;
      _loadedUserId = null;
    });

    await _loadAvatar(userId);
  }

  String? _normalizeAvatarUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();

    const oldAvatarBucketMarker =
        '/storage/v1/object/public/avatars/';

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      if (raw.contains(oldAvatarBucketMarker)) {
        return raw.replaceFirst(
          oldAvatarBucketMarker,
          '/storage/v1/object/public/${SupabaseService.bucket}/',
        );
      }

      return raw;
    }

    var path = raw.replaceAll('\\', '/');

    while (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (path.startsWith('avatars/')) {
      path = path.substring(
        'avatars/'.length,
      );
    }

    if (path.startsWith('${SupabaseService.bucket}/')) {
      path = path.substring(
        '${SupabaseService.bucket}/'.length,
      );
    }

    return SupabaseService.client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(path);
  }

  // ======================================================
  // NOTIFICATION SETTINGS
  // ======================================================

  Future<void> _loadNotificationSettings(String userId) async {
    if (_isNotificationSettingsLoading ||
        _notificationUserId == userId) {
      return;
    }

    _isNotificationSettingsLoading = true;
    _notificationUserId = userId;

    try {
      final settings =
      await _notificationService.getGlobalSettings(
        forceRefresh: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _allNotificationsEnabled = settings.allEnabled;
        _chatNotificationsEnabled = settings.chatEnabled;
        _projectUpdatesEnabled =
            settings.projectUpdatesEnabled;
      });
    } catch (e, st) {
      AppLogger.error(
        'Notification settings loading failed',
        error: e,
        stackTrace: st,
        tag: 'Drawer',
      );
    } finally {
      _isNotificationSettingsLoading = false;
    }
  }

  Future<void> _toggleAllNotifications(bool value) async {
    if (!mounted) {
      return;
    }

    final previous = _allNotificationsEnabled;

    setState(() {
      _allNotificationsEnabled = value;
    });

    try {
      await _notificationService.setGlobalAllEnabled(value);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        value
            ? 'notifications.all_enabled'
            : 'notifications.all_disabled',
      );
    } catch (e, st) {
      AppLogger.error(
        'Toggle all notifications failed',
        error: e,
        stackTrace: st,
        tag: 'Drawer',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _allNotificationsEnabled = previous;
      });

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  Future<void> _toggleChatNotifications(bool value) async {
    if (!mounted) {
      return;
    }

    final previous = _chatNotificationsEnabled;

    setState(() {
      _chatNotificationsEnabled = value;
    });

    try {
      await _notificationService.setGlobalChatEnabled(value);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        value
            ? 'notifications.chat_enabled'
            : 'notifications.chat_disabled',
      );
    } catch (e, st) {
      AppLogger.error(
        'Toggle chat notifications failed',
        error: e,
        stackTrace: st,
        tag: 'Drawer',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _chatNotificationsEnabled = previous;
      });

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  Future<void> _toggleProjectUpdates(bool value) async {
    if (!mounted) {
      return;
    }

    final previous = _projectUpdatesEnabled;

    setState(() {
      _projectUpdatesEnabled = value;
    });

    try {
      await _notificationService
          .setGlobalProjectUpdatesEnabled(value);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        value
            ? 'notifications.project_updates_enabled'
            : 'notifications.project_updates_disabled',
      );
    } catch (e, st) {
      AppLogger.error(
        'Toggle project update notifications failed',
        error: e,
        stackTrace: st,
        tag: 'Drawer',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _projectUpdatesEnabled = previous;
      });

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // ======================================================
  // AVATAR UI
  // ======================================================

  Widget _buildAvatar({
    required BuildContext context,
    required bool isGuest,
    required String? avatarUrl,
  }) {
    final theme = Theme.of(context);

    final fallbackIcon = Icon(
      isGuest ? Icons.person_off_rounded : Icons.person_rounded,
      color: theme.colorScheme.primary,
      size: 34,
    );

    if (isGuest || avatarUrl == null || avatarUrl.trim().isEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundColor: theme.colorScheme.surface,
        child: fallbackIcon,
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        avatarUrl,
        key: ValueKey(avatarUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Center(
            child: fallbackIcon,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================================================
  // DRAWER ITEMS
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
    final itemColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: itemColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
      delay: (50 * index).ms,
    )
        .slideX(begin: 0.05);
  }

  Widget _buildSwitchItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required int index,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);

    final iconColor = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.disabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () {
          onChanged(!value);
        }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: enabled ? null : theme.disabledColor,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
      delay: (50 * index).ms,
    )
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
        final user = authProv.user;
        final userId = user?.id;

        if (!isGuest && userId != null) {
          if (_loadedUserId != userId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadAvatar(userId);
              }
            });
          }

          if (_notificationUserId != userId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadNotificationSettings(userId);
              }
            });
          }
        }

        if (isGuest &&
            (_avatarUrl != null ||
                _loadedUserId != null ||
                _notificationUserId != null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _avatarUrl = null;
              _loadedUserId = null;
              _notificationUserId = null;
              _allNotificationsEnabled = true;
              _chatNotificationsEnabled = true;
              _projectUpdatesEnabled = true;
            });
          });
        }

        final metadataAvatar =
        user?.userMetadata?['avatar_url']?.toString();

        final displayAvatar =
            _avatarUrl ?? _normalizeAvatarUrl(metadataAvatar);

        final displayName = isGuest
            ? 'profile.guest'.tr()
            : projectProv.currentUserName.isNotEmpty
            ? projectProv.currentUserName
            : 'common.user'.tr();

        final displayEmail = isGuest
            ? 'profile.guest_email'.tr()
            : user?.email ?? 'auth.email_not_provided'.tr();

        return InkWell(
          onTap: isGuest
              ? null
              : () {
            _openProfileScreen(
              context: context,
              userId: userId,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 50,
              left: 24,
              right: 24,
              bottom: 24,
            ),
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
                _buildAvatar(
                  context: context,
                  isGuest: isGuest,
                  avatarUrl: displayAvatar,
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================================================
  // EXPORT
  // ======================================================

  Future<void> _openExportScreen({
    required BuildContext context,
    required ProjectProvider projectProv,
  }) async {
    final navigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    await _closeDrawerAndWait(context);

    try {
      LoadingOverlay.show();

      await projectProv.fetchProjects();
    } catch (e, st) {
      AppLogger.error(
        'Refresh before export failed',
        error: e,
        stackTrace: st,
        tag: 'Drawer',
      );

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      LoadingOverlay.hide();
    }

    if (!navigator.mounted) {
      return;
    }

    final projects = projectProv.projects;

    if (projects.isEmpty) {
      SnackbarManager.showError(
        'projects.no_projects',
      );
      return;
    }

    final previousCurrentProject = projectProv.currentProject;

    final currentProject = previousCurrentProject != null &&
        projects.any(
              (project) => project.id == previousCurrentProject.id,
        )
        ? previousCurrentProject
        : projects.first;

    projectProv.setCurrentProject(currentProject.id);

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ExportScreen(
          projectId: currentProject.id,
        ),
      ),
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
                _sectionTitle(
                  context,
                  'navigation.settings'.tr(),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: themeProv.isDark
                      ? Icons.wb_sunny_outlined
                      : Icons.dark_mode_outlined,
                  title: themeProv.isDark
                      ? 'profile.light_theme'.tr()
                      : 'profile.dark_theme'.tr(),
                  index: 0,
                  onTap: themeProv.toggleTheme,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.language_outlined,
                  title: 'profile.choose_language'.tr(),
                  index: 1,
                  onTap: () => _showLanguageDialog(context),
                ),
                if (!isGuest) ...[
                  const Divider(),
                  _sectionTitle(
                    context,
                    'notifications.title'.tr(),
                  ),
                  _buildSwitchItem(
                    context: context,
                    icon: _allNotificationsEnabled
                        ? Icons.notifications_none_outlined
                        : Icons.notifications_off_outlined,
                    title: 'notifications.all'.tr(),
                    value: _allNotificationsEnabled,
                    onChanged: _toggleAllNotifications,
                    index: 2,
                  ),
                  _buildSwitchItem(
                    context: context,
                    icon: Icons.chat_bubble_outline,
                    title: 'notifications.chat'.tr(),
                    value: _chatNotificationsEnabled,
                    onChanged: _toggleChatNotifications,
                    index: 3,
                    enabled: _allNotificationsEnabled,
                  ),
                  _buildSwitchItem(
                    context: context,
                    icon: Icons.update_outlined,
                    title: 'notifications.project_updates'.tr(),
                    value: _projectUpdatesEnabled,
                    onChanged: _toggleProjectUpdates,
                    index: 4,
                    enabled: _allNotificationsEnabled,
                  ),
                ],
                const Divider(),
                _sectionTitle(
                  context,
                  'navigation.management'.tr(),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'export.title'.tr(),
                  index: 5,
                  onTap: () {
                    _openExportScreen(
                      context: context,
                      projectProv: projectProv,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.calendar_month_outlined,
                  title: 'navigation.calendar'.tr(),
                  index: 6,
                  onTap: () {
                    _openCalendarScreen(context);
                  },
                ),
                if (!isGuest)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.sync_outlined,
                    title: 'projects.refresh'.tr(),
                    index: 7,
                    onTap: () async {
                      await _closeDrawerAndWait(context);

                      try {
                        LoadingOverlay.show();

                        await projectProv.fetchProjects();

                        SnackbarManager.showSuccess(
                          'common.updated',
                        );
                      } catch (e, st) {
                        AppLogger.error(
                          'Refresh projects failed',
                          error: e,
                          stackTrace: st,
                          tag: 'Drawer',
                        );

                        SnackbarManager.showError(
                          ErrorMapper.map(e),
                        );
                      } finally {
                        LoadingOverlay.hide();
                      }
                    },
                  ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'app.about'.tr(),
                  index: 8,
                  onTap: () {
                    _openAboutAppDialog(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildDrawerItem(
              context: context,
              icon: isGuest
                  ? Icons.login_outlined
                  : Icons.logout_outlined,
              title: isGuest
                  ? 'auth.login'.tr()
                  : 'auth.logout'.tr(),
              index: 9,
              color: isGuest ? colorScheme.primary : colorScheme.error,
              onTap: () async {
                final navigator = Navigator.of(
                  context,
                  rootNavigator: true,
                );

                try {
                  await _closeDrawerAndWait(context);

                  if (isGuest) {
                    await authProv.signOut();

                    if (!navigator.mounted) {
                      return;
                    }

                    await navigator.push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );

                    return;
                  }

                  await authProv.signOut();

                  _notificationService.clearSettingsCache();

                  if (mounted) {
                    setState(() {
                      _avatarUrl = null;
                      _loadedUserId = null;
                      _notificationUserId = null;
                      _allNotificationsEnabled = true;
                      _chatNotificationsEnabled = true;
                      _projectUpdatesEnabled = true;
                    });
                  }

                  SnackbarManager.showSuccess(
                    'auth.logout_success',
                  );
                } catch (e, st) {
                  AppLogger.error(
                    'Logout failed',
                    error: e,
                    stackTrace: st,
                    tag: 'Drawer',
                  );

                  SnackbarManager.showError(
                    ErrorMapper.map(e),
                  );
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

  Widget _sectionTitle(
      BuildContext context,
      String text,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        16,
        24,
        8,
      ),
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
  // LANGUAGE
  // ======================================================

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final current = dialogContext.locale.languageCode;

        return AlertDialog(
          title: Text(
            'profile.choose_language'.tr(),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _languageTile(
                dialogContext,
                code: 'ru',
                label: 'Русский',
                selected: current == 'ru',
              ),
              _languageTile(
                dialogContext,
                code: 'en',
                label: 'English',
                selected: current == 'en',
              ),
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
        try {
          LoadingOverlay.show();

          await LocalizationHelper.changeLanguage(
            context,
            code,
          );

          AppLogger.info(
            'Language changed to $code',
            tag: 'Drawer',
          );

          if (!context.mounted) {
            return;
          }

          Navigator.of(context).pop();

          SnackbarManager.showSuccess(
            'profile.language_changed',
          );
        } catch (e, st) {
          AppLogger.error(
            'Language change failed',
            error: e,
            stackTrace: st,
            tag: 'Drawer',
          );

          SnackbarManager.showError(
            ErrorMapper.map(e),
          );
        } finally {
          LoadingOverlay.hide();
        }
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
        Text(
          'app.description'.tr(),
        ),
        const SizedBox(height: 8),
        Text(
          'app.copyright'.tr(),
        ),
      ],
    );
  }
}