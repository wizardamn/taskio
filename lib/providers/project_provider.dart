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
  bool isLoading = false;

  String? _userId;
  String _currentUserName = 'Гость';

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;

  ProjectProvider(this._service) {
    // Конструктор остается пустым, вся инициализация в setUser
  }

  // ------------------------------------------------
  // ✅ ГЕТТЕРЫ
  // ------------------------------------------------
  String get currentUserName => _currentUserName;
  List<ProjectModel> get view {
    var result = [..._projects];
    if (_filter == ProjectFilter.inProgressOnly) {
      result =
          result.where((p) => p.statusEnum == ProjectStatus.inProgress).toList();
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

  // ------------------------------------------------
  // ✅ ИНИЦИАЛИЗАЦИЯ (Вызывается из LoginWrapper)
  // ------------------------------------------------
  Future<void> setUser(String userId, String userName) async {
    _userId = userId;
    _currentUserName = userName; // Устанавливаем имя
    isGuest = false;

    _service.updateOwner(_userId);
    await fetchProjects(); // Загружаем проекты сразу
    notifyListeners(); // Уведомляем UI, что мы больше не гость
  }

  // Вызывается из ProfileScreen
  void updateUserName(String newName) {
    if (_currentUserName != newName) {
      _currentUserName = newName;
      notifyListeners();
    }
  }

  // Вызывается из LoginWrapper при выходе
  void clear({bool keepProjects = false}) {
    isGuest = true;
    _userId = null;
    _currentUserName = 'Гость';
    _service.updateOwner(null);

    if (!keepProjects) {
      _projects.clear();
    }
    notifyListeners();
  }

  // ------------------------------------------------
  // ✅ ЗАГРУЗКА ПРОЕКТОВ
  // ------------------------------------------------
  Future<void> fetchProjects() async {
    if (isGuest || _userId == null) {
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      final loaded = await _service.getAll();
      _projects.clear();
      _projects.addAll(loaded);
    } catch (e, st) {
      debugPrint("fetchProjects error: $e\n$st");
      _projects.clear();
    }
    isLoading = false;
    notifyListeners();
  }

  // ------------------------------------------------
  // ✅ СОРТИРОВКА И ФИЛЬТР
  // ------------------------------------------------
  void setSort(SortBy sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setFilter(ProjectFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  // ------------------------------------------------
  // ✅ CRUD
  // ------------------------------------------------
  Future<void> addProject(ProjectModel p) async {
    if (isGuest) return;
    await _service.add(p);
    await fetchProjects();
  }

  Future<void> updateProject(ProjectModel p) async {
    if (isGuest) return;
    await _service.update(p);
    await fetchProjects();
  }

  Future<void> deleteProject(String id) async {
    if (isGuest) return;
    await _service.delete(id);
    await fetchProjects();
  }

  // ------------------------------------------------
  // ✅ УЧАСТНИКИ
  // ------------------------------------------------
  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      return await _service.getParticipants(projectId);
    } catch (e) {
      debugPrint("getParticipants error: $e");
      return [];
    }
  }

  Future<void> addParticipant(String projectId, String userId) async {
    if (isGuest) return;
    await _service.addParticipant(projectId, userId);
    await _refreshSingle(projectId);
  }

  Future<void> removeParticipant(String projectId, String userId) async {
    if (isGuest) return;
    await _service.removeParticipant(projectId, userId);
    await _refreshSingle(projectId);
  }

  // ------------------------------------------------
  // ✅ ВЛОЖЕНИЯ (МЕТОДЫ ДЛЯ ProjectFormScreen)
  // ------------------------------------------------

  /// Загружает файл в хранилище и обновляет проект в базе данных.
  /// Требует, чтобы ProjectService имел метод uploadAttachment.
  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (isGuest || _userId == null) {
      // Бросаем исключение, поскольку ProjectFormScreen ожидает ProjectModel или ошибку.
      throw Exception("operation_denied_guest".tr());
    }

    // 1. Делегируем работу сервису (загрузка файла + обновление проекта в БД)
    final updatedProject = await _service.uploadAttachment(projectId, file);

    // 2. Обновляем локальный список _projects
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index != -1) {
      _projects[index] = updatedProject;
      notifyListeners();
    }

    // 3. Возвращаем обновленную модель для ProjectFormScreen
    return updatedProject;
  }

  /// Удаляет файл из хранилища и обновляет проект в базе данных.
  /// Требует, чтобы ProjectService имел метод deleteAttachment.
  Future<void> deleteAttachment(String projectId, String filePath) async {
    if (isGuest || _userId == null) {
      return; // Гости не могут удалять вложения
    }

    // 1. Делегируем работу сервису (удаление файла + обновление проекта в БД)
    await _service.deleteAttachment(projectId, filePath);

    // 2. Обновляем проект после удаления вложения.
    await _refreshSingle(projectId);
  }

  // ------------------------------------------------
  // ✅ ОБНОВЛЕНИЕ ОДНОГО ПРОЕКТА
  // ------------------------------------------------
  Future<void> _refreshSingle(String projectId) async {
    try {
      final updated = await _service.getById(projectId);
      if (updated == null) return;
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("_refreshSingle error: $e");
    }
  }

  // ------------------------------------------------
  // ✅ СОЗДАНИЕ ПУСТОГО ПРОЕКТА
  // ------------------------------------------------
  ProjectModel createEmptyProject() {
    if (isGuest || _userId == null) {
      // Используем локализацию для сообщения об ошибке
      throw Exception("guest_cannot_create_project".tr());
    }
    return ProjectModel(
      id: "",
      ownerId: _userId!,
      // Используем локализацию для названия по умолчанию
      title: "new_project".tr(),
      description: "",
      deadline: DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      grade: null,
      attachments: const [],
      participants: [_userId!],
      createdAt: DateTime.now(),
    );
  }
}