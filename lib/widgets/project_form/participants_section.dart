import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

class ParticipantsSection extends StatelessWidget {
  final List<String> participantNames;
  final bool isOwner;
  final VoidCallback onEdit;

  const ParticipantsSection({
    super.key,
    required this.participantNames,
    required this.isOwner,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final subtitleText = participantNames.isEmpty
        ? 'users.no_name'.tr()
        : participantNames.join(', ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.people,
        color: colorScheme.primary,
      ),
      title: Text(
        'members.title'.tr(),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitleText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isOwner
          ? TextButton.icon(
        icon: const Icon(Icons.edit, size: 18),
        label: Text('common.edit'.tr()),
        onPressed: onEdit,
      )
          : null,
    )
        .animate()
        .fadeIn(delay: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}