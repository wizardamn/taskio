import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project_model.dart';
import '../../services/supabase_service.dart';

class ParticipantsSection extends StatelessWidget {
  final List<ProjectParticipant> participants;
  final bool isOwner;
  final VoidCallback onEdit;

  const ParticipantsSection({
    super.key,
    required this.participants,
    required this.isOwner,
    required this.onEdit,
  });

  // =========================================================
  // HELPERS
  // =========================================================

  String _displayName(ProjectParticipant participant) {
    final name = participant.fullName.trim();

    if (name.isNotEmpty && name.toLowerCase() != 'unknown') {
      return name;
    }

    final username = _username(participant);

    if (username.isNotEmpty) {
      return '@$username';
    }

    return 'users.no_name'.tr();
  }

  String _username(ProjectParticipant participant) {
    final username = participant.username?.trim() ?? '';

    if (username.startsWith('@')) {
      return username.substring(1);
    }

    return username;
  }

  String _initials(ProjectParticipant participant) {
    final name = _displayName(participant)
        .replaceAll('@', '')
        .trim();

    if (name.isEmpty) {
      return '?';
    }

    final parts = name
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

  String _roleText(ProjectRole role) {
    switch (role) {
      case ProjectRole.owner:
        return 'project_roles.owner'.tr();

      case ProjectRole.editor:
        return 'project_roles.editor'.tr();

      case ProjectRole.viewer:
        return 'project_roles.viewer'.tr();
    }
  }

  String _participantsCountText(BuildContext context) {
    final count = participants.length;

    if (context.locale.languageCode != 'ru') {
      return count == 1 ? '1 member' : '$count members';
    }

    if (count == 1) {
      return '1 участник';
    }

    if (count >= 2 && count <= 4) {
      return '$count участника';
    }

    return '$count участников';
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

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: 0.7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 14),
            if (participants.isEmpty)
              _buildEmptyState(
                context,
                colorScheme,
                textTheme,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: participants.length,
                separatorBuilder: (_, __) {
                  return Divider(
                    height: 14,
                    thickness: 0.4,
                    color: colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  return _buildParticipantTile(
                    context,
                    participants[index],
                  );
                },
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildHeader(
      BuildContext context,
      ColorScheme colorScheme,
      TextTheme textTheme,
      ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.people_alt_outlined,
            color: colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'members.title'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _participantsCountText(context),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (isOwner)
          IconButton(
            tooltip: 'common.edit'.tr(),
            icon: const Icon(
              Icons.edit_outlined,
            ),
            color: colorScheme.onSurfaceVariant,
            onPressed: onEdit,
          ),
      ],
    );
  }

  Widget _buildEmptyState(
      BuildContext context,
      ColorScheme colorScheme,
      TextTheme textTheme,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_add_disabled_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'members.no_participants'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(
      BuildContext context,
      ProjectParticipant participant,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = _displayName(participant);
    final username = _username(participant);
    final roleText = _roleText(participant.role);

    final isProjectOwner = participant.role == ProjectRole.owner;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatar(
          participant,
          colorScheme,
          isProjectOwner,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  _buildRoleChip(
                    context,
                    roleText: roleText,
                    isProjectOwner: isProjectOwner,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(
      BuildContext context, {
        required String roleText,
        required bool isProjectOwner,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isProjectOwner
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleText,
        style: textTheme.labelSmall?.copyWith(
          color: isProjectOwner
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: isProjectOwner
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAvatar(
      ProjectParticipant participant,
      ColorScheme colorScheme,
      bool isProjectOwner,
      ) {
    final avatarUrl = _normalizeAvatarUrl(
      participant.avatarUrl,
    );

    final backgroundColor = isProjectOwner
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    final foregroundColor = isProjectOwner
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    final fallback = Center(
      child: Text(
        _initials(participant),
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isProjectOwner
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
          width: isProjectOwner ? 1.2 : 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? fallback
          : Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return fallback;
        },
        loadingBuilder: (
            context,
            child,
            progress,
            ) {
          if (progress == null) {
            return child;
          }

          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}