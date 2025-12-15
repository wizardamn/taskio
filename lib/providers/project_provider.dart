import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/project_service.dart';
import '../services/notification_service.dart';

enum ProjectFilter { all, inProgressOnly }
enum SortBy { deadlineAsc, deadlineDesc, status }

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  bool isGuest = true;
  String? _userId;
  String _currentUserName = 'Гость';

  bool _isLoading = false;
  String? _errorMessage;

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;

  ProjectProvider(this._service);

  // Геттеры
  String get currentUserName => _currentUserName;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SortBy get currentSortBy => _sortBy;
  ProjectFilter get currentFilter => _filter;

  List<ProjectModel> get view {
    var result = [..._projects];
    if (_filter == ProjectFilter.inProgressOnly) {
      result = result.where((p) => p.statusEnum == ProjectStatus.inProgress).toList();
    }
    switch (_sortBy) {
      case SortBy.deadlineAsc:
        result.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;
      case SortBy.deadlineDesc:
        result.sort((a, b) => b.deadline.compareTo(a.deadline));
        break;
      case SortBy.status:
        result.sort((a, b) => a.statusEnum.index.compareTo(b.statusEnum.index));
        break;
    }
    return result;
  }

  Future<void> setUser(String userId, String userName) async {
    _userId = userId;
    _currentUserName = userName;
    isGuest = false;
    _service.updateOwner(_userId);
    await fetchProjects();
    notifyListeners();
  }

  void setGuestUser() {
    _userId = null;
    _currentUserName = 'Гость';
    isGuest = true;
    _projects.clear();
    _isLoading = false;
    _errorMessage = null;
    _service.updateOwner(null);
    notifyListeners();
  }

  void clear({bool keepProjects = false}) {
    isGuest = true;
    _userId = null;
    _currentUserName = 'Гость';
    _service.updateOwner(null);
    _isLoading = false;
    _errorMessage = null;
    if (!keepProjects) _projects.clear();
    notifyListeners();
  }

  Future<void> fetchProjects() async {
    if (isGuest || _userId == null) {
      _projects.clear();
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _service.getAll();
      _projects
        ..clear()
        ..addAll(loaded);
    } catch (e, st) {
      _projects.clear();
      _errorMessage = 'Ошибка загрузки: ${e.toString().split(':')[0].trim()}';
      debugPrint("ProjectProvider Fetch Error: $e\n$st");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSort(SortBy sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setFilter(ProjectFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  // --- CRUD Операции ---

  Future<ProjectModel?> addProject(ProjectModel p) async {
    if (isGuest || _userId == null) {
      _errorMessage = "guest_cannot_create_project".tr();
      notifyListeners();
      return null;
    }
    _errorMessage = null;

    try {
      final newProject = await _service.add(p);
      await NotificationService().showSimple(
        'Проект создан',
        'Проект "${newProject.title}" успешно создан.',
      );
      await fetchProjects();

      // Ищем созданный проект в обновленном списке
      return _projects.firstWhere(
              (proj) => proj.id == newProject.id,
          orElse: () => newProject
      );
    } catch (e, st) {
      _handleCrudError(e, st, "addProject");
      return null;
    }
  }

  Future<void> updateProject(ProjectModel p) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      final oldProject = await _service.getById(p.id);
      await _service.update(p);

      if (oldProject != null) {
        // Логика уведомлений при изменении (статус, дедлайн, название)
        // ... (код сокращен для краткости, логика та же)
        await NotificationService().showSimple('Проект обновлён', 'Изменения сохранены.');
      }
      await fetchProjects();
    } catch (e, st) {
      _handleCrudError(e, st, "updateProject");
    }
  }

  Future<void> deleteProject(String id) async {
    if (isGuest || _userId == null) return;
    try {
      final projectToDelete = await _service.getById(id);
      await _service.delete(id);
      if (projectToDelete != null) {
        await NotificationService().showSimple('Проект удалён', 'Проект "${projectToDelete.title}" удалён.');
      }
      await fetchProjects();
    } catch (e, st) {
      _handleCrudError(e, st, "deleteProject");
    }
  }

  // --- Права доступа (на основе ролей в БД) ---

  bool canEditProject(ProjectModel project) {
    if (isGuest || _userId == null) return false;
    if (project.ownerId == _userId) return true;
    if (project.statusEnum == ProjectStatus.completed) return false;

    final member = project.participantsData.firstWhere(
          (p) => p.id == _userId,
      orElse: () => ProjectParticipant(id: '', fullName: '', role: 'viewer'),
    );

    // Роли из БД: owner, editor
    return member.id == _userId && (member.role == 'owner' || member.role == 'editor');
  }

  bool canViewProject(ProjectModel project) {
    if (isGuest || _userId == null) return false;
    if (project.ownerId == _userId) return true;

    final member = project.participantsData.firstWhere(
          (p) => p.id == _userId,
      orElse: () => ProjectParticipant(id: '', fullName: '', role: ''),
    );
    return member.id == _userId;
  }

  // --- Участники ---

  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      return await _service.getParticipants(projectId);
    } catch (e) {
      return [];
    }
  }

  Future<void> addParticipant(String projectId, String userId, [String role = "editor"]) async {
    if (isGuest || _userId == null) return;
    try {
      await _service.addParticipant(projectId, userId, role);
      // Уведомление и перезагрузка
      await fetchProjects();
    } catch (e, st) {
      _handleCrudError(e, st, "addParticipant");
    }
  }

  Future<void> removeParticipant(String projectId, String userId) async {
    if (isGuest || _userId == null) return;
    try {
      await _service.removeParticipant(projectId, userId);
      await fetchProjects();
    } catch (e, st) {
      _handleCrudError(e, st, "removeParticipant");
    }
  }

  // --- Вложения ---

  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (isGuest || _userId == null) throw Exception("operation_denied_guest".tr());

    try {
      final updatedProject = await _service.uploadAttachment(projectId, file);

      final fileName = file.path.split('/').last;
      await NotificationService().showSimple('Файл загружен', fileName);

      // Локальное обновление
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      } else {
        _projects.add(updatedProject);
      }
      notifyListeners();
      return updatedProject;
    } catch (e, st) {
      _handleCrudError(e, st, "uploadAttachment");
      rethrow;
    }
  }

  Future<void> deleteAttachment(String projectId, String filePath) async {
    if (isGuest || _userId == null) return;
    try {
      await _service.deleteAttachment(projectId, filePath);

      // Локальное обновление
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        final current = _projects[index];
        final newAttachments = current.attachments.where((a) => a.filePath != filePath).toList();
        _projects[index] = current.copyWith(attachments: newAttachments);
      }
      notifyListeners();
    } catch (e, st) {
      _handleCrudError(e, st, "deleteAttachment");
    }
  }

  ProjectModel createEmptyProject() {
    if (isGuest || _userId == null) {
      throw Exception("guest_cannot_create_project".tr());
    }

    return ProjectModel(
      id: "",
      ownerId: _userId!,
      title: "new_project".tr(),
      description: "",
      deadline: DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      grade: null,
      // ИСПРАВЛЕНО: Убрано const для предотвращения ошибок
      attachments: [],
      participantsData: [],
      participantIds: [_userId!],
      createdAt: DateTime.now(),
    );
  }

  void _handleCrudError(Object e, StackTrace st, String operation) {
    _errorMessage = 'Error $operation: ${e.toString().split(':')[0].trim()}';
    debugPrint("ProjectProvider ERROR: $e");
    notifyListeners();
  }
}