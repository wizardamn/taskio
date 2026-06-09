import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/project_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/snackbar_manager.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  List<ProjectNotificationData> _notifications = [];

  bool _isLoading = true;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _loadData();
    });
  }

  // =========================================================
  // LOAD
  // =========================================================

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<ProjectProvider>().fetchPendingInvitations();

      final notifications =
      await _notificationService.getMyNotifications(
        limit: 100,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = notifications;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'notifications.load_error'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingRead) {
      return;
    }

    try {
      setState(() {
        _isMarkingRead = true;
      });

      await _notificationService.markAllProjectNotificationsAsRead();

      await _loadData();

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'notifications.marked_as_read'.tr(),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'notifications.update_error'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingRead = false;
        });
      }
    }
  }

  Future<void> _markOneAsRead(
      ProjectNotificationData notification,
      ) async {
    if (notification.isRead) {
      return;
    }

    try {
      await _notificationService.markNotificationAsRead(
        notification.id,
      );

      await _loadData();
    } catch (_) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'notifications.update_error'.tr(),
      );
    }
  }

  // =========================================================
  // INVITATIONS
  // =========================================================

  Future<void> _acceptInvitation(String invitationId) async {
    try {
      await context.read<ProjectProvider>().acceptInvitation(invitationId);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'invitations.accepted'.tr(),
      );

      await _loadData();
    } catch (_) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'notifications.update_error'.tr(),
      );
    }
  }

  Future<void> _declineInvitation(String invitationId) async {
    try {
      await context.read<ProjectProvider>().declineInvitation(invitationId);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'invitations.declined'.tr(),
      );

      await _loadData();
    } catch (_) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'notifications.update_error'.tr(),
      );
    }
  }

  String _invitationProjectTitle(
      Map<String, dynamic> invitation,
      ) {
    final projectRaw = invitation['projects'];

    if (projectRaw is Map) {
      final title = projectRaw['title']?.toString().trim();

      if (title != null && title.isNotEmpty) {
        return title;
      }
    }

    return 'notifications.project'.tr();
  }

  String _invitationRoleText(
      Map<String, dynamic> invitation,
      ) {
    final role = invitation['role']?.toString();

    switch (role) {
      case 'editor':
        return 'invitations.editor'.tr();

      case 'viewer':
        return 'invitations.viewer'.tr();

      default:
        return 'invitations.member'.tr();
    }
  }

  // =========================================================
  // NOTIFICATION TEXT
  // =========================================================

  String _projectArg(ProjectNotificationData notification) {
    final projectTitle = notification.projectTitle?.trim();

    if (projectTitle != null && projectTitle.isNotEmpty) {
      return projectTitle;
    }

    return 'notifications.project'.tr();
  }

  String _notificationTitle(ProjectNotificationData notification) {
    switch (notification.type) {
      case 'project_created':
        return 'notifications.project_created_title'.tr();

      case 'project_updated':
        return 'notifications.project_updated_title'.tr();

      case 'project_deleted':
        return 'notifications.project_deleted_title'.tr();

      case 'project_completed':
        return 'notifications.project_completed_title'.tr();

      case 'project_graded':
        return 'notifications.project_graded_title'.tr();

      case 'member_invited':
        return 'notifications.member_invited_title'.tr();

      case 'member_invite_accepted':
        return 'notifications.member_invite_accepted_title'.tr();

      case 'member_invite_declined':
        return 'notifications.member_invite_declined_title'.tr();

      case 'file_uploaded':
      case 'file_added':
        return 'notifications.file_added_title'.tr();

      case 'deadline':
      case 'deadline_soon':
        return 'notifications.deadline_title'.tr();

      case 'new_message':
      case 'chat_message':
        return 'notifications.new_message_title'.tr();

      case 'task_created':
        return 'notifications.task_created_title'.tr();

      case 'task_completed':
        return 'notifications.task_completed_title'.tr();

      default:
        final title = notification.title.trim();

        if (title.isNotEmpty) {
          return title;
        }

        return 'notifications.title'.tr();
    }
  }

  String _notificationBody(ProjectNotificationData notification) {
    final project = _projectArg(notification);

    switch (notification.type) {
      case 'project_created':
        return 'notifications.project_created_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'project_updated':
        return 'notifications.project_updated_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'project_deleted':
        return 'notifications.project_deleted_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'project_completed':
        return 'notifications.project_completed_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'member_invited':
        return 'notifications.member_invited_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'member_invite_accepted':
        return 'notifications.member_invite_accepted_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'member_invite_declined':
        return 'notifications.member_invite_declined_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'file_uploaded':
      case 'file_added':
        return 'notifications.file_added_body'.tr();

      case 'new_message':
      case 'chat_message':
        return 'notifications.new_message_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'task_created':
        return 'notifications.task_created_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'task_completed':
        return 'notifications.task_completed_body'.tr(
          namedArgs: {
            'project': project,
          },
        );

      case 'deadline':
      case 'deadline_soon':
        return '${'notifications.deadline_body'.tr()} $project';

      case 'project_graded':
        final body = notification.body.trim();

        if (body.isNotEmpty) {
          return body;
        }

        return 'notifications.project_graded_title'.tr();

      default:
        final body = notification.body.trim();

        if (body.isNotEmpty) {
          return body;
        }

        return 'notifications.title'.tr();
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMd(
      context.locale.toString(),
    ).add_Hm().format(date.toLocal());
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    final invitations = provider.pendingInvitations;

    final hasInvitations = invitations.isNotEmpty;
    final hasNotifications = _notifications.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'notifications.title'.tr(),
        ),
        actions: [
          if (hasNotifications)
            IconButton(
              tooltip: 'notifications.mark_all_as_read'.tr(),
              onPressed: _isMarkingRead ? null : _markAllAsRead,
              icon: _isMarkingRead
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.done_all_outlined,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? _buildLoading()
            : !hasInvitations && !hasNotifications
            ? _buildEmpty()
            : ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24,
          ),
          children: [
            if (hasInvitations) ...[
              _buildSectionTitle(
                icon: Icons.group_add_outlined,
                title: 'notifications.invitations'.tr(),
              ),
              const SizedBox(height: 8),
              ...invitations.map(
                _buildInvitationCard,
              ),
              const SizedBox(height: 20),
            ],
            if (hasNotifications) ...[
              _buildSectionTitle(
                icon: Icons.notifications_outlined,
                title: 'notifications.history_title'.tr(),
              ),
              const SizedBox(height: 8),
              ..._notifications.map(
                _buildNotificationCard,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // UI PARTS
  // =========================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(
      Map<String, dynamic> invitation,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invitationId = invitation['id']?.toString() ?? '';
    final projectTitle = _invitationProjectTitle(invitation);
    final roleText = _invitationRoleText(invitation);

    final createdAt = DateTime.tryParse(
      invitation['created_at']?.toString() ?? '',
    );

    final dateText = createdAt == null ? '' : _formatDate(createdAt);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.group_add_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'invitations.project_invitation'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'invitations.invited_to_project'.tr(
                          namedArgs: {
                            'project': projectTitle,
                          },
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${'invitations.role'.tr()}: $roleText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (dateText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: invitationId.isEmpty
                        ? null
                        : () => _declineInvitation(invitationId),
                    icon: const Icon(
                      Icons.close_outlined,
                    ),
                    label: Text(
                      'invitations.decline'.tr(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: invitationId.isEmpty
                        ? null
                        : () => _acceptInvitation(invitationId),
                    icon: const Icon(
                      Icons.check_outlined,
                    ),
                    label: Text(
                      'invitations.accept'.tr(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      ProjectNotificationData notification,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateText = _formatDate(notification.createdAt);

    final icon = _notificationIcon(notification.type);

    final title = _notificationTitle(notification);
    final body = _notificationBody(notification);

    final projectTitle = notification.projectTitle?.trim();

    return Card(
      elevation: 0,
      color: notification.isRead
          ? colorScheme.surfaceContainerLowest
          : colorScheme.primaryContainer.withValues(
        alpha: 0.35,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: notification.isRead
              ? colorScheme.outlineVariant
              : colorScheme.primary.withValues(
            alpha: 0.45,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _markOneAsRead(notification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: notification.isRead
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (projectTitle != null &&
                        projectTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${'notifications.project'.tr()}: $projectTitle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'project_created':
        return Icons.add_circle_outline;

      case 'project_updated':
        return Icons.edit_note_outlined;

      case 'project_deleted':
        return Icons.delete_outline;

      case 'project_completed':
        return Icons.task_alt_outlined;

      case 'project_graded':
        return Icons.grade_outlined;

      case 'member_invited':
        return Icons.group_add_outlined;

      case 'member_invite_accepted':
        return Icons.check_circle_outline;

      case 'member_invite_declined':
        return Icons.cancel_outlined;

      case 'file_uploaded':
      case 'file_added':
        return Icons.attach_file_outlined;

      case 'deadline':
      case 'deadline_soon':
        return Icons.event_busy_outlined;

      case 'new_message':
      case 'chat_message':
        return Icons.chat_bubble_outline;

      case 'task_created':
        return Icons.add_task_outlined;

      case 'task_completed':
        return Icons.task_alt_outlined;

      default:
        return Icons.notifications_outlined;
    }
  }

  Widget _buildLoading() {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, index) {
        return Container(
          height: 86,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.notifications_none_outlined,
          size: 72,
          color: colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'notifications.no_notifications_title'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'notifications.no_notifications_body'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}