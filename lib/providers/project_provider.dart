import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/project_service.dart';
import '../services/notification_service.dart';

import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';
import '../utils/snackbar_manager.dart';
import '../utils/loading_overlay.dart';

enum ProjectFilter { all, inProgressOnly, completedOnly }
enum SortBy { deadlineAsc, deadlineDesc, status, title }

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  ProjectProvider(this._service);

  String? _userId;
  String _currentUserName = '';

  bool _isLoading = false;
  String? _errorMessage;

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;
  String _searchQuery = '';

// ==============================
// Create Empty Project
// ==============================

  ProjectModel createEmptyProject() {
    if (_userId == null) {
      throw Exception('projects.guest_cannot_create');
    }

    return ProjectModel.createEmpty(
      ownerId: _userId!,
    );
  }

  // ==============================
  // Getters
  // ==============================

  List<ProjectModel> get projects => List.unmodifiable(_projects);

  String get currentUserName =>
      _currentUserName.isEmpty
          ? 'profile.guest'.tr()
          : _currentUserName;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isGuest => _userId == null;

  // ==============================
  // VIEW
  // ==============================

  List<ProjectModel> get view {
    var result = [..._projects];

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) =>
      p.title.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query)
      ).toList();
    }

    if (_filter == ProjectFilter.inProgressOnly) {
      result = result
          .where((p) => p.statusEnum == ProjectStatus.inProgress)
          .toList();
    } else if (_filter == ProjectFilter.completedOnly) {
      result = result
          .where((p) => p.statusEnum == ProjectStatus.completed)
          .toList();
    }

    switch (_sortBy) {
      case SortBy.deadlineAsc:
        result.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;
      case SortBy.deadlineDesc:
        result.sort((a, b) => b.deadline.compareTo(a.deadline));
        break;
      case SortBy.status:
        result.sort((a, b) =>
            a.statusEnum.index.compareTo(b.statusEnum.index));
        break;
      case SortBy.title:
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
    }

    return result;
  }

  // ==============================
  // User State
  // ==============================

  Future<void> setUser(String userId, String userName) async {
    _userId = userId;
    _currentUserName = userName;

    _service.updateOwner(userId);

    await fetchProjects();
  }

  void clear({bool keepProjects = false}) {
    _userId = null;
    _currentUserName = '';
    _errorMessage = null;
    _searchQuery = '';

    if (!keepProjects) {
      _projects.clear();
    }

    _service.updateOwner(null);
    notifyListeners();
  }

  // ==============================
  // Fetch
  // ==============================

  Future<void> fetchProjects() async {
    if (_userId == null) {
      _projects.clear();
      notifyListeners();
      return;
    }

    if (_isLoading) return;

    try {
      _setLoading(true);

      final loaded = await _service.getAll();

      _projects
        ..clear()
        ..addAll(loaded);

    } catch (e, st) {
      _handleError(e, st, 'fetchProjects');
    } finally {
      _setLoading(false);
    }
  }

  Future<ProjectModel?> fetchProjectById(String id) async {
    try {
      return await _service.getById(id);
    } catch (e, st) {
      _handleError(e, st, 'fetchProjectById');
      return null;
    }
  }

  // ==============================
  // Search / Sort / Filter
  // ==============================

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSort(SortBy sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setFilter(ProjectFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  // ==============================
  // Permissions
  // ==============================

  bool canEditProject(ProjectModel project) {
    return _userId != null && project.ownerId == _userId;
  }

  void _denyGuest() {
    SnackbarManager.showError(
      'projects.operation_denied_guest'.tr(),
    );
  }

  // ==============================
  // CRUD
  // ==============================

  Future<ProjectModel?> addProject(ProjectModel p) async {
    if (isGuest) {
      _denyGuest();
      return null;
    }

    try {
      _setLoading(true);

      final newProject = await _service.add(p);

      _projects.insert(0, newProject);

      SnackbarManager.showSuccess(
        'projects.created_success'.tr(),
      );

      await NotificationService().showSimple(
        'notifications.project_created_title'.tr(),
        newProject.title,
      );

      return newProject;
    } catch (e, st) {
      _handleError(e, st, 'addProject');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProject(ProjectModel p) async {
    if (isGuest || !canEditProject(p)) {
      _denyGuest();
      return;
    }

    try {
      _setLoading(true);

      await _service.update(p);

      final index =
      _projects.indexWhere((proj) => proj.id == p.id);

      if (index != -1) {
        _projects[index] = p;
      }

      SnackbarManager.showSuccess(
        'projects.updated_success'.tr(),
      );
    } catch (e, st) {
      _handleError(e, st, 'updateProject');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteProject(String id) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    try {
      _setLoading(true);

      await _service.delete(id);

      _projects.removeWhere((p) => p.id == id);

      SnackbarManager.showSuccess(
        'projects.deleted_success'.tr(),
      );
    } catch (e, st) {
      _handleError(e, st, 'deleteProject');
    } finally {
      _setLoading(false);
    }
  }

  // ==============================
  // Attachments
  // ==============================

  Future<ProjectModel> uploadAttachments({
    required String projectId,
    required List<String> fileNames,
    List<File>? files,
    List<Uint8List>? filesBytes,
  }) async {
    if (isGuest) {
      _denyGuest();
      throw Exception('Guest cannot upload');
    }

    try {
      _setLoading(true);

      final updated = await _service.uploadAttachments(
        projectId: projectId,
        fileNames: fileNames,
        files: files,
        filesBytes: filesBytes,
      );

      final index =
      _projects.indexWhere((p) => p.id == projectId);

      if (index != -1) {
        _projects[index] = updated;
      }

      SnackbarManager.showSuccess(
        'attachments.file_added'.tr(),
      );

      return updated;
    } catch (e, st) {
      _handleError(e, st, 'uploadAttachments');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAttachment(
      String projectId,
      String filePath,
      ) async {
    if (isGuest) {
      _denyGuest();
      return;
    }

    try {
      _setLoading(true);

      await _service.deleteAttachment(projectId, filePath);

      final index =
      _projects.indexWhere((p) => p.id == projectId);

      if (index != -1) {
        final project = _projects[index];

        _projects[index] = project.copyWith(
          attachments: project.attachments
              .where((a) => a.filePath != filePath)
              .toList(),
        );
      }

      SnackbarManager.showSuccess(
        'attachments.delete_success'.tr(),
      );
    } catch (e, st) {
      _handleError(e, st, 'deleteAttachment');
    } finally {
      _setLoading(false);
    }
  }

  // ==============================
  // Helpers
  // ==============================

  void _setLoading(bool value) {
    if (_isLoading == value) return;

    _isLoading = value;

    if (value) {
      LoadingOverlay.show();
    } else {
      LoadingOverlay.hide();
    }

    notifyListeners();
  }

  void _handleError(
      Object e,
      StackTrace st,
      String operation,
      ) {
    AppLogger.error(
        'ProjectProvider ERROR in $operation', e);
    AppLogger.error('StackTrace', st);

    _errorMessage = ErrorMapper.map(e);

    SnackbarManager.showError(
        _errorMessage ?? 'errors.unknown'.tr());
  }
}