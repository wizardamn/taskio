import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart';

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

  final TextEditingController _searchController = TextEditingController();

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
      final id = participant.id.trim();

      if (id.isEmpty) {
        continue;
      }

      _selectedIds.add(id);
      _selectedRoles[id] = participant.role;
    }

    final ownerId = widget.ownerId.trim();

    if (ownerId.isNotEmpty) {
      _selectedIds.add(ownerId);
      _selectedRoles[ownerId] = ProjectRole.owner;
    }

    for (final id in _selectedIds) {
      _selectedRoles.putIfAbsent(
        id,
            () => id == ownerId ? ProjectRole.owner : ProjectRole.editor,
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
      final firstName = _getString(user, 'first_name').toLowerCase();
      final lastName = _getString(user, 'last_name').toLowerCase();
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
  // AVATAR
  // =========================================================

  String? _normalizeAvatarUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();

    const oldAvatarBucketMarker = '/storage/v1/object/public/avatars/';

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
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final filteredUsers = _filteredUsers;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      title: Text(
        'project.select_participants'.tr(),
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        0,
      ),
      content: SizedBox(
        width: double.maxFinite,
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
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: filteredUsers.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 8);
                },
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
      actionsPadding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        12,
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
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(
            Icons.check,
            size: 18,
          ),
          label: Text(
            'common.done'.tr(),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final colorScheme = Theme.of(context).colorScheme;

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
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.2,
          ),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildSelectedInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final selectedCount = _selectedIds.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${'common.selected'.tr()}: $selectedCount',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 42,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'members.empty'.tr(),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

    final selectedRole =
        _selectedRoles[id] ?? (isOwner ? ProjectRole.owner : ProjectRole.editor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.32)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.55)
              : colorScheme.outlineVariant,
          width: isSelected ? 1.1 : 0.7,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOwner
            ? null
            : () {
          _toggleSelected(id);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            10,
            10,
            12,
            10,
          ),
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
              const SizedBox(width: 4),
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
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (username.isNotEmpty)
                          _buildUsernameLabel(
                            context,
                            username: username,
                          ),
                        if (globalRole.isNotEmpty)
                          _buildSmallChip(
                            context,
                            text: _globalRoleText(globalRole),
                            isPrimary: false,
                          ),
                        if (isOwner)
                          _buildSmallChip(
                            context,
                            text: 'project_roles.owner'.tr(),
                            isPrimary: true,
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

  Widget _buildUsernameLabel(
      BuildContext context, {
        required String username,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 170,
      ),
      child: Text(
        '@$username',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSmallChip(
      BuildContext context, {
        required String text,
        required bool isPrimary,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isPrimary
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelSmall?.copyWith(
          color: isPrimary
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
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

    final normalizedAvatarUrl = _normalizeAvatarUrl(avatarUrl);

    final backgroundColor =
    isOwner ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest;

    final foregroundColor =
    isOwner ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;

    final fallback = Center(
      child: Text(
        _getInitials(fullName),
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isOwner
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
          width: isOwner ? 1.2 : 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedAvatarUrl == null
          ? fallback
          : Image.network(
        normalizedAvatarUrl,
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

  Widget _buildRoleSelector(
      BuildContext context, {
        required String id,
        required bool isOwner,
        required ProjectRole role,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isOwner) {
      return SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'project_roles.owner'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final roles = <ProjectRole>[
      ProjectRole.editor,
      ProjectRole.viewer,
    ];

    final safeRole = roles.contains(role) ? role : ProjectRole.editor;

    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<ProjectRole>(
        initialValue: safeRole,
        isExpanded: true,
        isDense: true,
        menuMaxHeight: 260,
        decoration: InputDecoration(
          labelText: 'members.role'.tr(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        selectedItemBuilder: (context) {
          return roles.map((role) {
            return _buildSelectedRoleItem(
              context,
              role,
            );
          }).toList();
        },
        items: roles.map((role) {
          return DropdownMenuItem<ProjectRole>(
            value: role,
            child: _buildRoleMenuItem(
              context,
              role,
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }

          setState(() {
            _selectedRoles[id] = value;
          });
        },
      ),
    );
  }

  Widget _buildSelectedRoleItem(
      BuildContext context,
      ProjectRole role,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          _roleIcon(role),
          size: 17,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _projectRoleText(role),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleMenuItem(
      BuildContext context,
      ProjectRole role,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _roleIcon(role),
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _projectRoleText(role),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
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

      return a.fullName.toLowerCase().compareTo(
        b.fullName.toLowerCase(),
      );
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
      final id = participant.id.trim();

      if (id.isEmpty) {
        continue;
      }

      uniqueUsers.putIfAbsent(
        id,
            () => {
          'id': id,
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

    final username = _getUsername(user);
    final avatarUrl = _getString(user, 'avatar_url');

    return ProjectParticipant(
      id: id,
      fullName: _getDisplayName(user),
      username: username.isEmpty ? null : username,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      role: role,
    );
  }

  String _getDisplayName(
      Map<String, dynamic> user,
      ) {
    final fullName = _getString(user, 'full_name');

    if (fullName.isNotEmpty && fullName.toLowerCase() != 'unknown') {
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

  IconData _roleIcon(ProjectRole role) {
    switch (role) {
      case ProjectRole.owner:
        return Icons.verified_user_outlined;

      case ProjectRole.editor:
        return Icons.edit_outlined;

      case ProjectRole.viewer:
        return Icons.visibility_outlined;
    }
  }

  String _projectRoleText(ProjectRole role) {
    switch (role) {
      case ProjectRole.owner:
        return 'project_roles.owner'.tr();

      case ProjectRole.editor:
        return 'project_roles.editor'.tr();

      case ProjectRole.viewer:
        return 'project_roles.viewer'.tr();
    }
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