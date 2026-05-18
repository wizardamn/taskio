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

  final NotificationService _notifications =
  NotificationService();

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

      final fallbackName = email.contains('@')
          ? email.split('@').first
          : 'User';

      final fallbackUsername = fallbackName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');

      await client.from('profiles').upsert(
        {
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
        },
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
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return false;
    }

    if (project.ownerId == userId) {
      return true;
    }

    for (final participant in project.participantsData) {
      if (participant.id != userId) {
        continue;
      }

      return participant.role == ProjectRole.owner ||
          participant.role == ProjectRole.editor;
    }

    return false;
  }

  bool canManageProjectContent(ProjectModel project) {
    return isProjectMember(project);
  }

  bool canManageMembers(ProjectModel project) {
    return isOwner(project);
  }

  bool canGradeProject(ProjectModel project) {
    return isOwner(project) || canEditProject(project);
  }

  Future<bool> canEditProjectById(String projectId) async {
    final project = await getById(projectId);

    if (project == null) {
      return false;
    }

    return canEditProject(project);
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

      final ids = List<String>.from(idsRaw ?? []);

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

      return response
          .map<ProjectModel>(
            (raw) => ProjectModel.fromJson(
          Map<String, dynamic>.from(raw),
        ),
      )
          .toList();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load projects failed',
      );
    }
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

      return ProjectModel.fromJson(
        Map<String, dynamic>.from(data),
      );
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
      'category',
      'max_members',
      'max_attachments',
      'grading_enabled',
      'grade',
    };

    final json = <String, dynamic>{};

    for (final entry in source.entries) {
      if (allowed.contains(entry.key)) {
        json[entry.key] = entry.value;
      }
    }

    if (ownerId != null && ownerId.isNotEmpty) {
      json['owner_id'] = ownerId;
    }

    json.removeWhere((key, value) => value == null);

    return json;
  }

  // =========================================================
  // SYNC PARTICIPANTS
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

      final existingRows =
      List<Map<String, dynamic>>.from(existing);

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

      final rowsToUpsert = <Map<String, dynamic>>[];

      for (final id in targetIds) {
        final role = id == ownerId
            ? ProjectRole.owner
            : roleById[id] ??
            ProjectRoleExtension.fromString(
              existingRoles[id],
            );

        rowsToUpsert.add({
          'project_id': projectId,
          'member_id': id,
          'role': id == ownerId
              ? ProjectRole.owner.value
              : _normalizeEditableRole(role).value,
        });
      }

      if (rowsToUpsert.isNotEmpty) {
        await client.from('project_members').upsert(
          rowsToUpsert,
          onConflict: 'project_id,member_id',
        );
      }
    } catch (e, st) {
      _handleError(
        e,
        st,
        'sync participants failed',
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

      await _notifications.showSimple(
        'project_created',
        project.title,
      );

      final created = await getById(createdId);

      if (created == null) {
        throw Exception('errors.project_not_found');
      }

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

      final json = _projectJsonForDb(project);

      await client
          .from('projects')
          .update(json)
          .eq('id', project.id);

      final participants = _normalizeProjectParticipants(
        ownerId: dbProject.ownerId,
        participants: project.participantsData,
      );

      await syncParticipants(
        projectId: project.id,
        ownerId: dbProject.ownerId,
        participantIds: participants
            .map((participant) => participant.id)
            .toList(),
        participants: participants,
      );

      await _notifications.showSimple(
        'project_updated',
        project.title,
      );
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

      await client
          .from('projects')
          .delete()
          .eq('id', id);

      await _notifications.showSimple(
        'project_deleted',
        project.title,
      );
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

        final attachment = Attachment(
          id: attachmentId,
          projectId: projectId,
          fileName: originalName,
          filePath: path,
          mimeType: mimeType,
          fileSize: fileSize,
          uploadedAt: DateTime.now(),
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
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      await _notifications.showSimple(
        'file_added',
        '',
      );

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
    } catch (e, st) {
      _handleError(
        e,
        st,
        'delete attachment failed',
      );
    }
  }
}