import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.people),
      title: const Text("Участники команды"),
      subtitle: Text(participantNames.isEmpty ? "Никто не выбран" : participantNames.join(', ')),
      trailing: isOwner
          ? ElevatedButton.icon(
        icon: const Icon(Icons.edit, size: 18),
        label: const Text("Изменить"),
        onPressed: onEdit,
      )
          : null,
    ).animate().fadeIn(delay: 300.ms);
  }
}