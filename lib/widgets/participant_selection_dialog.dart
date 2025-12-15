import 'package:flutter/material.dart';

class ParticipantSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final List<String> currentParticipantIds;
  final String ownerId;

  const ParticipantSelectionDialog({
    super.key,
    required this.allUsers,
    required this.currentParticipantIds,
    required this.ownerId,
  });

  @override
  State<ParticipantSelectionDialog> createState() => _ParticipantSelectionDialogState();
}

class _ParticipantSelectionDialogState extends State<ParticipantSelectionDialog> {
  late Set<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = widget.currentParticipantIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    // Формируем список для отображения (Владелец + остальные)
    final List<Map<String, dynamic>> usersForSelection = [
      // Плейсхолдер владельца, если его нет в списке
      if (widget.ownerId.isNotEmpty)
        widget.allUsers.firstWhereOrNull((u) => u['id'] == widget.ownerId) ??
            {'id': widget.ownerId, 'full_name': 'Я (Владелец)'},
      // Остальные пользователи
      ...widget.allUsers.where((u) => u['id'] != widget.ownerId),
    ].toSet().toList();

    return AlertDialog(
      title: const Text("Выбор участников"),
      content: SizedBox(
        width: 300,
        height: 400,
        child: ListView(
          children: usersForSelection.map((u) {
            final String id = u['id'] as String;
            final isOwner = widget.ownerId == id;
            final String displayName = (u['full_name'] as String?) ?? id;

            // Владелец всегда выбран
            if (isOwner && !_tempSelected.contains(id)) {
              _tempSelected.add(id);
            }

            return CheckboxListTile(
              title: Text(displayName),
              value: _tempSelected.contains(id),
              onChanged: isOwner
                  ? null
                  : (v) {
                setState(() {
                  if (v == true) {
                    _tempSelected.add(id);
                  } else {
                    _tempSelected.remove(id);
                  }
                });
              },
              subtitle: isOwner
                  ? Text("Владелец",
                  style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold))
                  : null,
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Отмена"),
        ),
        ElevatedButton(
          onPressed: () {
            // Возвращаем список выбранных ID
            Navigator.pop(context, _tempSelected.toList());
          },
          child: const Text("Готово"),
        ),
      ],
    );
  }
}

// Приватное расширение, работает только в этом файле
extension _ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}