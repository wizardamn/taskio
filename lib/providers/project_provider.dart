import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/project_service.dart';

enum ProjectFilter { all, inProgressOnly }
enum SortBy { deadlineAsc, deadlineDesc, status }

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  bool isGuest = true;
  bool _isLoading = false;
  String? _errorMessage;

  String? _userId;
  String _currentUserName = 'Гость';

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;

  ProjectProvider(this._service);

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
      // Сортировка по возрастанию дедлайна (от старых к новым)
        result.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;
      case SortBy.deadlineDesc:
      // Сортировка по убыванию дедлайна (от новых к старым)
        result.sort((a, b) => b.deadline.compareTo(a.deadline));
        break;
      case SortBy.status:
      // Сортировка по индексу статуса (важно, чтобы ProjectStatus был правильно упорядочен)
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

  void updateUserName(String newName) {
    if (_currentUserName != newName) {
      _currentUserName = newName;
      notifyListeners();
    }
  }

  void clear({bool keepProjects = false}) {
    isGuest = true;
    _userId = null;
    _currentUserName = 'Гость';
    _service.updateOwner(null);
    _isLoading = false;
    _errorMessage = null;

    if (!keepProjects) {
      _projects.clear();
    }
    notifyListeners();
  }

  Future<void> fetchProjects() async {
    if (_userId == null || isGuest) {
      _projects.clear();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      debugPrint('ProjectProvider: fetchProjects отменено, пользователь - гость или ID отсутствует.');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    debugPrint('ProjectProvider: Начинаем загрузку проектов для ID: $_userId...');

    try {
      final loaded = await _service.getAll();
      _projects
        ..clear()
        ..addAll(loaded);

      debugPrint('ProjectProvider: Успешно загружено ${_projects.length} проектов.');

    } catch (e, st) {
      _projects.clear();
      // Оставляем логику извлечения первой части ошибки, так как это полезно для пользователя
      _errorMessage = 'Ошибка загрузки: ${e.toString().split(':')[0].trim()}';
      debugPrint("ProjectProvider ERROR: fetchProjects ошибка: $e\n$st");

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

  /// Добавление проекта. Предполагаем, что _service.add() возвращает полностью созданную модель.
  Future<ProjectModel?> addProject(ProjectModel p) async {
    if (isGuest || _userId == null) {
      _errorMessage = "guest_cannot_create_project".tr();
      notifyListeners();
      return null;
    }
    _errorMessage = null;

    try {
      // 1. Добавляем проект и получаем его финальную версию с серверным ID/таймстемпами
      final newProject = await _service.add(p);

      // 2. Обновляем локальный список
      _projects.add(newProject);
      notifyListeners();

      return newProject; // Возвращаем созданный проект

    } catch (e, st) {
      _handleCrudError(e, st, "addProject");
      return null;
    }
  }

  /// Обновление проекта. Используем _refreshSingle для гарантии синхронизации.
  Future<void> updateProject(ProjectModel p) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      // 1. Отправляем запрос на обновление
      await _service.update(p);

      // 2. Запрашиваем обновленный проект с сервера для полной синхронизации
      await _refreshSingle(p.id);

      // notifyListeners() вызывается внутри _refreshSingle

    } catch (e, st) {
      _handleCrudError(e, st, "updateProject");
    }
  }

  Future<void> deleteProject(String id) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      await _service.delete(id);

      _projects.removeWhere((p) => p.id == id);
      notifyListeners();

    } catch (e, st) {
      _handleCrudError(e, st, "deleteProject");
    }
  }

  bool canEditProject(ProjectModel project) {
    if (_userId == null) return false;
    // Нельзя редактировать завершенные проекты
    if (project.statusEnum == ProjectStatus.completed) return false;

    // Владелец может редактировать всегда (если не завершен)
    if (project.ownerId == _userId) return true;

    // Проверяем, является ли пользователь участником с ролью 'owner' или 'editor'
    final member = project.participantsData.firstWhere(
          (p) => p.id == _userId,
      orElse: () => ProjectParticipant(id: '', fullName: ''),
    );

    return member.id == _userId &&
        (member.role == 'owner' || member.role == 'editor');
  }

  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      // Это отдельный вызов, который не меняет основной список проектов, поэтому notifyListeners не требуется.
      return await _service.getParticipants(projectId);
    } catch (e) {
      debugPrint("getParticipants error: $e");
      return [];
    }
  }

  Future<void> addParticipant(String projectId, String userId) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;
    try {
      await _service.addParticipant(projectId, userId);
      // Обновляем проект после изменения списка участников
      await _refreshSingle(projectId);
    } catch (e, st) {
      _handleCrudError(e, st, "addParticipant");
    }
  }

  Future<void> removeParticipant(String projectId, String userId) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;
    try {
      await _service.removeParticipant(projectId, userId);
      // Обновляем проект после изменения списка участников
      await _refreshSingle(projectId);
    } catch (e, st) {
      _handleCrudError(e, st, "removeParticipant");
    }
  }

  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (isGuest || _userId == null) {
      throw Exception("operation_denied_guest".tr());
    }
    _errorMessage = null;

    try {
      // Сервис возвращает обновленную модель с новым списком вложений
      final updatedProject = await _service.uploadAttachment(projectId, file);

      // Обновляем локальный список
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      }
      notifyListeners();

      return updatedProject;
    } catch (e, st) {
      _handleCrudError(e, st, "uploadAttachment");
      rethrow;
    }
  }

  Future<void> deleteAttachment(String projectId, String filePath) async {
    if (isGuest || _userId == null) {
      _errorMessage = "operation_denied_guest".tr();
      notifyListeners();
      return;
    }
    _errorMessage = null;

    try {
      await _service.deleteAttachment(projectId, filePath);
      // Обновляем проект после удаления вложения
      await _refreshSingle(projectId);
    } catch (e, st) {
      _handleCrudError(e, st, "deleteAttachment");
    }
  }

  /// Запрашивает одну модель проекта с сервера и синхронизирует ее с локальным списком.
  Future<ProjectModel?> _refreshSingle(String projectId) async {
    try {
      final updated = await _service.getById(projectId);

      if (updated == null) {
        // Проект был удален на сервере
        _projects.removeWhere((p) => p.id == projectId);
        notifyListeners();
        return null;
      }

      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        // Проект найден, заменяем его обновленной версией
        _projects[index] = updated;
      } else {
        // Проект не найден, добавляем его (может быть после добавления или приглашения)
        _projects.add(updated);
      }
      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint("ProjectProvider ERROR: _refreshSingle ошибка: $e");
      // Не вызываем _handleCrudError здесь, чтобы не перезаписать основной _errorMessage
      return null;
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
      // Установка дедлайна, например, через 7 дней
      deadline: DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      grade: null,
      attachments: const [],
      participantsData: const [],
      participantIds: [_userId!],
      createdAt: DateTime.now(),
    );
  }

  void _handleCrudError(Object e, StackTrace st, String operation) {
    _errorMessage = 'Ошибка операции $operation: ${e.toString().split(':')[0].trim()}';
    debugPrint("ProjectProvider ERROR: $operation ошибка: $e\n$st");
    notifyListeners();
  }
}