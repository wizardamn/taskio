import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project_model.dart';

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

    if (name.isNotEmpty && name != 'Unknown') {
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

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              colorScheme,
              textTheme,
            ),

            const SizedBox(height: 12),

            if (participants.isEmpty)
              _buildEmptyState(
                context,
                colorScheme,
                textTheme,
              )
            else
              ...participants.map(
                    (participant) => _buildParticipantTile(
                  context,
                  participant,
                ),
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
        CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.people,
            color: colorScheme.primary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'members.title'.tr(),
                style: textTheme.titleMedium,
              ),

              const SizedBox(height: 2),

              Text(
                '${participants.length}',
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
            icon: const Icon(Icons.edit),
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
    return Text(
      'members.no_participants'.tr(),
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                    Text(
                      roleText,
                      style: textTheme.bodySmall?.copyWith(
                        color: isProjectOwner
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isProjectOwner
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
      ProjectParticipant participant,
      ColorScheme colorScheme,
      bool isProjectOwner,
      ) {
    final avatarUrl = participant.avatarUrl?.trim();

    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: isProjectOwner
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: isProjectOwner
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      child: Text(
        _initials(participant),
        style: TextStyle(
          color: isProjectOwner
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}