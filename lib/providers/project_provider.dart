import 'dart:async';
import 'dart:io' show File;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_model.dart';
import '../services/notification_service.dart';
import '../services/project_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';
import '../utils/snackbar_manager.dart';

enum ProjectFilter {
  all,
  inProgressOnly,
  completedOnly,
}

enum SortBy {
  deadlineAsc,
  deadlineDesc,
  status,
  title,
}

enum DeadlineFilter {
  all,
  today,
  week,
  overdue,
}

enum _ProjectListMode {
  all,
  active,
  archived,
}

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  ProjectProvider(this._service);

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  String? _userId;
  String _currentUserName = '';

  bool _isLoading = false;
  bool _disposed = false;
  bool _fetchQueued = false;
  bool _isInvitationsLoading = false;

  String? _errorMessage;
  String? _currentProjectId;
  String? _lastEmittedCurrentProjectId;

  final NotificationService _notifications = NotificationService();

  final Set<String> _completedShown = {};
  final Set<String> _autoCompletingProjectIds = {};
  final Set<String> _autoArchiveIgnoredProjectIds = {};

  final List<ProjectModel> _projects = [];
  final List<Map<String, dynamic>> _pendingInvitations = [];

  List<ProjectModel> _lastEmitted = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;
  DeadlineFilter _deadlineFilter = DeadlineFilter.all;

  String _searchQuery = '';

  Timer? _searchDebounce;
  Timer? _messagesRefreshDebounce;
  Timer? _projectsRefreshDebounce;
  Timer? _tasksRefreshDebounce;
  Timer? _invitationsRefreshDebounce;

  RealtimeChannel? _projectsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _invitationsChannel;

  String? get currentProjectId => _currentProjectId;

  ProjectFilter get filter => _filter;
  SortBy get sortBy => _sortBy;
  DeadlineFilter get deadlineFilter => _deadlineFilter;

  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isInvitationsLoading => _isInvitationsLoading;
  String? get errorMessage => _errorMessage;

  bool get isGuest {
    return !_hasValidUserId;
  }

  bool get _hasValidUserId {
    return _isValidUuid(_userId);
  }

  List<Map<String, dynamic>> get pendingInvitations {
    return List<Map<String, dynamic>>.unmodifiable(
      _pendingInvitations,
    );
  }

  int get pendingInvitationsCount {
    return _pendingInvitations.length;
  }

  String get currentUserName {
    return _currentUserName.isEmpty
        ? 'profile.guest'.tr()
        : _currentUserName;
  }

  ProjectModel? get currentProject {
    final id = _currentProjectId;

    if (id == null) {
      return null;
    }

    for (final project in _projects) {
      if (project.id == id) {
        return project;
      }
    }

    return null;
  }

  List<ProjectModel> get projects {
    return activeProjects;
  }

  List<ProjectModel> get allProjects {
    return _buildProjectList(
      _projects,
      mode: _ProjectListMode.all,
    );
  }

  List<ProjectModel> get activeProjects {
    return _buildProjectList(
      _projects,
      mode: _ProjectListMode.active,
    );
  }

  List<ProjectModel> get archivedProjects {
    return _buildProjectList(
      _projects,
      mode: _ProjectListMode.archived,
    );
  }

  int get archivedProjectsCount {
    return _projects.where(isArchivedProject).length;
  }

  bool get hasArchivedProjects {
    return archivedProjectsCount > 0;
  }

  bool _isValidUuid(String? value) {
    final id = value?.trim();

    if (id == null || id.isEmpty) {
      return false;
    }

    if (id.toLowerCase() == 'guest') {
      return false;
    }

    return _uuidRegex.hasMatch(id);
  }

  List<ProjectModel> _buildProjectList(
      Iterable<ProjectModel> source, {
        required _ProjectListMode mode,
      }) {
    var result = List<ProjectModel>.from(source);

    switch (mode) {
      case _ProjectListMode.active:
        result = result
            .where(
              (project) => !isArchivedProject(project),
        )
            .toList();
        break;

      case _ProjectListMode.archived:
        result = result
            .where(
              (project) => isArchivedProject(project),
        )
            .toList();
        break;

      case _ProjectListMode.all:
        break;
    }

    final now = DateTime.now();

    if (_deadlineFilter != DeadlineFilter.all) {
      result = result.where((project) {
        final deadline = project.deadline;

        switch (_deadlineFilter) {
          case DeadlineFilter.today:
            return deadline.year == now.year &&
                deadline.month == now.month &&
                deadline.day == now.day;

          case DeadlineFilter.week:
            return deadline.isAfter(now) &&
                deadline.isBefore(
                  now.add(
                    const Duration(days: 7),
                  ),
                );

          case DeadlineFilter.overdue:
            return deadline.isBefore(now);

          case DeadlineFilter.all:
            return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      result = result.where((project) {
        final inTitle = project.title.toLowerCase().contains(query);

        final inDescription =
        project.description.toLowerCase().contains(query);

        final inParticipants =
        project.participantsData.any((participant) {
          final fullName = participant.fullName.toLowerCase();

          final username = (participant.username ?? '').toLowerCase();

          return fullName.contains(query) || username.contains(query);
        });

        final inFiles = project.attachments.any((attachment) {
          return attachment.fileName.toLowerCase().contains(query);
        });

        return inTitle || inDescription || inParticipants || inFiles;
      }).toList();
    }

    switch (_filter) {
      case ProjectFilter.inProgressOnly:
        result = result
            .where(
              (project) => project.statusEnum == ProjectStatus.inProgress,
        )
            .toList();
        break;

      case ProjectFilter.completedOnly:
        result = result
            .where(
              (project) => project.statusEnum == ProjectStatus.completed,
        )
            .toList();
        break;

      case ProjectFilter.all:
        break;
    }

    _sort(result);

    return result;
  }

  // =========================================================
  // USER
  // =========================================================

  Future<void> setUser(
      String userId,
      String userName,
      ) async {
    if (_disposed) {
      return;
    }

    final normalizedUserId = userId.trim();
    final normalizedUserName = userName.trim();

    _removeRealtime();

    _notifications.clearSettingsCache();

    _projects.clear();
    _pendingInvitations.clear();
    _lastEmitted.clear();
    _completedShown.clear();
    _autoCompletingProjectIds.clear();
    _autoArchiveIgnoredProjectIds.clear();

    _currentProjectId = null;
    _lastEmittedCurrentProjectId = null;
    _errorMessage = null;
    _fetchQueued = false;
    _isLoading = false;
    _isInvitationsLoading = false;

    _searchDebounce?.cancel();
    _messagesRefreshDebounce?.cancel();
    _projectsRefreshDebounce?.cancel();
    _tasksRefreshDebounce?.cancel();
    _invitationsRefreshDebounce?.cancel();

    _searchDebounce = null;
    _messagesRefreshDebounce = null;
    _projectsRefreshDebounce = null;
    _tasksRefreshDebounce = null;
    _invitationsRefreshDebounce = null;

    _currentUserName = normalizedUserName;

    if (!_isValidUuid(normalizedUserId)) {
      _userId = null;
      _service.updateOwner(null);
      _safeNotify();
      return;
    }

    _userId = normalizedUserId;
    _service.updateOwner(normalizedUserId);

    await fetchProjects();

    if (_disposed || isGuest) {
      return;
    }

    await fetchPendingInvitations();

    if (_disposed || isGuest) {
      return;
    }

    _subscribeRealtime();
    _subscribeMessagesRealtime();
    _subscribeTasksRealtime();
    _subscribeInvitationsRealtime();

    _safeNotify();
  }

  void clear({
    bool keepProjects = false,
  }) {
    _userId = null;
    _currentUserName = '';
    _errorMessage = null;
    _searchQuery = '';
    _currentProjectId = null;
    _lastEmittedCurrentProjectId = null;
    _fetchQueued = false;
    _isLoading = false;
    _isInvitationsLoading = false;

    _completedShown.clear();
    _autoCompletingProjectIds.clear();
    _autoArchiveIgnoredProjectIds.clear();
    _pendingInvitations.clear();

    _searchDebounce?.cancel();
    _messagesRefreshDebounce?.cancel();
    _projectsRefreshDebounce?.cancel();
    _tasksRefreshDebounce?.cancel();
    _invitationsRefreshDebounce?.cancel();

    _searchDebounce = null;
    _messagesRefreshDebounce = null;
    _projectsRefreshDebounce = null;
    _tasksRefreshDebounce = null;
    _invitationsRefreshDebounce = null;

    if (!keepProjects) {
      _projects.clear();
    }

    _lastEmitted.clear();

    _removeRealtime();

    _notifications.clearSettingsCache();

    unawaited(
      _notifications.cancelAll(),
    );

    _service.updateOwner(null);

    _safeNotify();
  }

  // =========================================================
  // CREATE EMPTY
  // =========================================================

  ProjectModel createEmptyProject() {
    final userId = _userId;

    if (!_isValidUuid(userId)) {
      throw Exception(
        'projects.guest_cannot_create',
      );
    }

    return ProjectModel.createEmpty(
      ownerId: userId!,
    );
  }

  // =========================================================
  // USERS FOR PARTICIPANT SELECTION
  // =========================================================

  Future<List<Map<String, dynamic>>> getUsersForSelection() async {
    if (isGuest) {
      _denyGuest();
      return [];
    }

    try {
      return await _service.getUsersForSelection();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'getUsersForSelection',
      );

      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() {
    return getUsersForSelection();
  }

  // =========================================================
  // INVITATIONS
  // =========================================================

  Future<void> fetchPendingInvitations() async {
    if (_disposed) {
      return;
    }

    if (isGuest) {
      if (_pendingInvitations.isNotEmpty || _isInvitationsLoading) {
        _pendingInvitations.clear();
        _isInvitationsLoading = false;
        _safeNotify();
      }

      return;
    }

    try {
      _setInvitationsLoading(true);

      final invitations = await _service.getMyPendingInvitations();

      _pendingInvitations
        ..clear()
        ..addAll(invitations);

      _safeNotify();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'fetchPendingInvitations',
      );
    } finally {
      _setInvitationsLoading(false);
    }
  }

  Future<void> acceptInvitation(String invitationId) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    if (invitationId.trim().isEmpty) {
      return;
    }

    try {
      _setLoading(true);

      await _service.acceptInvitation(invitationId);

      _pendingInvitations.removeWhere(
            (invitation) => invitation['id']?.toString() == invitationId,
      );

      await fetchProjects();
      await fetchPendingInvitations();

      SnackbarManager.showSuccess(
        'invitations.accepted'.tr(),
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'acceptInvitation',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    if (invitationId.trim().isEmpty) {
      return;
    }

    try {
      _setInvitationsLoading(true);

      await _service.declineInvitation(invitationId);

      _pendingInvitations.removeWhere(
            (invitation) => invitation['id']?.toString() == invitationId,
      );

      await fetchPendingInvitations();

      SnackbarManager.showSuccess(
        'invitations.declined'.tr(),
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'declineInvitation',
      );
    } finally {
      _setInvitationsLoading(false);
    }
  }

  // =========================================================
  // FETCH PROJECTS
  // =========================================================

  Future<void> fetchProjects() async {
    if (_disposed || isGuest) {
      return;
    }

    if (_isLoading) {
      _fetchQueued = true;
      return;
    }

    try {
      _setLoading(true);

      final loaded = await _service.getAll();

      _sort(loaded);

      if (_isSame(loaded, _projects)) {
        _fixCurrentProject();
        await _checkCompletedProjects();
        _emitIfChanged();
        return;
      }

      _projects
        ..clear()
        ..addAll(loaded);

      _fixCurrentProject();

      await _rescheduleProjectDeadlines();

      await _checkCompletedProjects();

      _emitIfChanged();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'fetchProjects',
      );
    } finally {
      _setLoading(false);

      if (_fetchQueued && !_disposed && !isGuest) {
        _fetchQueued = false;

        unawaited(
          fetchProjects(),
        );
      } else {
        _fetchQueued = false;
      }
    }
  }

  Future<ProjectModel?> refreshProject(
      String projectId, {
        bool makeCurrent = false,
      }) async {
    if (_disposed || isGuest || projectId.trim().isEmpty) {
      return null;
    }

    try {
      final fresh = await _service.getById(projectId);

      if (fresh == null) {
        _projects.removeWhere(
              (project) => project.id == projectId,
        );

        if (_currentProjectId == projectId) {
          _currentProjectId = null;
        }

        await _notifications.cancelProjectDeadline(projectId);

        _fixCurrentProject();
        _emitIfChanged();

        return null;
      }

      final index = _projects.indexWhere(
            (project) => project.id == projectId,
      );

      if (index == -1) {
        _projects.insert(0, fresh);
      } else {
        _projects[index] = fresh;
      }

      _sort(_projects);

      if (makeCurrent || _currentProjectId == null) {
        _currentProjectId = fresh.id;
      }

      await _syncProjectDeadlineNotification(fresh);

      _fixCurrentProject();

      await _checkCompletedProjects();

      _emitIfChanged();

      return fresh;
    } catch (e, st) {
      _handleError(
        e,
        st,
        'refreshProject',
      );

      return null;
    }
  }

  void _fixCurrentProject() {
    if (_projects.isEmpty) {
      _currentProjectId = null;
      return;
    }

    final currentId = _currentProjectId;

    if (currentId != null && currentId.isNotEmpty) {
      final exists = _projects.any(
            (project) => project.id == currentId,
      );

      if (exists) {
        return;
      }
    }

    final active = _projects.where(
          (project) => !isArchivedProject(project),
    );

    if (active.isNotEmpty) {
      _currentProjectId = active.first.id;
      return;
    }

    _currentProjectId = _projects.first.id;
  }

  // =========================================================
  // CURRENT PROJECT
  // =========================================================

  void setCurrentProject(String projectId) {
    if (projectId.trim().isEmpty) {
      return;
    }

    if (_currentProjectId == projectId) {
      return;
    }

    _currentProjectId = projectId;

    _safeNotify();
  }

  // =========================================================
  // ADD PROJECT
  // =========================================================

  Future<ProjectModel?> addProject(
      ProjectModel project,
      ) async {
    if (isGuest) {
      _denyGuest();
      return null;
    }

    try {
      _setLoading(true);

      final created = await _service.add(project);

      _projects.insert(0, created);

      _sort(_projects);

      _currentProjectId = created.id;

      await _syncProjectDeadlineNotification(created);

      _emitIfChanged();

      return created;
    } catch (e, st) {
      _handleError(
        e,
        st,
        'addProject',
      );

      return null;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // UPDATE PROJECT
  // =========================================================

  Future<void> updateProject(
      ProjectModel project,
      ) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    final current = _findProject(project.id) ?? project;

    if (!canEditProject(current)) {
      _denyPermission();
      return;
    }

    final projectForUpdate = _prepareProjectForUpdate(
      incoming: project,
      current: current,
    );

    try {
      _setLoading(true);

      await _service.update(projectForUpdate);

      final fresh = await _service.getById(projectForUpdate.id);

      if (fresh == null) {
        await fetchProjects();
        return;
      }

      final index = _projects.indexWhere(
            (item) => item.id == projectForUpdate.id,
      );

      if (index != -1) {
        _projects[index] = fresh;
      } else {
        _projects.insert(0, fresh);
      }

      _sort(_projects);

      _currentProjectId = fresh.id;

      await _syncProjectDeadlineNotification(fresh);

      await fetchPendingInvitations();

      await _checkCompletedProjects();

      _emitIfChanged();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'updateProject',
      );
    } finally {
      _setLoading(false);
    }
  }

  ProjectModel _prepareProjectForUpdate({
    required ProjectModel incoming,
    required ProjectModel current,
  }) {
    if (isOwner(current)) {
      return incoming;
    }

    return ProjectModel(
      id: current.id,
      ownerId: current.ownerId,
      title: incoming.title,
      description: incoming.description,
      deadline: incoming.deadline,
      createdAt: current.createdAt,
      status: incoming.status,
      color: incoming.color,
      category: current.category,
      maxMembers: current.maxMembers,
      maxAttachments: current.maxAttachments,
      gradingEnabled: current.gradingEnabled,
      participantsData: current.participantsData,
      attachments: current.attachments,
      totalTasks: current.totalTasks,
      completedTasks: current.completedTasks,
      lastMessage: current.lastMessage,
      lastMessageAt: current.lastMessageAt,
      unreadCount: current.unreadCount,
    );
  }

  // =========================================================
  // ARCHIVE / RESTORE / COMPLETE
  // =========================================================

  bool isArchivedProject(ProjectModel project) {
    return project.statusEnum == ProjectStatus.completed ||
        project.statusEnum == ProjectStatus.archived;
  }

  bool canArchiveProject(ProjectModel project) {
    return canEditProject(project) && !isArchivedProject(project);
  }

  bool canRestoreProject(ProjectModel project) {
    return canEditProject(project) && isArchivedProject(project);
  }

  Future<void> completeProject(ProjectModel project) async {
    _autoArchiveIgnoredProjectIds.remove(project.id);

    await _changeProjectStatus(
      project: project,
      status: ProjectStatus.completed,
      operation: 'completeProject',
    );
  }

  Future<void> archiveProject(ProjectModel project) async {
    _autoArchiveIgnoredProjectIds.remove(project.id);

    await _changeProjectStatus(
      project: project,
      status: ProjectStatus.archived,
      operation: 'archiveProject',
    );
  }

  Future<void> restoreProject(ProjectModel project) async {
    _autoArchiveIgnoredProjectIds.add(project.id);
    _completedShown.remove(project.id);

    await _changeProjectStatus(
      project: project,
      status: ProjectStatus.inProgress,
      operation: 'restoreProject',
    );
  }

  Future<void> _changeProjectStatus({
    required ProjectModel project,
    required ProjectStatus status,
    required String operation,
  }) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    final current = _findProject(project.id) ?? project;

    if (!canEditProject(current)) {
      _denyPermission();
      return;
    }

    if (current.statusEnum == status) {
      return;
    }

    try {
      _setLoading(true);

      final updated = current.copyWith(
        status: status.index,
      );

      await _service.update(updated);

      final fresh = await _service.getById(updated.id);

      if (fresh == null) {
        await fetchProjects();
        return;
      }

      final index = _projects.indexWhere(
            (item) => item.id == fresh.id,
      );

      if (index != -1) {
        _projects[index] = fresh;
      } else {
        _projects.insert(0, fresh);
      }

      _sort(_projects);

      _currentProjectId = fresh.id;

      await _syncProjectDeadlineNotification(fresh);

      _fixCurrentProject();

      _emitIfChanged();
    } catch (e, st) {
      _handleError(
        e,
        st,
        operation,
      );
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // DELETE PROJECT
  // =========================================================

  Future<void> deleteProject(String id) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    final project = _findProject(id);

    if (project != null && !isOwner(project)) {
      _denyPermission();
      return;
    }

    try {
      _setLoading(true);

      await _service.delete(id);

      _projects.removeWhere(
            (project) => project.id == id,
      );

      _completedShown.remove(id);
      _autoCompletingProjectIds.remove(id);
      _autoArchiveIgnoredProjectIds.remove(id);

      if (_currentProjectId == id) {
        _currentProjectId = _projects.isNotEmpty ? _projects.first.id : null;
      }

      await _notifications.cancelProjectDeadline(id);

      _emitIfChanged();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'deleteProject',
      );
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // PARTICIPANTS / ROLES
  // =========================================================

  Future<void> syncParticipants({
    required String projectId,
    required String ownerId,
    required List<String> participantIds,
    List<ProjectParticipant>? participants,
  }) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    final project = _findProject(projectId);

    if (project != null && !canManageMembers(project)) {
      _denyPermission();
      return;
    }

    try {
      await _service.syncParticipants(
        projectId: projectId,
        ownerId: ownerId,
        participantIds: participantIds,
        participants: participants,
      );

      await refreshProject(
        projectId,
        makeCurrent: _currentProjectId == projectId,
      );

      await fetchPendingInvitations();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'syncParticipants',
      );
    }
  }

  Future<void> updateMemberRole({
    required String projectId,
    required String memberId,
    required ProjectRole role,
  }) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    final project = _findProject(projectId);

    if (project == null) {
      await refreshProject(projectId);
    }

    final actualProject = _findProject(projectId) ?? project;

    if (actualProject != null && !canChangeMemberRoles(actualProject)) {
      _denyPermission();
      return;
    }

    try {
      await _service.updateMemberRole(
        projectId: projectId,
        memberId: memberId,
        role: role,
      );

      await refreshProject(
        projectId,
        makeCurrent: _currentProjectId == projectId,
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'updateMemberRole',
      );
    }
  }

  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Future<ProjectModel?> uploadAttachments({
    required String projectId,
    required List<String> fileNames,
    List<File>? files,
    List<Uint8List>? filesBytes,
  }) async {
    if (isGuest) {
      _denyGuest();
      return null;
    }

    final project = _findProject(projectId);

    if (project != null && !canAddAttachments(project)) {
      _denyPermission();
      return null;
    }

    try {
      final updated = await _service.uploadAttachments(
        projectId: projectId,
        fileNames: fileNames,
        files: files,
        filesBytes: filesBytes,
      );

      final index = _projects.indexWhere(
            (project) => project.id == projectId,
      );

      if (index != -1) {
        _projects[index] = updated;
      } else {
        _projects.insert(0, updated);
      }

      _sort(_projects);

      _currentProjectId = updated.id;

      _emitIfChanged();

      return updated;
    } catch (e, st) {
      _handleError(
        e,
        st,
        'uploadAttachments',
      );

      return null;
    }
  }

  Future<void> deleteAttachment({
    required String projectId,
    required String filePath,
  }) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    final project = _findProject(projectId);

    if (project != null) {
      final attachment = _findAttachmentInProject(
        project: project,
        filePath: filePath,
      );

      if (attachment != null &&
          !canDeleteAttachment(
            project: project,
            attachment: attachment,
          )) {
        _denyPermission();
        return;
      }
    }

    try {
      await _service.deleteAttachment(
        projectId,
        filePath,
      );

      final index = _projects.indexWhere(
            (project) => project.id == projectId,
      );

      if (index != -1) {
        final current = _projects[index];

        _projects[index] = current.copyWith(
          attachments: current.attachments
              .where(
                (attachment) => attachment.filePath != filePath,
          )
              .toList(),
        );

        _currentProjectId = projectId;

        _emitIfChanged();
      }
    } catch (e, st) {
      _handleError(
        e,
        st,
        'deleteAttachment',
      );
    }
  }

  // =========================================================
  // PERMISSIONS
  // =========================================================

  bool isProjectMember(ProjectModel project) {
    final userId = _userId;

    if (!_isValidUuid(userId)) {
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

    return role == ProjectRole.owner || role == ProjectRole.editor;
  }

  bool canManageProjectContent(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner || role == ProjectRole.editor;
  }

  bool canManageTasks(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner || role == ProjectRole.editor;
  }

  bool canCompleteTasks(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner ||
        role == ProjectRole.editor ||
        role == ProjectRole.viewer;
  }

  bool canAddAttachments(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner ||
        role == ProjectRole.editor ||
        role == ProjectRole.viewer;
  }

  bool canDeleteAnyAttachments(ProjectModel project) {
    final role = _currentUserRole(project);

    return role == ProjectRole.owner || role == ProjectRole.editor;
  }

  bool canDeleteAttachment({
    required ProjectModel project,
    required Attachment attachment,
  }) {
    final role = _currentUserRole(project);
    final userId = _userId;

    if (!_isValidUuid(userId)) {
      return false;
    }

    if (role == ProjectRole.owner || role == ProjectRole.editor) {
      return true;
    }

    if (role != ProjectRole.viewer) {
      return false;
    }

    return attachment.isUploadedBy(userId!);
  }

  bool canEditOwnerSettings(ProjectModel project) {
    return isOwner(project);
  }

  bool isOwner(ProjectModel project) {
    final userId = _userId;

    if (!_isValidUuid(userId)) {
      return false;
    }

    return project.ownerId == userId;
  }

  bool canManageMembers(ProjectModel project) {
    return isOwner(project);
  }

  bool canChangeMemberRoles(ProjectModel project) {
    return isOwner(project);
  }

  bool canGradeProject(ProjectModel project) {
    return isOwner(project);
  }

  ProjectRole? _currentUserRole(ProjectModel project) {
    final userId = _userId;

    if (!_isValidUuid(userId)) {
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

  ProjectModel? _findProject(String id) {
    for (final project in _projects) {
      if (project.id == id) {
        return project;
      }
    }

    return null;
  }

  Attachment? _findAttachmentInProject({
    required ProjectModel project,
    required String filePath,
  }) {
    final normalizedPath = filePath.trim();

    if (normalizedPath.isEmpty) {
      return null;
    }

    for (final attachment in project.attachments) {
      if (attachment.filePath == normalizedPath) {
        return attachment;
      }
    }

    return null;
  }

  // =========================================================
  // DEADLINE NOTIFICATIONS
  // =========================================================

  bool _shouldScheduleDeadline(ProjectModel project) {
    final isActive = project.statusEnum == ProjectStatus.planned ||
        project.statusEnum == ProjectStatus.inProgress;

    if (!isActive) {
      return false;
    }

    return project.deadline.isAfter(DateTime.now());
  }

  List<ProjectModel> _activeDeadlineProjects() {
    return _projects.where(_shouldScheduleDeadline).toList();
  }

  Future<void> _rescheduleProjectDeadlines() async {
    if (_projects.isEmpty) {
      await _notifications.cancelAll();
      return;
    }

    await _notifications.scheduleProjects(
      _activeDeadlineProjects(),
    );
  }

  Future<void> _syncProjectDeadlineNotification(
      ProjectModel project,
      ) async {
    if (_shouldScheduleDeadline(project)) {
      await _notifications.scheduleProjectDeadline(
        projectId: project.id,
        title: project.title,
        deadline: project.deadline,
      );
      return;
    }

    await _notifications.cancelProjectDeadline(project.id);
  }

  // =========================================================
  // FILTERS / SEARCH / SORT
  // =========================================================

  void search(String query) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
          () {
        if (_disposed) {
          return;
        }

        _searchQuery = query.trim();

        _safeNotify();
      },
    );
  }

  void setSort(SortBy sortBy) {
    if (_sortBy == sortBy) {
      return;
    }

    _sortBy = sortBy;

    _safeNotify();
  }

  void setFilter(ProjectFilter filter) {
    if (_filter == filter) {
      return;
    }

    _filter = filter;

    _safeNotify();
  }

  void setDeadlineFilter(
      DeadlineFilter filter,
      ) {
    if (_deadlineFilter == filter) {
      return;
    }

    _deadlineFilter = filter;

    _safeNotify();
  }

  void resetFilters() {
    _filter = ProjectFilter.all;
    _deadlineFilter = DeadlineFilter.all;
    _sortBy = SortBy.deadlineAsc;
    _searchQuery = '';

    _safeNotify();
  }

  void _sort(List<ProjectModel> list) {
    switch (_sortBy) {
      case SortBy.deadlineAsc:
        list.sort(
              (a, b) => a.deadline.compareTo(b.deadline),
        );
        break;

      case SortBy.deadlineDesc:
        list.sort(
              (a, b) => b.deadline.compareTo(a.deadline),
        );
        break;

      case SortBy.status:
        list.sort(
              (a, b) => a.statusEnum.index.compareTo(
            b.statusEnum.index,
          ),
        );
        break;

      case SortBy.title:
        list.sort(
              (a, b) => a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          ),
        );
        break;
    }
  }

  // =========================================================
  // REALTIME
  // =========================================================

  void _subscribeRealtime() {
    if (_disposed || isGuest) {
      return;
    }

    _projectsChannel = SupabaseService.client.channel(
      'projects_user_$_userId',
    );

    void scheduleRefresh() {
      _projectsRefreshDebounce?.cancel();

      _projectsRefreshDebounce = Timer(
        const Duration(milliseconds: 400),
            () {
          if (_disposed || isGuest) {
            return;
          }

          unawaited(
            fetchProjects(),
          );
        },
      );
    }

    _projectsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_members',
      callback: (_) {
        scheduleRefresh();
      },
    );

    _projectsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_attachments',
      callback: (_) {
        scheduleRefresh();
      },
    );

    _projectsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'projects',
      callback: (_) {
        scheduleRefresh();
      },
    );

    _projectsChannel!.subscribe(
          (status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          AppLogger.error(
            'Projects realtime error',
            error: error,
            tag: 'ProjectProvider',
          );
        }
      },
    );
  }

  void _subscribeMessagesRealtime() {
    if (_disposed || isGuest) {
      return;
    }

    _messagesChannel = SupabaseService.client.channel(
      'messages_user_$_userId',
    );

    _messagesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_messages',
      callback: (_) {
        _messagesRefreshDebounce?.cancel();

        _messagesRefreshDebounce = Timer(
          const Duration(milliseconds: 500),
              () {
            if (_disposed || isGuest) {
              return;
            }

            unawaited(
              fetchProjects(),
            );
          },
        );
      },
    );

    _messagesChannel!.subscribe(
          (status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          AppLogger.error(
            'Messages realtime error',
            error: error,
            tag: 'ProjectProvider',
          );
        }
      },
    );
  }

  void _subscribeTasksRealtime() {
    if (_disposed || isGuest) {
      return;
    }

    _tasksChannel = SupabaseService.client.channel(
      'tasks_user_$_userId',
    );

    _tasksChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_tasks',
      callback: (_) {
        _tasksRefreshDebounce?.cancel();

        _tasksRefreshDebounce = Timer(
          const Duration(milliseconds: 500),
              () async {
            if (_disposed || isGuest) {
              return;
            }

            await fetchProjects();
          },
        );
      },
    );

    _tasksChannel!.subscribe(
          (status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          AppLogger.error(
            'Tasks realtime error',
            error: error,
            tag: 'ProjectProvider',
          );
        }
      },
    );
  }

  void _subscribeInvitationsRealtime() {
    if (_disposed || isGuest) {
      return;
    }

    _invitationsChannel = SupabaseService.client.channel(
      'project_invitations_user_$_userId',
    );

    void scheduleRefresh() {
      _invitationsRefreshDebounce?.cancel();

      _invitationsRefreshDebounce = Timer(
        const Duration(milliseconds: 400),
            () async {
          if (_disposed || isGuest) {
            return;
          }

          await fetchPendingInvitations();
          await fetchProjects();
        },
      );
    }

    _invitationsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_invitations',
      callback: (_) {
        scheduleRefresh();
      },
    );

    _invitationsChannel!.subscribe(
          (status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          AppLogger.error(
            'Invitations realtime error',
            error: error,
            tag: 'ProjectProvider',
          );
        }
      },
    );
  }

  void _removeRealtime() {
    final projectsChannel = _projectsChannel;
    final messagesChannel = _messagesChannel;
    final tasksChannel = _tasksChannel;
    final invitationsChannel = _invitationsChannel;

    _projectsChannel = null;
    _messagesChannel = null;
    _tasksChannel = null;
    _invitationsChannel = null;

    if (projectsChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(
          projectsChannel,
        ),
      );
    }

    if (messagesChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(
          messagesChannel,
        ),
      );
    }

    if (tasksChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(
          tasksChannel,
        ),
      );
    }

    if (invitationsChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(
          invitationsChannel,
        ),
      );
    }
  }

  // =========================================================
  // COMPLETED CHECK / AUTO ARCHIVE
  // =========================================================

  Future<void> _checkCompletedProjects() async {
    if (isGuest) {
      return;
    }

    final snapshot = List<ProjectModel>.from(_projects);

    for (final project in snapshot) {
      if (_disposed || isGuest) {
        return;
      }

      final completed =
          project.totalTasks > 0 && project.completedTasks == project.totalTasks;

      if (!completed) {
        _completedShown.remove(project.id);
        _autoArchiveIgnoredProjectIds.remove(project.id);
        continue;
      }

      if (isArchivedProject(project)) {
        _completedShown.add(project.id);
        continue;
      }

      if (_autoArchiveIgnoredProjectIds.contains(project.id)) {
        continue;
      }

      if (!canEditProject(project)) {
        if (_completedShown.add(project.id)) {
          SnackbarManager.showSuccess(
            'projects.completed'.tr(
              namedArgs: {
                'title': project.title,
              },
            ),
          );
        }

        continue;
      }

      await _completeProjectAutomatically(project);
    }
  }

  Future<void> _completeProjectAutomatically(
      ProjectModel project,
      ) async {
    if (_disposed || isGuest) {
      return;
    }

    if (_autoCompletingProjectIds.contains(project.id)) {
      return;
    }

    _autoCompletingProjectIds.add(project.id);

    try {
      final current = _findProject(project.id) ?? project;

      if (current.statusEnum == ProjectStatus.completed ||
          current.statusEnum == ProjectStatus.archived) {
        return;
      }

      final stillCompleted =
          current.totalTasks > 0 && current.completedTasks == current.totalTasks;

      if (!stillCompleted) {
        return;
      }

      final updated = current.copyWith(
        status: ProjectStatus.completed.index,
      );

      await _service.update(updated);

      final fresh = await _service.getById(updated.id);

      final nextProject = fresh ?? updated;

      final index = _projects.indexWhere(
            (item) => item.id == nextProject.id,
      );

      if (index != -1) {
        _projects[index] = nextProject;
      } else {
        _projects.insert(0, nextProject);
      }

      _sort(_projects);

      _currentProjectId = nextProject.id;

      await _syncProjectDeadlineNotification(nextProject);

      _fixCurrentProject();

      if (_completedShown.add(nextProject.id)) {
        SnackbarManager.showSuccess(
          'projects.completed'.tr(
            namedArgs: {
              'title': nextProject.title,
            },
          ),
        );
      }

      _emitIfChanged();
    } catch (e, st) {
      AppLogger.error(
        'Automatic project completion failed',
        error: e,
        stackTrace: st,
        tag: 'ProjectProvider',
      );
    } finally {
      _autoCompletingProjectIds.remove(project.id);
    }
  }

  // =========================================================
  // EMIT / COMPARE
  // =========================================================

  void _emitIfChanged() {
    final sameProjects = _isSame(
      _projects,
      _lastEmitted,
    );

    final sameCurrentProject =
        _currentProjectId == _lastEmittedCurrentProjectId;

    if (sameProjects && sameCurrentProject) {
      return;
    }

    _lastEmitted = List<ProjectModel>.from(_projects);
    _lastEmittedCurrentProjectId = _currentProjectId;

    _safeNotify();
  }

  bool _isSame(
      List<ProjectModel> a,
      List<ProjectModel> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      final p1 = a[i];
      final p2 = b[i];

      final attachments1 = p1.attachments.map(_attachmentSignature).toList();

      final attachments2 = p2.attachments.map(_attachmentSignature).toList();

      final participants1 =
      p1.participantsData.map(_participantSignature).toList();

      final participants2 =
      p2.participantsData.map(_participantSignature).toList();

      if (p1.id != p2.id ||
          p1.ownerId != p2.ownerId ||
          p1.title != p2.title ||
          p1.description != p2.description ||
          p1.status != p2.status ||
          p1.color != p2.color ||
          p1.category != p2.category ||
          p1.maxMembers != p2.maxMembers ||
          p1.maxAttachments != p2.maxAttachments ||
          p1.gradingEnabled != p2.gradingEnabled ||
          p1.unreadCount != p2.unreadCount ||
          p1.lastMessage != p2.lastMessage ||
          p1.totalTasks != p2.totalTasks ||
          p1.completedTasks != p2.completedTasks ||
          p1.deadline.toIso8601String() != p2.deadline.toIso8601String() ||
          p1.createdAt.toIso8601String() != p2.createdAt.toIso8601String() ||
          p1.lastMessageAt?.toIso8601String() !=
              p2.lastMessageAt?.toIso8601String() ||
          !listEquals(attachments1, attachments2) ||
          !listEquals(participants1, participants2)) {
        return false;
      }
    }

    return true;
  }

  String _participantSignature(ProjectParticipant participant) {
    return [
      participant.id,
      participant.role.value,
      participant.fullName,
      participant.username ?? '',
      participant.avatarUrl ?? '',
    ].join('|');
  }

  String _attachmentSignature(Attachment attachment) {
    return [
      attachment.id,
      attachment.fileName,
      attachment.filePath,
      attachment.mimeType,
      attachment.fileSize.toString(),
      attachment.uploaderId,
      attachment.uploadedAt.toIso8601String(),
    ].join('|');
  }

  // =========================================================
  // STATE / ERROR
  // =========================================================

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;

    _safeNotify();
  }

  void _setInvitationsLoading(bool value) {
    if (_isInvitationsLoading == value) {
      return;
    }

    _isInvitationsLoading = value;

    _safeNotify();
  }

  void _denyGuest() {
    SnackbarManager.showError(
      'projects.operation_denied_guest'.tr(),
    );
  }

  void _denyPermission() {
    SnackbarManager.showError(
      'errors.no_permission'.tr(),
    );
  }

  void _handleError(
      Object e,
      StackTrace st,
      String operation,
      ) {
    AppLogger.error(
      'ProjectProvider ERROR in $operation',
      error: e,
      stackTrace: st,
      tag: 'ProjectProvider',
    );

    _errorMessage = ErrorMapper.map(e);

    SnackbarManager.showError(
      _errorMessage ?? 'errors.unknown'.tr(),
    );
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _disposed = true;

    _searchDebounce?.cancel();
    _messagesRefreshDebounce?.cancel();
    _projectsRefreshDebounce?.cancel();
    _tasksRefreshDebounce?.cancel();
    _invitationsRefreshDebounce?.cancel();

    _searchDebounce = null;
    _messagesRefreshDebounce = null;
    _projectsRefreshDebounce = null;
    _tasksRefreshDebounce = null;
    _invitationsRefreshDebounce = null;

    _completedShown.clear();
    _autoCompletingProjectIds.clear();
    _autoArchiveIgnoredProjectIds.clear();
    _pendingInvitations.clear();

    _removeRealtime();

    _projects.clear();
    _lastEmitted.clear();
    _lastEmittedCurrentProjectId = null;

    super.dispose();
  }
}