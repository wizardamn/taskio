import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/project_service.dart';
import '../services/notification_service.dart';

enum ProjectFilter { all, inProgressOnly, completedOnly }
enum SortBy { deadlineAsc, deadlineDesc, status, title }

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  bool isGuest = true;
  String? _userId;
  String _currentUserName = '';

  bool _isLoading = false;
  String? _errorMessage;

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;
  String _searchQuery = '';

  ProjectProvider(this._service);

  // --- Геттеры ---

  // Возвращает либо имя пользователя, либо переведенный ключ "guest"
  String get currentUserName => isGuest ? 'user_guest'.tr() : _currentUserName;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SortBy get currentSortBy => _sortBy;
  ProjectFilter get currentFilter => _filter;
  String get searchQuery => _searchQuery;

  List<ProjectModel> get view {
    var result = [..._projects];

    // 1. Поиск
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) =>
      p.title.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query)
      ).toList();
    }

    // 2. Фильтрация
    if (_filter == ProjectFilter.inProgressOnly) {
      result = result.where((p) => p.statusEnum == ProjectStatus.inProgress).toList();
    } else if (_filter == ProjectFilter.completedOnly) {
      result = result.where((p) => p.statusEnum == ProjectStatus.completed).toList();
    }

    // 3. Сортировка
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
      case SortBy.title:
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return result;
  }

  // --- Управление состоянием пользователя ---

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
    _currentUserName = '';
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
    _currentUserName = '';
    _service.updateOwner(null);
    _isLoading = false;
    _errorMessage = null;
    _searchQuery = '';
    if (!keepProjects) _projects.clear();
    notifyListeners();
  }

  // --- Загрузка данных ---

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
      _errorMessage = 'error_fetch_failed'.tr();
      debugPrint("ProjectProvider Fetch Error: $e\n$st");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Фильтры и поиск ---

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
        'notif_project_created_title'.tr(),
        'notif_project_created_body'.tr(args: [newProject.title]),
      );

      // Обновляем список, добавляя новый проект в начало
      // Мы можем использовать данные от сервиса, чтобы не делать лишний запрос
      _projects.insert(0, newProject);
      notifyListeners();

      return newProject;
    } catch (e, st) {
      _handleCrudError(e, st, "addProject");
      return null;
    }
  }

  Future<void> updateProject(ProjectModel p) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      await _service.update(p);
      await NotificationService().showSimple(
          'notif_project_updated_title'.tr(),
          'notif_project_updated_body'.tr()
      );

      // Локальное обновление
      final index = _projects.indexWhere((proj) => proj.id == p.id);
      if (index != -1) {
        _projects[index] = p;
        notifyListeners();
      } else {
        // Если почему-то проекта нет в списке, можно перезагрузить
        await fetchProjects();
      }
    } catch (e, st) {
      _handleCrudError(e, st, "updateProject");
    }
  }

  Future<void> deleteProject(String id) async {
    if (isGuest || _userId == null) return;
    try {
      final projectToDelete = _projects.firstWhere((p) => p.id == id, orElse: () => createEmptyProject());

      await _service.delete(id);

      if (projectToDelete.id.isNotEmpty) {
        await NotificationService().showSimple(
            'notif_project_deleted_title'.tr(),
            'notif_project_deleted_body'.tr(args: [projectToDelete.title])
        );
      }

      // Локальное удаление
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e, st) {
      _handleCrudError(e, st, "deleteProject");
    }
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
      // Здесь лучше перезагрузить, так как меняется вложенная структура
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

  // --- Вложения (Массовая загрузка) ---

  Future<ProjectModel> uploadAttachments({
    required String projectId,
    required List<String> fileNames,
    List<File>? files,
    List<Uint8List>? filesBytes,
  }) async {
    if (isGuest || _userId == null) throw Exception("operation_denied_guest".tr());

    try {
      _isLoading = true;
      notifyListeners();

      // Вызываем сервис для загрузки списка файлов
      final updatedProject = await _service.uploadAttachments(
          projectId: projectId,
          fileNames: fileNames,
          files: files,
          filesBytes: filesBytes
      );

      // Уведомление об успехе
      await NotificationService().showSimple(
          'notif_file_uploaded_title'.tr(),
          'notif_files_count'.tr(args: [fileNames.length.toString()])
      );

      // Обновляем локальную копию проекта в списке
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      } else {
        _projects.add(updatedProject);
      }

      _isLoading = false;
      notifyListeners();

      return updatedProject;
    } catch (e, st) {
      _isLoading = false;
      _handleCrudError(e, st, "uploadAttachments");
      rethrow;
    }
  }

  Future<void> deleteAttachment(String projectId, String filePath) async {
    if (isGuest || _userId == null) return;
    try {
      await _service.deleteAttachment(projectId, filePath);

      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        final current = _projects[index];
        // Создаем новый список вложений без удаленного файла
        final newAttachments = current.attachments.where((a) => a.filePath != filePath).toList();
        // Используем copyWith для обновления модели
        _projects[index] = current.copyWith(attachments: newAttachments);
      }

      notifyListeners();
    } catch (e, st) {
      _handleCrudError(e, st, "deleteAttachment");
    }
  }

  // --- Права доступа ---

  bool canEditProject(ProjectModel project) {
    if (isGuest || _userId == null) return false;
    if (project.ownerId == _userId) return true;
    if (project.statusEnum == ProjectStatus.completed) return false;

    final member = project.participantsData.firstWhere(
          (p) => p.id == _userId,
      orElse: () => ProjectParticipant(id: '', fullName: '', role: 'viewer'),
    );

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

  // --- Утилиты ---

  ProjectModel createEmptyProject() {
    if (isGuest || _userId == null) {
      throw Exception("guest_cannot_create_project".tr());
    }

    return ProjectModel(
      id: "",
      ownerId: _userId!,
      title: "new_project_placeholder".tr(),
      description: "",
      deadline: DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      grade: null,
      attachments: [],
      participantsData: [],
      participantIds: [_userId!],
      createdAt: DateTime.now(),
      color: '0xFF2196F3',
    );
  }

  void _handleCrudError(Object e, StackTrace st, String operation) {
    _errorMessage = 'error_operation_failed'.tr();
    debugPrint("ProjectProvider ERROR in $operation: $e\n$st");
    notifyListeners();
  }
}