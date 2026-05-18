import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';

class ParticipantSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final List<String> currentParticipantIds;
  final List<ProjectParticipant> currentParticipants;
  final String ownerId;

  const ParticipantSelectionDialog({
    super.key,
    required this.allUsers,
    required this.currentParticipantIds,
    required this.ownerId,
    this.currentParticipants = const [],
  });

  @override
  State<ParticipantSelectionDialog> createState() =>
      _ParticipantSelectionDialogState();
}

class _ParticipantSelectionDialogState
    extends State<ParticipantSelectionDialog> {
  late final Set<String> _selectedIds;
  late final Map<String, ProjectRole> _selectedRoles;
  late final List<Map<String, dynamic>> _usersForSelection;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _selectedIds = widget.currentParticipantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    _selectedRoles = {};

    for (final participant in widget.currentParticipants) {
      if (participant.id.trim().isEmpty) {
        continue;
      }

      _selectedIds.add(participant.id);
      _selectedRoles[participant.id] = participant.role;
    }

    if (widget.ownerId.trim().isNotEmpty) {
      _selectedIds.add(widget.ownerId);
      _selectedRoles[widget.ownerId] = ProjectRole.owner;
    }

    for (final id in _selectedIds) {
      _selectedRoles.putIfAbsent(
        id,
            () => id == widget.ownerId
            ? ProjectRole.owner
            : ProjectRole.editor,
      );
    }

    _usersForSelection = _buildUsersList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // FILTER
  // =========================================================

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _usersForSelection;
    }

    return _usersForSelection.where((user) {
      final id = _getString(user, 'id').toLowerCase();
      final fullName = _getDisplayName(user).toLowerCase();
      final firstName =
      _getString(user, 'first_name').toLowerCase();
      final lastName =
      _getString(user, 'last_name').toLowerCase();
      final username = _getUsername(user).toLowerCase();
      final email = _getString(user, 'email').toLowerCase();

      return id.contains(query) ||
          fullName.contains(query) ||
          firstName.contains(query) ||
          lastName.contains(query) ||
          username.contains(query) ||
          email.contains(query);
    }).toList();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final filteredUsers = _filteredUsers;

    return AlertDialog(
      title: Text(
        'project.select_participants'.tr(),
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        0,
      ),
      content: SizedBox(
        width: screen.width > 600 ? 500 : screen.width * 0.92,
        height: screen.height > 800 ? 620 : screen.height * 0.76,
        child: Column(
          children: [
            _buildSearchField(),

            const SizedBox(height: 12),

            _buildSelectedInfo(),

            const SizedBox(height: 12),

            Expanded(
              child: filteredUsers.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                itemCount: filteredUsers.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildUserTile(
                    context,
                    filteredUsers[index],
                  );
                },
              ),
            ),
          ],
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
        FilledButton(
          onPressed: _submit,
          child: Text(
            'common.done'.tr(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'members.search_hint'.tr(),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
          tooltip: 'common.clear'.tr(),
          icon: const Icon(Icons.close),
          onPressed: () {
            _searchController.clear();

            setState(() {
              _searchQuery = '';
            });
          },
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildSelectedInfo() {
    final selectedCount = _selectedIds.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '${'members.title'.tr()}: $selectedCount',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'members.empty'.tr(),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildUserTile(
      BuildContext context,
      Map<String, dynamic> user,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final id = _getString(user, 'id');

    if (id.isEmpty) {
      return const SizedBox.shrink();
    }

    final isOwner = id == widget.ownerId;
    final isSelected = _selectedIds.contains(id);

    final fullName = _getDisplayName(user);
    final username = _getUsername(user);
    final avatarUrl = _getString(user, 'avatar_url');
    final globalRole = _getString(user, 'role');

    final selectedRole = _selectedRoles[id] ??
        (isOwner ? ProjectRole.owner : ProjectRole.editor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.55)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isOwner
            ? null
            : () {
          _toggleSelected(id);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: isOwner
                    ? null
                    : (_) {
                  _toggleSelected(id);
                },
              ),

              const SizedBox(width: 6),

              _buildAvatar(
                context,
                fullName: fullName,
                avatarUrl: avatarUrl,
                isOwner: isOwner,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected || isOwner
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (username.isNotEmpty)
                          Text(
                            '@$username',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),

                        if (globalRole.isNotEmpty)
                          Text(
                            _globalRoleText(globalRole),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),

                        if (isOwner)
                          Text(
                            'project_roles.owner'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),

                    if (isSelected) ...[
                      const SizedBox(height: 10),
                      _buildRoleSelector(
                        context,
                        id: id,
                        isOwner: isOwner,
                        role: selectedRole,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
      BuildContext context, {
        required String fullName,
        required String avatarUrl,
        required bool isOwner,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: isOwner
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: isOwner
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      child: Text(
        _getInitials(fullName),
        style: TextStyle(
          color: isOwner
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleSelector(
      BuildContext context, {
        required String id,
        required bool isOwner,
        required ProjectRole role,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isOwner) {
      return Row(
        children: [
          Icon(
            Icons.verified_user,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'project_roles.owner'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<ProjectRole>(
      initialValue:
      role == ProjectRole.owner ? ProjectRole.editor : role,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'members.role'.tr(),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: [
        DropdownMenuItem(
          value: ProjectRole.editor,
          child: Text(
            'project_roles.editor'.tr(),
          ),
        ),
        DropdownMenuItem(
          value: ProjectRole.viewer,
          child: Text(
            'project_roles.viewer'.tr(),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedRoles[id] = value;
        });
      },
    );
  }

  // =========================================================
  // ACTIONS
  // =========================================================

  void _toggleSelected(String id) {
    if (id == widget.ownerId) {
      return;
    }

    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedRoles.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedRoles[id] = ProjectRole.editor;
      }
    });
  }

  void _submit() {
    final ownerId = widget.ownerId.trim();

    if (ownerId.isNotEmpty) {
      _selectedIds.add(ownerId);
      _selectedRoles[ownerId] = ProjectRole.owner;
    }

    final result = _selectedIds
        .map(_participantById)
        .whereType<ProjectParticipant>()
        .toList();

    result.sort((a, b) {
      if (a.id == ownerId) {
        return -1;
      }

      if (b.id == ownerId) {
        return 1;
      }

      return a.fullName
          .toLowerCase()
          .compareTo(b.fullName.toLowerCase());
    });

    Navigator.pop<List<ProjectParticipant>>(
      context,
      result,
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  List<Map<String, dynamic>> _buildUsersList() {
    final uniqueUsers = <String, Map<String, dynamic>>{};

    for (final user in widget.allUsers) {
      final id = _getString(user, 'id');

      if (id.isEmpty) {
        continue;
      }

      uniqueUsers[id] = {
        'id': id,
        'full_name': user['full_name'],
        'first_name': user['first_name'],
        'last_name': user['last_name'],
        'username': user['username'],
        'email': user['email'],
        'avatar_url': user['avatar_url'],
        'role': user['role'],
      };
    }

    for (final participant in widget.currentParticipants) {
      if (participant.id.trim().isEmpty) {
        continue;
      }

      uniqueUsers.putIfAbsent(
        participant.id,
            () => {
          'id': participant.id,
          'full_name': participant.fullName,
          'username': participant.username,
          'avatar_url': participant.avatarUrl,
          'role': participant.role.value,
        },
      );
    }

    final ownerId = widget.ownerId.trim();

    if (ownerId.isNotEmpty && !uniqueUsers.containsKey(ownerId)) {
      uniqueUsers[ownerId] = {
        'id': ownerId,
        'full_name': 'project.owner'.tr(),
        'username': '',
        'avatar_url': null,
        'role': ProjectRole.owner.value,
      };
    }

    final list = uniqueUsers.values.toList();

    list.sort((a, b) {
      final idA = _getString(a, 'id');
      final idB = _getString(b, 'id');

      if (idA == ownerId) {
        return -1;
      }

      if (idB == ownerId) {
        return 1;
      }

      final nameA = _getDisplayName(a).toLowerCase();
      final nameB = _getDisplayName(b).toLowerCase();

      return nameA.compareTo(nameB);
    });

    return list;
  }

  ProjectParticipant? _participantById(String id) {
    final user = _usersForSelection.firstWhere(
          (item) => _getString(item, 'id') == id,
      orElse: () => const {},
    );

    if (user.isEmpty) {
      return null;
    }

    final role = id == widget.ownerId
        ? ProjectRole.owner
        : _selectedRoles[id] ?? ProjectRole.editor;

    return ProjectParticipant(
      id: id,
      fullName: _getDisplayName(user),
      username: _getUsername(user).isEmpty
          ? null
          : _getUsername(user),
      avatarUrl: _getString(user, 'avatar_url').isEmpty
          ? null
          : _getString(user, 'avatar_url'),
      role: role,
    );
  }

  String _getDisplayName(
      Map<String, dynamic> user,
      ) {
    final fullName = _getString(user, 'full_name');

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final firstName = _getString(user, 'first_name');
    final lastName = _getString(user, 'last_name');

    final combined = '$firstName $lastName'.trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    final username = _getUsername(user);

    if (username.isNotEmpty) {
      return '@$username';
    }

    return 'users.no_name'.tr();
  }

  String _getUsername(
      Map<String, dynamic> user,
      ) {
    final username = _getString(user, 'username');

    if (username.startsWith('@')) {
      return username.substring(1);
    }

    return username;
  }

  String _getInitials(String name) {
    final prepared = name.replaceAll('@', '').trim();

    final parts = prepared
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

  String _getString(
      Map<String, dynamic> user,
      String key,
      ) {
    return user[key]?.toString().trim() ?? '';
  }

  String _globalRoleText(String role) {
    final normalized = role.trim().toLowerCase();

    if (normalized.isEmpty) {
      return '';
    }

    switch (normalized) {
      case 'owner':
        return 'project_roles.owner'.tr();

      case 'editor':
        return 'project_roles.editor'.tr();

      case 'viewer':
        return 'project_roles.viewer'.tr();

      case 'student':
        return 'roles.student'.tr();

      case 'teacher':
        return 'roles.teacher'.tr();

      case 'leader':
        return 'roles.leader'.tr();

      case 'general':
        return 'roles.general'.tr();

      default:
        return role;
    }
  }
}