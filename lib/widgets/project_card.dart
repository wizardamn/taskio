import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../utils/project_ui_utils.dart';
import '../utils/snackbar_manager.dart';
import 'highlight_text.dart';

class ProjectCard extends StatefulWidget {
  final ProjectModel project;

  /// Открытие карточки проекта.
  /// Даже viewer должен иметь возможность открыть карточку.
  final Function(ProjectModel) onEdit;

  final Function(ProjectModel) onDelete;
  final VoidCallback? onChat;

  /// Право редактировать проект.
  /// owner/editor — true.
  /// viewer — false.
  final bool canEdit;

  /// true только для владельца.
  final bool isOwner;

  final String searchQuery;

  /// Передаётся из ProjectListScreen через unreadMap.
  /// Если null — используется project.unreadCount.
  final int? unreadCount;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.isOwner,
    required this.searchQuery,
    this.onChat,
    this.unreadCount,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  final NotificationService _notificationService =
  NotificationService();

  bool _notificationsEnabled = true;
  bool _isNotificationLoading = false;

  int get _effectiveUnreadCount {
    return widget.unreadCount ?? widget.project.unreadCount;
  }

  /// Меню с тремя точками показывается только тем,
  /// кто реально может редактировать или удалить проект.
  ///
  /// viewer меню не видит, но открыть проект, чат и уведомления может.
  bool get _canShowMenu {
    return widget.canEdit || widget.isOwner;
  }

  bool get _canEditProject {
    return widget.canEdit || widget.isOwner;
  }

