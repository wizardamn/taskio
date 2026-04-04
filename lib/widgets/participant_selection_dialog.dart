import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
  State<ParticipantSelectionDialog> createState() =>
      _ParticipantSelectionDialogState();
}

class _ParticipantSelectionDialogState
    extends State<ParticipantSelectionDialog> {
  late Set<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected =
        widget.currentParticipantIds.toSet();

    // Владелец всегда выбран
    if (widget.ownerId.isNotEmpty) {
      _tempSelected.add(widget.ownerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final usersForSelection =
    _buildUsersList();

    return AlertDialog(
      title: Text(
        'project.select_participants'.tr(),
      ),
      content: SizedBox(
        width: 350,
        height: 400,
        child: ListView.builder(
          itemCount: usersForSelection.length,
          itemBuilder: (_, index) {
            final user =
            usersForSelection[index];

            final id =
            user['id'] as String;

            final isOwner =
                id == widget.ownerId;

            final displayName =
                (user['full_name']
                as String?) ??
                    id;

            return CheckboxListTile(
              value:
              _tempSelected.contains(id),
              onChanged: isOwner
                  ? null
                  : (value) {
                setState(() {
                  if (value == true) {
                    _tempSelected.add(id);
                  } else {
                    _tempSelected
                        .remove(id);
                  }
                });
              },
              title: Text(displayName),
              subtitle: isOwner
                  ? Text(
                'project.owner'.tr(),
                style: TextStyle(
                  color:
                  colorScheme.primary,
                  fontWeight:
                  FontWeight.bold,
                ),
              )
                  : null,
              controlAffinity:
              ListTileControlAffinity
                  .leading,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context),
          child:
          Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _tempSelected.toList(),
            );
          },
          child: Text('common.done'.tr()),
        ),
      ],
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  List<Map<String, dynamic>>
  _buildUsersList() {
    final Map<String, Map<String, dynamic>>
    uniqueUsers = {};

    for (final user in widget.allUsers) {
      final id = user['id'] as String?;
      if (id != null) {
        uniqueUsers[id] = user;
      }
    }

    // Если владельца нет в списке — добавим
    if (widget.ownerId.isNotEmpty &&
        !uniqueUsers
            .containsKey(widget.ownerId)) {
      uniqueUsers[widget.ownerId] = {
        'id': widget.ownerId,
        'full_name':
        'project.me_owner'.tr(),
      };
    }

    final list =
    uniqueUsers.values.toList();

    // Сортируем: владелец сверху, потом по имени
    list.sort((a, b) {
      if (a['id'] ==
          widget.ownerId) {
        return -1;
      }
      if (b['id'] ==
          widget.ownerId) {
        return 1;
      }

      final nameA =
      (a['full_name'] ?? '')
          .toString()
          .toLowerCase();
      final nameB =
      (b['full_name'] ?? '')
          .toString()
          .toLowerCase();

      return nameA.compareTo(nameB);
    });

    return list;
  }
}