import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../utils/project_ui_utils.dart';
import 'highlight_text.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;

  /// Используется как открытие карточки проекта.
  /// Даже viewer должен иметь возможность открыть карточку.
  final Function(ProjectModel) onEdit;

  final Function(ProjectModel) onDelete;
  final VoidCallback? onChat;

  /// Право менять настройки проекта.
  /// Viewer может открыть карточку, но не должен видеть меню редактирования.
  final bool canEdit;

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

  int get _effectiveUnreadCount {
    return unreadCount ?? project.unreadCount;
  }

  bool get _canShowMenu {
    return canEdit || isOwner;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final progress = project.progress.clamp(
      0.0,
      1.0,
    );

    final participants = project.participantsData
        .map((participant) => participant.fullName.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final deadline = DateFormat.yMMMd(
      context.locale.toString(),
    ).format(project.deadline);

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
          onEdit(project);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),

              const SizedBox(height: 8),

              _buildLastMessage(context),

              if (project.totalTasks > 0) ...[
                const SizedBox(height: 10),
                _buildProgress(
                  progress,
                  colorScheme,
                ),
              ],

              if (participants.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildParticipants(participants),
              ],

              const SizedBox(height: 8),

              _buildMeta(
                context,
                deadline,
              ),

              if (project.attachments.isNotEmpty)
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
            color: project.colorObj,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: HighlightText(
            text: project.title,
            query: searchQuery,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight:
              count > 0 ? FontWeight.w800 : FontWeight.bold,
            ),
          ),
        ),

        _ChatButtonWithBadge(
          unreadCount: count,
          onPressed: onChat,
        ),

        if (_canShowMenu)
          PopupMenuButton<String>(
            tooltip: 'common.open'.tr(),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit(project);
                  break;

                case 'delete':
                  onDelete(project);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(
                  'common.edit'.tr(),
                ),
              ),
              if (isOwner)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'common.delete'.tr(),
                    style: TextStyle(
                      color: colorScheme.error,
                    ),
                  ),
                ),
            ],
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
    final lastMessageAt = project.lastMessageAt;

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
            query: searchQuery,
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
    final message = project.lastMessage?.trim() ?? '';

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

  Widget _buildParticipants(List<String> participants) {
    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (_, index) {
          final name = participants[index];
          final initials = _initials(name);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: name,
              child: CircleAvatar(
                radius: 12,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
          '${'projects.status'.tr()}: ${project.statusEnum.localizedText()}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Widget _buildAttachments(BuildContext context) {
    final client = SupabaseService.client;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: project.attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final attachment = project.attachments[index];

            if (attachment.filePath.trim().isEmpty) {
              return const SizedBox.shrink();
            }

            final url = client.storage
                .from(SupabaseService.bucket)
                .getPublicUrl(attachment.filePath);

            final isImage = _isImageAttachment(
              attachment.mimeType,
            );

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
                      color:
                      Theme.of(context).colorScheme.outlineVariant,
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

  bool _isImageAttachment(String mimeType) {
    final mime = mimeType.toLowerCase();

    return mime.contains('image') ||
        mime.contains('png') ||
        mime.contains('jpg') ||
        mime.contains('jpeg') ||
        mime.contains('gif') ||
        mime.contains('webp');
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    if (!await canLaunchUrl(uri)) {
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
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
          icon: const Icon(
            Icons.chat_bubble_outline,
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
                unreadCount > 99 ? '99+' : unreadCount.toString(),
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