  bool get _canDeleteProject {
    return widget.isOwner;
  }

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  @override
  void didUpdateWidget(covariant ProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.project.id != widget.project.id) {
      _loadNotificationSettings();
    }
  }

  // =========================================================
  // TEXT
  // =========================================================

  String _text(
      BuildContext context, {
        required String ru,
        required String en,
      }) {
    return context.locale.languageCode == 'ru' ? ru : en;
  }

  // =========================================================
  // NOTIFICATIONS
  // =========================================================

  Future<void> _loadNotificationSettings() async {
    if (widget.project.id.trim().isEmpty) {
      return;
    }

    try {
      final settings =
      await _notificationService.getProjectSettings(
        widget.project.id,
        forceRefresh: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = settings.allEnabled &&
            settings.chatEnabled &&
            settings.projectUpdatesEnabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = true;
      });
    }
  }

  Future<void> _toggleProjectNotifications() async {
    if (_isNotificationLoading) {
      return;
    }

    final nextValue = !_notificationsEnabled;

    final successMessage = nextValue
        ? _text(
      context,
      ru: 'Уведомления включены',
      en: 'Notifications enabled',
    )
        : _text(
      context,
      ru: 'Уведомления отключены',
      en: 'Notifications disabled',
    );

    final errorMessage = _text(
      context,
      ru: 'Не удалось изменить настройки уведомлений',
      en: 'Failed to change notification settings',
    );

    try {
      setState(() {
        _isNotificationLoading = true;
      });

      await _notificationService.setProjectNotificationsEnabled(
        projectId: widget.project.id,
        value: nextValue,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = nextValue;
      });

      SnackbarManager.showSuccess(successMessage);
    } catch (_) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isNotificationLoading = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final progress = widget.project.progress.clamp(
      0.0,
      1.0,
    );

    final participants = widget.project.participantsData;

    final deadline = DateFormat.yMMMd(
      context.locale.toString(),
    ).format(widget.project.deadline);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          widget.onEdit(widget.project);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildHeader(context),

              const SizedBox(height: 8),

              _buildLastMessage(context),

              if (widget.project.totalTasks > 0) ...[
                const SizedBox(height: 10),
                _buildProgress(
                  progress,
                  colorScheme,
                ),
              ],

              if (participants.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildParticipants(
                  context,
                  participants,
                ),
              ],

              const SizedBox(height: 8),

              _buildMeta(
                context,
                deadline,
              ),

              if (widget.project.attachments.isNotEmpty)
                _buildAttachments(context),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = _effectiveUnreadCount;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.project.colorObj,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: HighlightText(
            text: widget.project.title,
            query: widget.searchQuery,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight: count > 0
                  ? FontWeight.w800
                  : FontWeight.bold,
            ),
          ),
        ),

        _NotificationButton(
          enabled: _notificationsEnabled,
          loading: _isNotificationLoading,
          onPressed: _toggleProjectNotifications,
        ),

        _ChatButtonWithBadge(
          unreadCount: count,
          onPressed: widget.onChat,
        ),

        if (_canShowMenu)
          PopupMenuButton<String>(
            tooltip: _text(
              context,
              ru: 'Действия',
              en: 'Actions',
            ),
            icon: Icon(
              Icons.more_vert,
              color: colorScheme.onSurfaceVariant,
            ),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  widget.onEdit(widget.project);
                  break;

                case 'delete':
                  widget.onDelete(widget.project);
                  break;
              }
            },
            itemBuilder: (_) => [
              if (_canEditProject)
                PopupMenuItem(
                  value: 'edit',
                  child: _buildPopupMenuItemContent(
                    context,
                    icon: Icons.edit_outlined,
                    text: 'common.edit'.tr(),
                  ),
                ),

              if (_canDeleteProject)
                PopupMenuItem(
                  value: 'delete',
                  child: _buildPopupMenuItemContent(
                    context,
                    icon: Icons.delete_outline,
                    text: 'common.delete'.tr(),
                    iconColor: colorScheme.error,
                    textColor: colorScheme.error,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildPopupMenuItemContent(
      BuildContext context, {
        required IconData icon,
        required String text,
        Color? iconColor,
        Color? textColor,
      }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LAST MESSAGE
  // =========================================================

  Widget _buildLastMessage(BuildContext context) {
    final theme = Theme.of(context);
    final count = _effectiveUnreadCount;

    final lastMessage = _lastMessagePreview(context);
    final lastMessageAt = widget.project.lastMessageAt;

    if (lastMessage.isEmpty) {
      return Text(
        'chat.no_messages'.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.outline,
        ),
      );
    }

    final time = lastMessageAt != null
        ? DateFormat.Hm(
      context.locale.toString(),
    ).format(lastMessageAt)
        : '';

    return Row(
      children: [
        Expanded(
          child: HighlightText(
            text: lastMessage,
            query: widget.searchQuery,
            style: TextStyle(
              fontSize: 12,
              fontWeight: count > 0
                  ? FontWeight.w700
                  : FontWeight.normal,
              color: count > 0
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        if (time.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: count > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              fontWeight: count > 0
                  ? FontWeight.w700
                  : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }

  String _lastMessagePreview(BuildContext context) {
    final message = widget.project.lastMessage?.trim() ?? '';

    if (message.isEmpty) {
      return '';
    }

    final lower = message.toLowerCase();

    if (_isImageMessage(lower)) {
      return _localizedPhoto(context);
    }

    if (_isFileMessage(lower)) {
      return _localizedFile(context);
    }

    return message;
  }

  bool _isImageMessage(String text) {
    final isImageExtension = text.endsWith('.jpg') ||
        text.endsWith('.jpeg') ||
        text.endsWith('.png') ||
        text.endsWith('.gif') ||
        text.endsWith('.webp');

    final isStorageImage = text.contains('/storage/') &&
        (text.contains('.jpg') ||
            text.contains('.jpeg') ||
            text.contains('.png') ||
            text.contains('.gif') ||
            text.contains('.webp'));

    return isImageExtension || isStorageImage;
  }

  bool _isFileMessage(String text) {
    final isKnownFile = text.endsWith('.pdf') ||
        text.endsWith('.doc') ||
        text.endsWith('.docx') ||
        text.endsWith('.ppt') ||
        text.endsWith('.pptx') ||
        text.endsWith('.xls') ||
        text.endsWith('.xlsx') ||
        text.endsWith('.txt') ||
        text.endsWith('.zip') ||
        text.endsWith('.rar');

    final isStorageUrl = text.contains('/storage/') ||
        text.contains('supabase') ||
        text.startsWith('http://') ||
        text.startsWith('https://');

    return isKnownFile || isStorageUrl;
  }

  String _localizedPhoto(BuildContext context) {
    return context.locale.languageCode == 'ru'
        ? 'Фотография'
        : 'Photo';
  }

  String _localizedFile(BuildContext context) {
    return context.locale.languageCode == 'ru'
        ? 'Файл'
        : 'File';
  }

  // =========================================================
  // PARTICIPANTS
  // =========================================================

  Widget _buildParticipants(
      BuildContext context,
      List<ProjectParticipant> participants,
      ) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          final name = _participantName(participant);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: name,
              child: _buildParticipantAvatar(
                context,
                participant,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticipantAvatar(
      BuildContext context,
      ProjectParticipant participant,
      ) {
    final theme = Theme.of(context);
    final name = _participantName(participant);
    final initials = _initials(name);

    final avatarUrl = _normalizeAvatarUrl(
      participant.avatarUrl,
    );

    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? fallback
          : Image.network(
        avatarUrl,
        key: ValueKey(avatarUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return fallback;
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return Center(
            child: SizedBox(
              width: 14,
              height: 14,
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

  String _participantName(ProjectParticipant participant) {
    final fullName = participant.fullName.trim();

    if (fullName.isNotEmpty &&
        fullName.toLowerCase() != 'unknown') {
      return fullName;
    }

    final username = participant.username?.trim();

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return '?';
  }

  String? _normalizeAvatarUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();

    const oldAvatarBucketMarker =
        '/storage/v1/object/public/avatars/';

    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      if (raw.contains(oldAvatarBucketMarker)) {
        return raw.replaceFirst(
          oldAvatarBucketMarker,
          '/storage/v1/object/public/${SupabaseService.bucket}/',
        );
      }

      return raw;
    }

    try {
      var path = raw.replaceAll('\\', '/');

      while (path.startsWith('/')) {
        path = path.substring(1);
      }

      if (path.startsWith('avatars/')) {
        path = path.substring('avatars/'.length);
      }

      if (path.startsWith('${SupabaseService.bucket}/')) {
        path = path.substring(
          '${SupabaseService.bucket}/'.length,
        );
      }

      return SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return '${parts[0].characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  // =========================================================
  // PROGRESS
  // =========================================================

  Widget _buildProgress(
      double progress,
      ColorScheme scheme,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
        ),

        const SizedBox(height: 4),

        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(
            fontSize: 11,
            color: scheme.outline,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // META
  // =========================================================

  Widget _buildMeta(
      BuildContext context,
      String deadline,
      ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'projects.deadline'.tr()}: $deadline',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          '${'projects.status'.tr()}: ${widget.project.statusEnum.localizedText()}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Widget _buildAttachments(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: widget.project.attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final attachment =
            widget.project.attachments[index];

            if (attachment.filePath.trim().isEmpty) {
              return const SizedBox.shrink();
            }

            final url = _publicUrlForAttachment(attachment.filePath);

            if (url == null) {
              return const SizedBox.shrink();
            }

            final isImage = _isImageAttachment(attachment);

            return GestureDetector(
              onTap: () async {
                await _openAttachment(url);
              },
              child: Tooltip(
                message: attachment.fileName,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isImage
                        ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return _AttachmentIcon(
                          mimeType: attachment.mimeType,
                        );
                      },
                    )
                        : _AttachmentIcon(
                      mimeType: attachment.mimeType,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _publicUrlForAttachment(String rawPath) {
    final raw = rawPath.trim();

    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    try {
      var path = raw.replaceAll('\\', '/');

      while (path.startsWith('/')) {
        path = path.substring(1);
      }

      if (path.startsWith('${SupabaseService.bucket}/')) {
        path = path.substring(
          '${SupabaseService.bucket}/'.length,
        );
      }

      return SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  bool _isImageAttachment(Attachment attachment) {
    final mime = attachment.mimeType.toLowerCase().trim();
    final name = attachment.fileName.toLowerCase().trim();
    final path = attachment.filePath.toLowerCase().trim();

    if (mime.contains('image')) {
      return true;
    }

    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      SnackbarManager.showError(
        'chat.file_open_error'.tr(),
      );
      return;
    }

    try {
      final canOpen = await canLaunchUrl(uri);

      if (!canOpen) {
        SnackbarManager.showError(
          'chat.file_open_error'.tr(),
        );
        return;
      }

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      SnackbarManager.showError(
        'chat.file_open_error'.tr(),
      );
    }
  }
}

// =========================================================
// NOTIFICATION BUTTON
// =========================================================

class _NotificationButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _NotificationButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurfaceVariant;

    return IconButton(
      tooltip: enabled
          ? context.locale.languageCode == 'ru'
          ? 'Уведомления включены'
          : 'Notifications enabled'
          : context.locale.languageCode == 'ru'
          ? 'Уведомления отключены'
          : 'Notifications disabled',
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: iconColor,
        ),
      )
          : Icon(
        enabled
            ? Icons.notifications_none_outlined
            : Icons.notifications_off_outlined,
        color: iconColor,
      ),
    );
  }
}

// =========================================================
// CHAT BUTTON + UNREAD BADGE
// =========================================================

class _ChatButtonWithBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onPressed;

  const _ChatButtonWithBadge({
    required this.unreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.chat_bubble_outline,
            color: colorScheme.onSurfaceVariant,
          ),
          tooltip: 'chat.title'.tr(),
          onPressed: onPressed,
        ),

        if (unreadCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99
                    ? '99+'
                    : unreadCount.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =========================================================
// ATTACHMENT ICON
// =========================================================

class _AttachmentIcon extends StatelessWidget {
  final String mimeType;

  const _AttachmentIcon({
    required this.mimeType,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        ProjectUIUtils.getFileIcon(mimeType),
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}