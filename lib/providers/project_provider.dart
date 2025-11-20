import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// Убедитесь, что ProjectStatus доступен, возможно, из project_model.dart
import '../models/project_model.dart';
import '../services/project_service.dart';

enum ProjectFilter { all, inProgressOnly }
enum SortBy { deadlineAsc, deadlineDesc, status }

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  bool isGuest = true;
  // Сделаем приватными для контроля
  bool _isLoading = false;
  // Используем отдельное поле для ошибок CRUD, чтобы не конфликтовать с _isLoading
  String? _errorMessage;

  String? _userId;
  String _currentUserName = 'Гость';

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;

  ProjectProvider(this._service);

  // ------------------------------------------------
  // ✅ ГЕТТЕРЫ
  // ------------------------------------------------
  String get currentUserName => _currentUserName;
  bool get isLoading => _isLoading; // Геттер для состояния загрузки
  String? get errorMessage => _errorMessage; // Геттер для ошибок

  SortBy get currentSortBy => _sortBy;
  ProjectFilter get currentFilter => _filter;

  List<ProjectModel> get view {
    var result = [..._projects];

    // 1. Фильтрация
    if (_filter == ProjectFilter.inProgressOnly) {
      result = result.where((p) => p.statusEnum == ProjectStatus.inProgress).toList();
    }

    // 2. Сортировка
    switch (_sortBy) {
      case SortBy.deadlineAsc:
        result.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;
      case SortBy.deadlineDesc:
        result.sort((a, b) => b.deadline.compareTo(b.deadline));
        break;
      case SortBy.status:
      // Сортировка по индексу enum - надежный способ
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
    _currentUserName = userName;
    isGuest = false;

    // Сначала обновляем владельца в сервисе
    _service.updateOwner(_userId);
    // Затем загружаем проекты
    await fetchProjects();
    notifyListeners();
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
    _isLoading = false;
    _errorMessage = null; // Очищаем ошибки при выходе

    if (!keepProjects) {
      _projects.clear();
    }
    // Вызов notifyListeners обязателен, даже если _projects.clear() не вызывался,
    // чтобы обновить UI, связанный с авторизацией.
    notifyListeners();
  }

  // ------------------------------------------------
  // ✅ ЗАГРУЗКА ПРОЕКТОВ
  // ------------------------------------------------
  Future<void> fetchProjects() async {
    // Улучшенная guard clause
    if (_userId == null || isGuest) {
      _projects.clear();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      debugPrint('ProjectProvider: fetchProjects отменено, пользователь - гость или ID отсутствует.');
      return;
    }

    _isLoading = true;
    _errorMessage = null; // Сбрасываем ошибку перед новой попыткой
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
      // Улучшаем форматирование сообщения об ошибке
      _errorMessage = 'Ошибка загрузки: ${e.toString().split(':')[0].trim()}';
      debugPrint("ProjectProvider ERROR: fetchProjects ошибка: $e\n$st");

    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Добавляет проект. Возвращает сохраненную модель.
  Future<ProjectModel?> addProject(ProjectModel p) async {
    // Проверка _userId == null добавлена для полноты
    if (isGuest || _userId == null) return null;
    _errorMessage = null;

    try {
      // 1. Вызов сервиса.
      await _service.add(p);

      // 2. Запрашиваем актуальную версию проекта и обновляем локальный список.
      // Это необходимо, чтобы получить все серверные поля (createdAt, ID и т.д.).
      final updatedProject = await _refreshSingle(p.id);

      // 3. Возвращаем обновленную модель.
      return updatedProject;

    } catch (e, st) {
      _handleCrudError(e, st, "addProject");
      return null;
    }
  }

  /// Обновляет проект.
  Future<void> updateProject(ProjectModel p) async {
    // Проверка _userId == null добавлена для полноты
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      await _service.update(p);

      // Обновляем только локальный объект 'p'.
      final index = _projects.indexWhere((existing) => existing.id == p.id);
      if (index != -1) {
        _projects[index] = p;
      } else {
        debugPrint('ProjectProvider WARNING: Обновляемый проект с ID ${p.id} не найден в локальном списке. Добавляем его.');
        _projects.add(p); // Добавляем, если по какой-то причине его не было.
      }
      notifyListeners();

    } catch (e, st) {
      _handleCrudError(e, st, "updateProject");
    }
  }

  /// Удаляет проект.
  Future<void> deleteProject(String id) async {
    // Проверка _userId == null добавлена для полноты
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      await _service.delete(id);

      // Удаляем локально
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();

    } catch (e, st) {
      _handleCrudError(e, st, "deleteProject");
    }
  }

  // ------------------------------------------------
  // ✅ ПРАВА ДОСТУПА
  // ------------------------------------------------

  /// Проверяет, может ли текущий пользователь редактировать проект.
  /// Редактирование разрешено участнику проекта, если статус не "Завершен".
  bool canEditProject(ProjectModel project) {
    // Включаем проверку на _userId == null для полной безопасности.
    if (_userId == null) {
      return false;
    }

    // Нельзя редактировать завершенные проекты.
    if (project.statusEnum == ProjectStatus.completed) {
      return false;
    }

    // Редактирование разрешено, если пользователь является участником.
    return project.participantIds.contains(_userId!);
  }

  // ------------------------------------------------
  // ✅ УЧАСТНИКИ
  // ------------------------------------------------
  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      return await _service.getParticipants(projectId);
    } catch (e) {
      debugPrint("getParticipants error: $e");
      // Возвращаем пустой список вместо rethrow для более мягкой обработки в UI
      return [];
    }
  }

  Future<void> addParticipant(String projectId, String userId) async {
    // Проверка _userId == null добавлена для полноты
    if (isGuest || _userId == null) return;
    _errorMessage = null;
    try {
      await _service.addParticipant(projectId, userId);
      // Обновляем только этот проект
      await _refreshSingle(projectId);
    } catch (e, st) {
      _handleCrudError(e, st, "addParticipant");
    }
  }

  Future<void> removeParticipant(String projectId, String userId) async {
    // Проверка _userId == null добавлена для полноты
    if (isGuest || _userId == null) return;
    _errorMessage = null;
    try {
      await _service.removeParticipant(projectId, userId);
      // Обновляем только этот проект
      await _refreshSingle(projectId);
    } catch (e, st) {
      _handleCrudError(e, st, "removeParticipant");
    }
  }

  // ------------------------------------------------
  // ✅ ВЛОЖЕНИЯ (МЕТОДЫ ДЛЯ ProjectFormScreen)
  // ------------------------------------------------

  /// Загружает файл в хранилище и обновляет проект в базе данных.
  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (isGuest || _userId == null) {
      // Используем throw, а не return, так как метод возвращает ProjectModel
      throw Exception("operation_denied_guest".tr());
    }
    _errorMessage = null;

    try {
      final updatedProject = await _service.uploadAttachment(projectId, file);

      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      }
      notifyListeners();

      return updatedProject;
    } catch (e, st) {
      _handleCrudError(e, st, "uploadAttachment");
      rethrow; // Перебрасываем ошибку для обработки в UI
    }
  }

  /// Удаляет файл из хранилища и обновляет проект в базе данных.
  Future<void> deleteAttachment(String projectId, String filePath) async {
    if (isGuest || _userId == null) {
      // Гости не могут удалять вложения
      _errorMessage = "operation_denied_guest".tr();
      notifyListeners();
      return;
    }
    _errorMessage = null;

    try {
      await _service.deleteAttachment(projectId, filePath);

      // _refreshSingle обновит проект, удалив вложение из списка.
      await _refreshSingle(projectId);
    } catch (e, st) {
      _handleCrudError(e, st, "deleteAttachment");
    }
  }

  // ------------------------------------------------
  // ✅ ОБНОВЛЕНИЕ ОДНОГО ПРОЕКТА (Fetch from Service)
  // ------------------------------------------------
  /// Запрашивает актуальную версию проекта из сервиса и обновляет локальный список.
  Future<ProjectModel?> _refreshSingle(String projectId) async {
    try {
      final updated = await _service.getById(projectId);
      if (updated == null) {
        // Если проект не найден, удаляем его из локального списка (если он там был)
        _projects.removeWhere((p) => p.id == projectId);
        notifyListeners();
        return null;
      }

      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updated;
      } else {
        // Если проект не найден, добавляем его
        _projects.add(updated);
      }
      notifyListeners();
      return updated;
    } catch (e) {
      // Здесь не устанавливаем _errorMessage, так как это фоновое обновление.
      debugPrint("ProjectProvider ERROR: _refreshSingle ошибка: $e");
      return null;
    }
  }

  // ------------------------------------------------
  // ✅ СОЗДАНИЕ ПУСТОГО ПРОЕКТА
  // ------------------------------------------------
  ProjectModel createEmptyProject() {
    if (isGuest || _userId == null) {
      // Используем throw для ошибки
      throw Exception("guest_cannot_create_project".tr());
    }
    return ProjectModel(
      id: "",
      ownerId: _userId!,
      // Используем локализацию для названия по умолчанию
      title: "new_project".tr(),
      description: "",
      deadline: DateTime.now().add(const Duration(days: 7)),
      // Предполагаем, что ProjectStatus.planned доступен
      status: ProjectStatus.planned.index,
      grade: null,
      attachments: const [],

      participantsData: const [],
      // Владелец сразу добавляется в список участников
      participantIds: [_userId!],

      createdAt: DateTime.now(),
    );
  }

  // ------------------------------------------------
  // ✅ ОБРАБОТКА ОШИБОК CRUD
  // ------------------------------------------------
  /// Вспомогательный метод для обработки ошибок CRUD-операций.
  void _handleCrudError(Object e, StackTrace st, String operation) {
    // Устанавливаем сообщение об ошибке для отображения в UI
    _errorMessage = 'Ошибка операции $operation: ${e.toString().split(':')[0].trim()}';
    debugPrint("ProjectProvider ERROR: $operation ошибка: $e\n$st");
    notifyListeners();
  }
}