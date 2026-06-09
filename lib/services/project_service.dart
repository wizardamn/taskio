import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/project_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class ProjectService {
  final SupabaseClient client = SupabaseService.client;

  final String bucketName = SupabaseService.bucket;

  final NotificationService _notifications = NotificationService();

  static const String _invitationsTable = 'project_invitations';

  String? _currentUserId;

  // =========================================================
  // OWNER
  // =========================================================

  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  String? get currentUserId => _currentUserId;

  // =========================================================
  // ERROR
  // =========================================================

  Never _handleError(
      Object e,
      StackTrace st,
      String operation,
      ) {
    debugPrint('[ProjectService] $operation: $e');

    Error.throwWithStackTrace(
      Exception('$operation: $e'),
      st,
    );
  }

  // =========================================================
  // ENSURE PROFILE
  // =========================================================

  Future<void> _ensureCurrentUserProfile() async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final exists = await client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (exists != null) {
        return;
      }

      final user = client.auth.currentUser;
      final email = user?.email ?? '';

      final fullName =
      user?.userMetadata?['full_name']?.toString().trim();

      final username =
      user?.userMetadata?['username']?.toString().trim();

      final avatarUrl =
      user?.userMetadata?['avatar_url']?.toString().trim();

      final fallbackName = email.contains('@')
          ? email.split('@').first
          : 'User';

      final fallbackUsername = fallbackName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');

      final data = <String, dynamic>{
        'id': userId,
        'username': username != null && username.isNotEmpty
            ? username
            : fallbackUsername,
        'full_name': fullName != null && fullName.isNotEmpty
            ? fullName
            : fallbackName,
        'role': 'student',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        data['avatar_url'] = avatarUrl;
      }

      await client.from('profiles').upsert(
        data,
        onConflict: 'id',
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'ensure profile failed',
      );
    }
  }

  // =========================================================
  // PERMISSIONS
  // =========================================================

  bool isOwner(ProjectModel project) {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return false;
    }

    return project.ownerId == userId;
  }

  bool isProjectMember(ProjectModel project) {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return false;
    }

    if (project.ownerId == userId) {
      return true;
    }

    return project.participantsData.any(
          (participant) => participant.id == userId,
    );
  }

  bool canOpenProject(ProjectModel project) {
    return isProjectMember(project);
  }

  bool canEditProject(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner ||
        role == ProjectRole.editor;
  }

  bool canManageProjectContent(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner ||
        role == ProjectRole.editor;
  }

  bool canManageMembers(ProjectModel project) {
    return isOwner(project);
  }

  bool canGradeProject(ProjectModel project) {
    return isOwner(project);
  }

  Future<bool> canEditProjectById(String projectId) async {
    final project = await getById(projectId);

    if (project == null) {
      return false;
    }

    return canEditProject(project);
  }

  ProjectRole? _currentUserRole(ProjectModel project) {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    if (project.ownerId == userId) {
      return ProjectRole.owner;
    }

    for (final participant in project.participantsData) {
      if (participant.id == userId) {
        return participant.role;
      }
    }

    return null;
  }

  // =========================================================
  // USERS FOR PARTICIPANT SELECTION
  // =========================================================

  Future<List<Map<String, dynamic>>> getUsersForSelection() async {
    try {
      final response = await client
          .from('profiles')
          .select(
        '''
            id,
            full_name,
            first_name,
            last_name,
            username,
            avatar_url,
            role
            ''',
      )
          .order('full_name', ascending: true);

      final users = List<Map<String, dynamic>>.from(response);

      users.sort((a, b) {
        final aName = _displayNameFromMap(a).toLowerCase();
        final bName = _displayNameFromMap(b).toLowerCase();

        return aName.compareTo(bName);
      });

      return users;
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load users failed',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() {
    return getUsersForSelection();
  }

  String _displayNameFromMap(Map<String, dynamic> user) {
    final fullName = user['full_name']?.toString().trim();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final firstName = user['first_name']?.toString().trim() ?? '';
    final lastName = user['last_name']?.toString().trim() ?? '';

    final combined = '$firstName $lastName'.trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    final username = user['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return 'User';
  }

  // =========================================================
  // PROFILE ENRICHMENT
  // =========================================================

  Future<List<ProjectModel>> _enrichProjectsWithProfiles(
      List<ProjectModel> projects,
      ) async {
    if (projects.isEmpty) {
      return projects;
    }

    final memberIds = <String>{};

    for (final project in projects) {
      if (project.ownerId.trim().isNotEmpty) {
        memberIds.add(project.ownerId.trim());
      }

      for (final participant in project.participantsData) {
        final id = participant.id.trim();

        if (id.isNotEmpty) {
          memberIds.add(id);
        }
      }
    }

    if (memberIds.isEmpty) {
      return projects;
    }

    try {
      final profilesRaw = await client
          .from('profiles')
          .select(
        '''
            id,
            full_name,
            username,
            avatar_url
            ''',
      )
          .inFilter(
        'id',
        memberIds.toList(),
      );

      final profiles = List<Map<String, dynamic>>.from(profilesRaw);

      final profileById = <String, Map<String, dynamic>>{};

      for (final profile in profiles) {
        final id = profile['id']?.toString();

        if (id != null && id.isNotEmpty) {
          profileById[id] = profile;
        }
      }

      return projects.map((project) {
        return _enrichProjectWithProfileMap(
          project,
          profileById,
        );
      }).toList();
    } catch (e) {
      debugPrint('[ProjectService] profile enrichment skipped: $e');
      return projects;
    }
  }

  Future<ProjectModel> _enrichProjectWithProfiles(
      ProjectModel project,
      ) async {
    final enriched = await _enrichProjectsWithProfiles([project]);

    if (enriched.isEmpty) {
      return project;
    }

    return enriched.first;
  }

  ProjectModel _enrichProjectWithProfileMap(
      ProjectModel project,
      Map<String, Map<String, dynamic>> profileById,
      ) {
    final participantsById = <String, ProjectParticipant>{};

    for (final participant in project.participantsData) {
      final id = participant.id.trim();

      if (id.isEmpty) {
        continue;
      }

      final profile = profileById[id];

      participantsById[id] = _mergeParticipantWithProfile(
        participant: participant,
        profile: profile,
      );
    }

    final ownerId = project.ownerId.trim();

    if (ownerId.isNotEmpty) {
      final existingOwner = participantsById[ownerId];
      final ownerProfile = profileById[ownerId];

      participantsById[ownerId] = _mergeParticipantWithProfile(
        participant: existingOwner ??
            ProjectParticipant(
              id: ownerId,
              fullName: _profileDisplayName(ownerProfile) ?? 'Owner',
              username: ownerProfile?['username']?.toString(),
              avatarUrl: ownerProfile?['avatar_url']?.toString(),
              role: ProjectRole.owner,
            ),
        profile: ownerProfile,
        forcedRole: ProjectRole.owner,
      );
    }

    final participants = participantsById.values.toList();

    participants.sort((a, b) {
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

    return project.copyWith(
      participantsData: participants,
    );
  }

  ProjectParticipant _mergeParticipantWithProfile({
    required ProjectParticipant participant,
    required Map<String, dynamic>? profile,
    ProjectRole? forcedRole,
  }) {
    final profileName = _profileDisplayName(profile);

    final currentName = participant.fullName.trim();

    final fullName = profileName != null && profileName.isNotEmpty
        ? profileName
        : currentName.isNotEmpty
        ? currentName
        : 'User';

    final username = profile?['username']?.toString().trim();

    final avatarUrl = profile?['avatar_url']?.toString().trim();

    return ProjectParticipant(
      id: participant.id,
      fullName: fullName,
      username: username != null && username.isNotEmpty
          ? username
          : participant.username,
      avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty
          ? avatarUrl
          : participant.avatarUrl,
      role: forcedRole ?? participant.role,
    );
  }

  String? _profileDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) {
      return null;
    }

    final fullName = profile['full_name']?.toString().trim();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final username = profile['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return null;
  }

  // =========================================================
  // GET ALL
  // =========================================================

  Future<List<ProjectModel>> getAll() async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final idsRaw = await client.rpc(
        'get_my_project_ids',
      );

      final ids = _extractProjectIds(idsRaw);

      if (ids.isEmpty) {
        return [];
      }

      final response = await client
          .from('projects_view')
          .select()
          .inFilter('id', ids)
          .order(
        'created_at',
        ascending: false,
      );

      final projects = response.map<ProjectModel>((raw) {
        return ProjectModel.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }).toList();

      return _enrichProjectsWithProfiles(projects);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load projects failed',
      );
    }
  }

  List<String> _extractProjectIds(dynamic raw) {
    if (raw == null) {
      return [];
    }

    if (raw is! List) {
      return [];
    }

    return raw
        .map<String?>((item) {
      if (item == null) {
        return null;
      }

      if (item is String) {
        return item;
      }

      if (item is Map) {
        final id = item['id'] ?? item['project_id'];

        return id?.toString();
      }

      return item.toString();
    })
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  // =========================================================
  // GET BY ID
  // =========================================================

  Future<ProjectModel?> getById(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

    try {
      final data = await client
          .from('projects_view')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      final project = ProjectModel.fromJson(
        Map<String, dynamic>.from(data),
      );

      return _enrichProjectWithProfiles(project);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load project failed',
      );
    }
  }

  // =========================================================
  // PROJECT JSON
  // =========================================================

  Map<String, dynamic> _projectJsonForDb(
      ProjectModel project, {
        String? ownerId,
        bool includeOwnerSettings = true,
      }) {
    final source = Map<String, dynamic>.from(
      project.toJson(),
    );

    final allowed = <String>{
      'owner_id',
      'title',
      'description',
      'deadline',
      'status',
      'color',
    };

    if (includeOwnerSettings) {
      allowed.addAll({
        'category',
        'max_members',
        'max_attachments',
        'grading_enabled',
        'grade',
      });
    }

    final json = <String, dynamic>{};

    for (final entry in source.entries) {
      if (allowed.contains(entry.key)) {
        json[entry.key] = entry.value;
      }
    }

    if (ownerId != null && ownerId.isNotEmpty) {
      json['owner_id'] = ownerId;
    }

    if (!includeOwnerSettings) {
      json.remove('owner_id');
      json.remove('category');
      json.remove('max_members');
      json.remove('max_attachments');
      json.remove('grading_enabled');
      json.remove('grade');
    }

    json.removeWhere((key, value) => value == null);

    return json;
  }

  // =========================================================
  // PARTICIPANTS / INVITATIONS
  // =========================================================

  Future<void> syncParticipants({
    required String projectId,
    required String ownerId,
    required List<String> participantIds,
    List<ProjectParticipant>? participants,
  }) async {
    if (projectId.trim().isEmpty || ownerId.trim().isEmpty) {
      return;
    }

    try {
      final project = await getById(projectId);

      if (project != null && !isOwner(project)) {
        throw Exception('errors.no_permission');
      }

      final roleById = <String, ProjectRole>{};

      if (participants != null) {
        for (final participant in participants) {
          final id = participant.id.trim();

          if (id.isEmpty) {
            continue;
          }

          roleById[id] = id == ownerId
              ? ProjectRole.owner
              : _normalizeEditableRole(participant.role);
        }
      }

      final targetIds = participantIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      targetIds.add(ownerId);

      if (project != null &&
          project.maxMembers > 0 &&
          targetIds.length > project.maxMembers) {
        throw Exception('projects.max_members_error');
      }

      final existing = await client
          .from('project_members')
          .select('member_id, role')
          .eq('project_id', projectId);

      final existingRows = List<Map<String, dynamic>>.from(existing);

      final existingIds = existingRows
          .map<String>((row) => row['member_id'].toString())
          .toSet();

      final existingRoles = <String, String>{};

      for (final row in existingRows) {
        final memberId = row['member_id']?.toString();
        final role = row['role']?.toString();

        if (memberId == null || memberId.isEmpty) {
          continue;
        }

        existingRoles[memberId] =
        role != null && role.isNotEmpty ? role : 'viewer';
      }

      final toRemove = existingIds
          .difference(targetIds)
          .where((id) => id != ownerId)
          .toSet();

      if (toRemove.isNotEmpty) {
        await client
            .from('project_members')
            .delete()
            .eq('project_id', projectId)
            .inFilter(
          'member_id',
          toRemove.toList(),
        );
      }

      await _deletePendingInvitationsNotInTarget(
        projectId: projectId,
        targetIds: targetIds,
      );

      final rowsToUpsert = <Map<String, dynamic>>[];
      final idsToInvite = <String>{};

      for (final id in targetIds) {
        if (id == ownerId) {
          rowsToUpsert.add({
            'project_id': projectId,
            'member_id': id,
            'role': ProjectRole.owner.value,
          });

          continue;
        }

        final role = roleById[id] ??
            ProjectRoleExtension.fromString(
              existingRoles[id],
            );

        if (existingIds.contains(id)) {
          rowsToUpsert.add({
            'project_id': projectId,
            'member_id': id,
            'role': _normalizeEditableRole(role).value,
          });
        } else {
          idsToInvite.add(id);
        }
      }

      if (rowsToUpsert.isNotEmpty) {
        await client.from('project_members').upsert(
          rowsToUpsert,
          onConflict: 'project_id,member_id',
        );
      }

      if (project != null && idsToInvite.isNotEmpty) {
        for (final invitedUserId in idsToInvite) {
          final role = roleById[invitedUserId] ?? ProjectRole.viewer;

          await inviteProjectMember(
            projectId: projectId,
            invitedUserId: invitedUserId,
            role: _normalizeEditableRole(role),
            project: project,
          );
        }
      }
    } catch (e, st) {
      _handleError(
        e,
        st,
        'sync participants failed',
      );
    }
  }

  Future<void> _deletePendingInvitationsNotInTarget({
    required String projectId,
    required Set<String> targetIds,
  }) async {
    try {
      final pendingRaw = await client
          .from(_invitationsTable)
          .select('invited_user_id')
          .eq('project_id', projectId)
          .eq('status', 'pending');

      final pendingIds = List<Map<String, dynamic>>.from(pendingRaw)
          .map((row) => row['invited_user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final toDelete = pendingIds.difference(targetIds);

      if (toDelete.isEmpty) {
        return;
      }

      await client
          .from(_invitationsTable)
          .delete()
          .eq('project_id', projectId)
          .eq('status', 'pending')
          .inFilter(
        'invited_user_id',
        toDelete.toList(),
      );
    } catch (e) {
      debugPrint(
        '[ProjectService] pending invitations cleanup skipped: $e',
      );
    }
  }

  Future<void> inviteProjectMember({
    required String projectId,
    required String invitedUserId,
    required ProjectRole role,
    ProjectModel? project,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    try {
      final currentProject = project ?? await getById(projectId);

      if (currentProject == null) {
        throw Exception('errors.project_not_found');
      }

      if (!isOwner(currentProject)) {
        throw Exception('errors.no_permission');
      }

      final normalizedRole = _normalizeEditableRole(role);

      if (normalizedRole == ProjectRole.owner) {
        throw Exception('errors.no_permission');
      }

      final normalizedInvitedUserId = invitedUserId.trim();

      if (normalizedInvitedUserId.isEmpty ||
          normalizedInvitedUserId == currentProject.ownerId) {
        return;
      }

      final alreadyMember = currentProject.participantsData.any(
            (participant) => participant.id == normalizedInvitedUserId,
      );

      if (alreadyMember) {
        return;
      }

      final now = DateTime.now().toUtc().toIso8601String();

      await client.from(_invitationsTable).upsert(
        {
          'project_id': currentProject.id,
          'invited_user_id': normalizedInvitedUserId,
          'invited_by': userId,
          'role': normalizedRole.value,
          'status': 'pending',
          'created_at': now,
          'responded_at': null,
        },
        onConflict: 'project_id,invited_user_id',
      );

      await _notifications.notifyProjectInvitation(
        projectId: currentProject.id,
        projectTitle: currentProject.title,
        invitedUserId: normalizedInvitedUserId,
        invitedBy: userId,
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'invite project member failed',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getMyPendingInvitations() async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final response = await client
          .from(_invitationsTable)
          .select(
        '''
            id,
            project_id,
            invited_user_id,
            invited_by,
            role,
            status,
            created_at,
            responded_at,
            projects:project_id (
              id,
              title,
              description,
              owner_id
            )
            ''',
      )
          .eq('invited_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load pending invitations failed',
      );
    }
  }

  Future<Map<String, dynamic>?> _getInvitationForCurrentUser(
      String invitationId,
      ) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    if (invitationId.trim().isEmpty) {
      return null;
    }

    final invitation = await client
        .from(_invitationsTable)
        .select(
      '''
          id,
          project_id,
          invited_user_id,
          invited_by,
          role,
          status,
          created_at,
          responded_at,
          projects:project_id (
            id,
            title,
            owner_id
          )
          ''',
    )
        .eq('id', invitationId)
        .maybeSingle();

    if (invitation == null) {
      return null;
    }

    final data = Map<String, dynamic>.from(invitation);

    final invitedUserId =
        data['invited_user_id']?.toString().trim() ?? '';

    if (invitedUserId != userId) {
      throw Exception('errors.no_permission');
    }

    return data;
  }

  String _projectTitleFromInvitation(
      Map<String, dynamic> invitation,
      ) {
    final projectRaw = invitation['projects'];

    if (projectRaw is Map) {
      final title = projectRaw['title']?.toString().trim();

      if (title != null && title.isNotEmpty) {
        return title;
      }
    }

    return 'Проект';
  }

  Future<void> acceptInvitation(String invitationId) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    if (invitationId.trim().isEmpty) {
      return;
    }

    try {
      final invitation = await _getInvitationForCurrentUser(
        invitationId,
      );

      if (invitation == null) {
        throw Exception('errors.project_not_found');
      }

      final status = invitation['status']?.toString() ?? '';

      if (status != 'pending') {
        return;
      }

      final projectId =
          invitation['project_id']?.toString().trim() ?? '';

      final invitedBy =
      invitation['invited_by']?.toString().trim();

      final projectTitle = _projectTitleFromInvitation(
        invitation,
      );

      await client.rpc(
        'accept_project_invitation',
        params: {
          'p_invitation_id': invitationId,
        },
      );

      if (invitedBy != null && invitedBy.isNotEmpty) {
        await _notifications.createProjectNotification(
          recipientId: invitedBy,
          senderId: userId,
          projectId: projectId,
          projectTitle: projectTitle,
          type: 'member_invite_accepted',
          title: 'Приглашение принято',
          body:
          'Пользователь принял приглашение в проект "$projectTitle"',
        );
      }
    } catch (e, st) {
      _handleError(
        e,
        st,
        'accept invitation failed',
      );
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    if (invitationId.trim().isEmpty) {
      return;
    }

    try {
      final invitation = await _getInvitationForCurrentUser(
        invitationId,
      );

      if (invitation == null) {
        return;
      }

      final status = invitation['status']?.toString() ?? '';

      if (status != 'pending') {
        return;
      }

      final projectId =
          invitation['project_id']?.toString().trim() ?? '';

      final invitedBy =
      invitation['invited_by']?.toString().trim();

      final projectTitle = _projectTitleFromInvitation(
        invitation,
      );

      await client.rpc(
        'decline_project_invitation',
        params: {
          'p_invitation_id': invitationId,
        },
      );

      if (invitedBy != null && invitedBy.isNotEmpty) {
        await _notifications.createProjectNotification(
          recipientId: invitedBy,
          senderId: userId,
          projectId: projectId,
          projectTitle: projectTitle,
          type: 'member_invite_declined',
          title: 'Приглашение отклонено',
          body:
          'Пользователь отклонил приглашение в проект "$projectTitle"',
        );
      }
    } catch (e, st) {
      _handleError(
        e,
        st,
        'decline invitation failed',
      );
    }
  }

  ProjectRole _normalizeEditableRole(ProjectRole role) {
    if (role == ProjectRole.owner) {
      return ProjectRole.editor;
    }

    return role;
  }

  Future<void> updateMemberRole({
    required String projectId,
    required String memberId,
    required ProjectRole role,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    try {
      final project = await getById(projectId);

      if (project == null) {
        throw Exception('errors.project_not_found');
      }

      if (!isOwner(project)) {
        throw Exception('errors.no_permission');
      }

      if (memberId == project.ownerId && role != ProjectRole.owner) {
        throw Exception('errors.no_permission');
      }

      await client
          .from('project_members')
          .update({
        'role': memberId == project.ownerId
            ? ProjectRole.owner.value
            : _normalizeEditableRole(role).value,
      })
          .eq('project_id', projectId)
          .eq('member_id', memberId);

      final fresh = await getById(projectId) ?? project;

      await _notifications.notifyProjectUpdatedForMembers(
        project: fresh,
        senderId: userId,
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'update member role failed',
      );
    }
  }

  // =========================================================
  // ADD PROJECT
  // =========================================================

  Future<ProjectModel> add(ProjectModel project) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    await _ensureCurrentUserProfile();

    try {
      final json = _projectJsonForDb(
        project,
        ownerId: userId,
        includeOwnerSettings: true,
      );

      final response = await client
          .from('projects')
          .insert(json)
          .select('id')
          .single();

      final createdId = response['id'].toString();

      final participants = _normalizeProjectParticipants(
        ownerId: userId,
        participants: project.participantsData,
      );

      await syncParticipants(
        projectId: createdId,
        ownerId: userId,
        participantIds: participants
            .map((participant) => participant.id)
            .toList(),
        participants: participants,
      );

      final created = await getById(createdId);

      if (created == null) {
        throw Exception('errors.project_not_found');
      }

      await _notifications.showProjectUpdateNotification(
        projectId: created.id,
        title: 'Проект создан',
        body: created.title,
        payload: created.id,
      );

      return created;
    } catch (e, st) {
      _handleError(
        e,
        st,
        'create project failed',
      );
    }
  }

  // =========================================================
  // UPDATE PROJECT
  // =========================================================

  Future<void> update(ProjectModel project) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    try {
      final dbProject = await getById(project.id);

      if (dbProject == null) {
        throw Exception('errors.project_not_found');
      }

      if (!canEditProject(dbProject)) {
        throw Exception('errors.no_permission');
      }

      final ownerUpdate = isOwner(dbProject);

      final safeProject = ownerUpdate
          ? project
          : ProjectModel(
        id: dbProject.id,
        ownerId: dbProject.ownerId,
        title: project.title,
        description: project.description,
        deadline: project.deadline,
        createdAt: dbProject.createdAt,
        status: project.status,
        color: project.color,
        category: dbProject.category,
        maxMembers: dbProject.maxMembers,
        maxAttachments: dbProject.maxAttachments,
        gradingEnabled: dbProject.gradingEnabled,
        participantsData: dbProject.participantsData,
        attachments: dbProject.attachments,
        totalTasks: dbProject.totalTasks,
        completedTasks: dbProject.completedTasks,
        lastMessage: dbProject.lastMessage,
        lastMessageAt: dbProject.lastMessageAt,
        unreadCount: dbProject.unreadCount,
      );

      final wasCompleted =
          dbProject.statusEnum == ProjectStatus.completed;

      final becameCompleted =
          safeProject.statusEnum == ProjectStatus.completed;

      final json = _projectJsonForDb(
        safeProject,
        includeOwnerSettings: ownerUpdate,
      );

      await client
          .from('projects')
          .update(json)
          .eq('id', safeProject.id);

      if (ownerUpdate) {
        final participants = _normalizeProjectParticipants(
          ownerId: dbProject.ownerId,
          participants: safeProject.participantsData,
        );

        await syncParticipants(
          projectId: safeProject.id,
          ownerId: dbProject.ownerId,
          participantIds: participants
              .map((participant) => participant.id)
              .toList(),
          participants: participants,
        );
      }

      final fresh = await getById(safeProject.id) ?? safeProject;

      if (!wasCompleted && becameCompleted) {
        await _notifications.notifyProjectCompletedForMembers(
          project: fresh,
          senderId: userId,
        );
      } else {
        await _notifications.notifyProjectUpdatedForMembers(
          project: fresh,
          senderId: userId,
        );
      }
    } catch (e, st) {
      _handleError(
        e,
        st,
        'update project failed',
      );
    }
  }

  List<ProjectParticipant> _normalizeProjectParticipants({
    required String ownerId,
    required List<ProjectParticipant> participants,
  }) {
    final map = <String, ProjectParticipant>{};

    for (final participant in participants) {
      final id = participant.id.trim();

      if (id.isEmpty) {
        continue;
      }

      map[id] = ProjectParticipant(
        id: id,
        fullName: participant.fullName,
        username: participant.username,
        avatarUrl: participant.avatarUrl,
        role: id == ownerId
            ? ProjectRole.owner
            : _normalizeEditableRole(participant.role),
      );
    }

    if (ownerId.isNotEmpty) {
      final owner = map[ownerId];

      map[ownerId] = ProjectParticipant(
        id: ownerId,
        fullName: owner?.fullName ?? 'Owner',
        username: owner?.username,
        avatarUrl: owner?.avatarUrl,
        role: ProjectRole.owner,
      );
    }

    final result = map.values.toList();

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

    return result;
  }

  // =========================================================
  // DELETE PROJECT
  // =========================================================

  Future<void> delete(String id) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    try {
      final project = await getById(id);

      if (project == null) {
        return;
      }

      if (!isOwner(project)) {
        throw Exception('errors.no_permission');
      }

      await _notifications.notifyProjectDeletedForMembers(
        project: project,
        senderId: userId,
      );

      if (project.attachments.isNotEmpty) {
        final paths = project.attachments
            .map((attachment) => attachment.filePath)
            .where((path) => path.trim().isNotEmpty)
            .toList();

        if (paths.isNotEmpty) {
          try {
            await client.storage.from(bucketName).remove(paths);
          } catch (e) {
            debugPrint(
              '[ProjectService] storage cleanup failed: $e',
            );
          }
        }
      }

      await _safeDeleteByProjectId(
        table: 'message_reads',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'chat_typing',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'chat_presence',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'project_messages',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'project_tasks',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'project_grades',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'project_attachments',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: 'project_members',
        projectId: id,
      );

      await _safeDeleteByProjectId(
        table: _invitationsTable,
        projectId: id,
      );

      await client.from('projects').delete().eq('id', id);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'delete project failed',
      );
    }
  }

  Future<void> _safeDeleteByProjectId({
    required String table,
    required String projectId,
  }) async {
    try {
      await client.from(table).delete().eq('project_id', projectId);
    } catch (e) {
      debugPrint(
        '[ProjectService] delete from $table skipped: $e',
      );
    }
  }

  // =========================================================
  // UPLOAD ATTACHMENTS
  // =========================================================

  Future<ProjectModel> uploadAttachments({
    required String projectId,
    required List<String> fileNames,
    List<File>? files,
    List<Uint8List>? filesBytes,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    try {
      final project = await getById(projectId);

      if (project == null) {
        throw Exception('errors.project_not_found');
      }

      if (!canManageProjectContent(project)) {
        throw Exception('errors.no_permission');
      }

      if (fileNames.isEmpty) {
        return project;
      }

      final totalAfterUpload =
          project.attachments.length + fileNames.length;

      if (project.maxAttachments > 0 &&
          totalAfterUpload > project.maxAttachments) {
        throw Exception('projects.max_attachments_error');
      }

      if (kIsWeb) {
        if (filesBytes == null ||
            filesBytes.length != fileNames.length) {
          throw Exception('errors.invalid_files_bytes');
        }
      } else {
        if (files == null || files.length != fileNames.length) {
          throw Exception('errors.invalid_files');
        }
      }

      final uploaded = <Attachment>[];

      for (int index = 0; index < fileNames.length; index++) {
        final originalName = fileNames[index].trim();

        if (originalName.isEmpty) {
          continue;
        }

        final ext = _extensionOf(originalName);
        final mimeType = _mimeTypeFromExtension(ext);

        final safeName = _buildSafeStorageName(
          originalName,
          index,
        );

        final path = 'projects/$projectId/$userId/$safeName';

        int fileSize = 0;

        if (kIsWeb && filesBytes != null) {
          fileSize = filesBytes[index].length;

          await client.storage.from(bucketName).uploadBinary(
            path,
            filesBytes[index],
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );
        } else if (files != null) {
          fileSize = await files[index].length();

          await client.storage.from(bucketName).upload(
            path,
            files[index],
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );
        }

        final attachmentId = const Uuid().v4();

        final now = DateTime.now();

        final attachment = Attachment(
          id: attachmentId,
          projectId: projectId,
          fileName: originalName,
          filePath: path,
          mimeType: mimeType,
          fileSize: fileSize,
          uploadedAt: now,
          uploaderId: userId,
        );

        uploaded.add(attachment);

        await client.from('project_attachments').insert({
          'id': attachmentId,
          'project_id': projectId,
          'uploaded_by': userId,
          'file_name': originalName,
          'file_path': path,
          'mime_type': mimeType,
          'file_size': fileSize,
          'created_at': now.toUtc().toIso8601String(),
        });
      }

      if (uploaded.isNotEmpty) {
        await _notifications.notifyProjectUpdatedForMembers(
          project: project,
          senderId: userId,
        );
      }

      return project.copyWith(
        attachments: [
          ...project.attachments,
          ...uploaded,
        ],
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'upload attachments failed',
      );
    }
  }

  String _extensionOf(String fileName) {
    final clean = fileName.trim();

    if (!clean.contains('.')) {
      return 'bin';
    }

    final ext = clean.split('.').last.toLowerCase().trim();

    final safeExt = ext.replaceAll(
      RegExp(r'[^a-zA-Z0-9]+'),
      '',
    );

    return safeExt.isEmpty ? 'bin' : safeExt;
  }

  String _buildSafeStorageName(
      String originalName,
      int index,
      ) {
    final ext = _extensionOf(originalName);

    return '${DateTime.now().millisecondsSinceEpoch}_'
        '${index}_${const Uuid().v4()}.$ext';
  }

  String _mimeTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'gif':
        return 'image/gif';

      case 'webp':
        return 'image/webp';

      case 'pdf':
        return 'application/pdf';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'xls':
        return 'application/vnd.ms-excel';

      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';

      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      case 'txt':
        return 'text/plain';

      case 'zip':
        return 'application/zip';

      case 'rar':
        return 'application/vnd.rar';

      default:
        return 'application/octet-stream';
    }
  }

  // =========================================================
  // DELETE ATTACHMENT
  // =========================================================

  Future<void> deleteAttachment(
      String projectId,
      String filePath,
      ) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    try {
      final project = await getById(projectId);

      if (project == null) {
        return;
      }

      if (!canManageProjectContent(project)) {
        throw Exception('errors.no_permission');
      }

      if (filePath.trim().isEmpty) {
        return;
      }

      try {
        await client.storage.from(bucketName).remove([filePath]);
      } catch (e) {
        debugPrint(
          '[ProjectService] storage attachment delete failed: $e',
        );
      }

      await client
          .from('project_attachments')
          .delete()
          .eq('project_id', projectId)
          .eq('file_path', filePath);

      await _notifications.notifyProjectUpdatedForMembers(
        project: project,
        senderId: userId,
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'delete attachment failed',
      );
    }
  }
}