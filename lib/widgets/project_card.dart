import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../utils/project_ui_utils.dart';
import 'highlight_text.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final Function(ProjectModel) onEdit;
  final Function(ProjectModel) onDelete;
  final VoidCallback? onChat;
  final bool canEdit;
  final bool isOwner;
  final String searchQuery;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.isOwner,
    required this.searchQuery,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final progress = project.progress.clamp(
      0.0,
      1.0,
    );

    final participants = project.participantsData
        .map(
          (p) => p.fullName.trim(),
    )
        .where(
          (name) => name.isNotEmpty,
    )
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onEdit(project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildHeader(context),

              const SizedBox(height: 8),

              _buildLastMessage(context),

              const SizedBox(height: 10),

              if (project.totalTasks > 0)
                _buildProgress(
                  progress,
                  colorScheme,
                ),

              if (participants.isNotEmpty)
                const SizedBox(height: 8),

              if (participants.isNotEmpty)
                _buildParticipants(participants),

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

  Widget _buildHeader(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),

        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
              ),
              tooltip: 'chat.title'.tr(),
              onPressed: onChat,
            ),

            if (project.unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration:
                  BoxDecoration(
                    color: colorScheme.error,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  constraints:
                  const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    project.unreadCount > 99
                        ? '99+'
                        : project.unreadCount
                        .toString(),
                    style:
                    TextStyle(
                      color: colorScheme
                          .onError,
                      fontSize: 10,
                      fontWeight:
                      FontWeight.bold,
                    ),
                    textAlign:
                    TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        if (canEdit || isOwner)
          PopupMenuButton<String>(
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
                  'projects.open'.tr(),
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

  Widget _buildLastMessage(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    final lastMessage =
        project.lastMessage?.trim() ?? '';

    final lastMessageAt =
        project.lastMessageAt;

    if (lastMessage.isEmpty) {
      return Text(
        'chat.no_messages'.tr(),
        style: TextStyle(
          fontSize: 12,
          color:
          theme.colorScheme.outline,
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
              fontWeight:
              project.unreadCount > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),

        if (time.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: theme
                  .colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // PARTICIPANTS
  // =========================================================

  Widget _buildParticipants(
      List<String> participants,
      ) {
    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection:
        Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (_, i) {
          final name =
          participants[i];

          final initials =
          name.isNotEmpty
              ? name[0]
              .toUpperCase()
              : '?';

          return Padding(
            padding:
            const EdgeInsets.only(
              right: 6,
            ),
            child: Tooltip(
              message: name,
              child: CircleAvatar(
                radius: 12,
                child: Text(
                  initials,
                  style:
                  const TextStyle(
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

  // =========================================================
  // PROGRESS
  // =========================================================

  Widget _buildProgress(
      double progress,
      ColorScheme scheme,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius:
          BorderRadius.circular(6),
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
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          '${'projects.deadline'.tr()}: $deadline',
        ),
        Text(
          '${'projects.status'.tr()}: ${project.statusEnum.localizedText()}',
        ),
      ],
    );
  }

  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Widget _buildAttachments(
      BuildContext context,
      ) {
    final client =
        SupabaseService.client;

    return Padding(
      padding:
      const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection:
          Axis.horizontal,
          physics:
          const BouncingScrollPhysics(),
          itemCount:
          project.attachments.length,
          separatorBuilder:
              (_, __) =>
          const SizedBox(
            width: 8,
          ),
          itemBuilder: (_, index) {
            final att =
            project.attachments[index];

            if (att.filePath
                .trim()
                .isEmpty) {
              return const SizedBox
                  .shrink();
            }

            final url = client.storage
                .from(
              SupabaseService.bucket,
            )
                .getPublicUrl(
              att.filePath,
            );

            final mime =
            att.mimeType
                .toLowerCase();

            final isImage =
                mime.contains(
                  'image',
                ) ||
                    mime.contains(
                      'png',
                    ) ||
                    mime.contains(
                      'jpg',
                    ) ||
                    mime.contains(
                      'jpeg',
                    ) ||
                    mime.contains(
                      'gif',
                    ) ||
                    mime.contains(
                      'webp',
                    );

            return GestureDetector(
              onTap: () async {
                final uri =
                Uri.tryParse(url);

                if (uri == null) {
                  return;
                }

                await launchUrl(
                  uri,
                  mode: LaunchMode
                      .externalApplication,
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  child: isImage
                      ? Image.network(
                    url,
                    fit:
                    BoxFit.cover,
                    errorBuilder:
                        (
                        _,
                        __,
                        ___,
                        ) {
                      return Icon(
                        ProjectUIUtils
                            .getFileIcon(
                          att.mimeType,
                        ),
                        size: 20,
                      );
                    },
                  )
                      : Icon(
                    ProjectUIUtils
                        .getFileIcon(
                      att.mimeType,
                    ),
                    size: 20,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}