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
  late final Set<String> _tempSelected;
  late final List<Map<String, dynamic>> _usersForSelection;

  @override
  void initState() {
    super.initState();

    _tempSelected = widget.currentParticipantIds.toSet();

    /// владелец всегда участник
    if (widget.ownerId.trim().isNotEmpty) {
      _tempSelected.add(widget.ownerId);
    }

    _usersForSelection = _buildUsersList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screen = MediaQuery.of(context).size;

    return AlertDialog(
      title: Text(
        'project.select_participants'.tr(),
      ),
      content: SizedBox(
        width: screen.width > 600
            ? 420
            : screen.width * 0.9,
        height: screen.height > 800
            ? 500
            : screen.height * 0.65,
        child: _usersForSelection.isEmpty
            ? Center(
          child: Text(
            'common.no_data'.tr(),
          ),
        )
            : ListView.builder(
          itemCount: _usersForSelection.length,
          itemBuilder: (_, index) {
            final user = _usersForSelection[index];

            final id = user['id'].toString();
            final isOwner = id == widget.ownerId;

            final displayName =
            _getDisplayName(user);

            return CheckboxListTile(
              value: _tempSelected.contains(id),
              controlAffinity:
              ListTileControlAffinity.leading,
              onChanged: isOwner
                  ? null
                  : (value) {
                setState(() {
                  if (value == true) {
                    _tempSelected.add(id);
                  } else {
                    _tempSelected.remove(id);
                  }
                });
              },
              title: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: isOwner
                  ? Text(
                'project.owner'.tr(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'common.cancel'.tr(),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.ownerId.trim().isNotEmpty) {
              _tempSelected.add(widget.ownerId);
            }

            Navigator.pop(
              context,
              _tempSelected.toList(),
            );
          },
          child: Text(
            'common.done'.tr(),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  List<Map<String, dynamic>> _buildUsersList() {
    final Map<String, Map<String, dynamic>> uniqueUsers = {};

    for (final user in widget.allUsers) {
      final rawId = user['id'];

      if (rawId == null) {
        continue;
      }

      final id = rawId.toString().trim();

      if (id.isEmpty) {
        continue;
      }

      uniqueUsers[id] = {
        'id': id,
        'full_name': user['full_name'],
        'first_name': user['first_name'],
        'last_name': user['last_name'],
        'username': user['username'],
        'role': user['role'],
      };
    }

    /// если owner отсутствует в списке
    if (widget.ownerId.trim().isNotEmpty &&
        !uniqueUsers.containsKey(widget.ownerId)) {
      uniqueUsers[widget.ownerId] = {
        'id': widget.ownerId,
        'full_name': 'project.me_owner'.tr(),
      };
    }

    final list = uniqueUsers.values.toList();

    list.sort((a, b) {
      final idA = a['id'].toString();
      final idB = b['id'].toString();

      /// владелец сверху
      if (idA == widget.ownerId) {
        return -1;
      }

      if (idB == widget.ownerId) {
        return 1;
      }

      final nameA =
      _getDisplayName(a).toLowerCase();

      final nameB =
      _getDisplayName(b).toLowerCase();

      return nameA.compareTo(nameB);
    });

    return list;
  }

  String _getDisplayName(
      Map<String, dynamic> user,
      ) {
    final fullName =
    user['full_name']?.toString().trim();

    if (fullName != null &&
        fullName.isNotEmpty) {
      return fullName;
    }

    final firstName =
        user['first_name']?.toString().trim() ?? '';

    final lastName =
        user['last_name']?.toString().trim() ?? '';

    final combined =
    '$firstName $lastName'.trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    final username =
    user['username']?.toString().trim();

    if (username != null &&
        username.isNotEmpty) {
      return username;
    }

    return 'common.user'.tr();
  }
}