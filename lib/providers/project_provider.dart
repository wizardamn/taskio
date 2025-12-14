import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/project_service.dart';
import '../services/notification_service.dart'; // <-- ИМПОРТ NotificationService

enum ProjectFilter { all, inProgressOnly }
enum SortBy { deadlineAsc, deadlineDesc, status }

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  // --- Состояние пользователя ---
  bool isGuest = true; // <-- Используется как индикатор гостевого режима
  String? _userId;
  String _currentUserName = 'Гость';
  // --- Конец состояния пользователя ---

  bool _isLoading = false;
  String? _errorMessage;

  final List<ProjectModel> _projects = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;

  ProjectProvider(this._service);

  // --- Геттеры ---
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
  // --- Конец геттеров ---

  // --- Управление состоянием пользователя ---
  /// Устанавливает данные авторизованного пользователя
  Future<void> setUser(String userId, String userName) async {
    _userId = userId;
    _currentUserName = userName;
    isGuest = false; // <-- Сбрасываем флаг гостя

    _service.updateOwner(_userId);
    await fetchProjects(); // <-- Загружаем проекты для нового пользователя
    notifyListeners(); // <-- Уведомляем об изменении состояния пользователя
  }

  /// Устанавливает состояние гостя
  void setGuestUser() {
    _userId = null;
    _currentUserName = 'Гость';
    isGuest = true; // <-- Устанавливаем флаг гостя
    _projects.clear(); // <-- Очищаем список проектов
    _isLoading = false;
    _errorMessage = null;
    _service.updateOwner(null); // <-- Убираем владельца у сервиса
    notifyListeners(); // <-- Уведомляем об изменении состояния пользователя
  }

  /// Обновляет имя пользователя
  void updateUserName(String newName) {
    if (_currentUserName != newName) {
      _currentUserName = newName;
      notifyListeners();
    }
  }

  /// Сбрасывает все данные провайдера
  void clear({bool keepProjects = false}) {
    isGuest = true; // <-- Сбрасываем флаг гостя
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
  // --- Конец управления состоянием пользователя ---

  /// Загружает проекты для текущего пользователя (если не гость)
  Future<void> fetchProjects() async {
    if (isGuest || _userId == null) {
      _projects.clear();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      debugPrint('ProjectProvider: fetchProjects отменено, пользователь - гость или ID отсутствует.');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // <-- Уведомляем об начале загрузки
    debugPrint('ProjectProvider: Начинаем загрузку проектов для ID: $_userId...');

    try {
      final loaded = await _service.getAll();
      _projects
        ..clear()
        ..addAll(loaded);

      debugPrint('ProjectProvider: Успешно загружено ${_projects.length} проектов.');

    } catch (e, st) {
      _projects.clear();
      _errorMessage = 'Ошибка загрузки: ${e.toString().split(':')[0].trim()}';
      debugPrint("ProjectProvider ERROR: fetchProjects ошибка: $e\n$st");

    } finally {
      _isLoading = false;
      notifyListeners(); // <-- Уведомляем о завершении загрузки (успешной или с ошибкой)
    }
  }

  // --- Сортировка и фильтрация ---
  void setSort(SortBy sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setFilter(ProjectFilter filter) {
    _filter = filter;
    notifyListeners();
  }
  // --- Конец сортировки и фильтрации ---

  /// Добавляет проект (доступно только авторизованным пользователям)
  Future<ProjectModel?> addProject(ProjectModel p) async {
    if (isGuest || _userId == null) {
      _errorMessage = "guest_cannot_create_project".tr();
      notifyListeners();
      return null;
    }
    _errorMessage = null;

    try {
      final newProject = await _service.add(p);

      // --- НОВОЕ: Отправка уведомления о создании ---
      await NotificationService().showSimple(
        'Проект создан',
        'Проект "${newProject.title}" успешно создан.',
      );
      // --- КОНЕЦ НОВОГО ---

      // НЕ обновляем локальный список _projects напрямую
      // Вместо этого, перезагружаем всё, чтобы гарантировать синхронизацию с базой данных
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ВСЕХ ПРОЕКТОВ ПОСЛЕ ДОБАВЛЕНИЯ

      // Возвращаем обновленный проект (тот, что загружен из базы)
      final createdProject = _projects.firstWhere((proj) => proj.id == newProject.id, orElse: () => newProject);
      return createdProject;

    } catch (e, st) {
      _handleCrudError(e, st, "addProject");
      return null;
    }
  }

  /// Обновляет проект (доступно только авторизованным пользователям)
  Future<void> updateProject(ProjectModel p) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    try {
      // --- НОВОЕ: Получаем старый проект для сравнения ---
      final oldProject = await _service.getById(p.id);
      // --- КОНЕЦ НОВОГО ---

      await _service.update(p);

      // --- НОВОЕ: Отправка уведомления об изменении ---
      if (oldProject != null) {
        String notificationTitle = 'Проект обновлён';
        String notificationBody = 'Проект "${p.title}" был изменён.';

        if (oldProject.status != p.status) {
          notificationBody += ' Статус изменён с "${oldProject.statusEnum.text}" на "${p.statusEnum.text}".';
        }
        if (oldProject.deadline != p.deadline) {
          notificationBody += ' Дедлайн изменён с "${DateFormat('dd.MM.yyyy HH:mm').format(oldProject.deadline)}" на "${DateFormat('dd.MM.yyyy HH:mm').format(p.deadline)}".';
        }
        if (oldProject.title != p.title) {
          notificationTitle = 'Проект переименован';
          notificationBody = 'Проект "${oldProject.title}" переименован в "${p.title}".';
        }

        await NotificationService().showSimple(notificationTitle, notificationBody);
      }
      // --- КОНЕЦ НОВОГО ---

      // НЕ обновляем локальный список _projects напрямую
      // Вместо этого, перезагружаем всё, чтобы гарантировать синхронизацию с базой данных
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ВСЕХ ПРОЕКТОВ ПОСЛЕ ОБНОВЛЕНИЯ

    } catch (e, st) {
      _handleCrudError(e, st, "updateProject");
    }
  }

  /// Удаляет проект (доступно только авторизованным пользователям)
  Future<void> deleteProject(String id) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;

    // --- НОВОЕ: Получаем проект перед удалением для уведомления ---
    final projectToDelete = await _service.getById(id);
    // --- КОНЕЦ НОВОГО ---

    try {
      await _service.delete(id);

      // --- НОВОЕ: Отправка уведомления об удалении ---
      if (projectToDelete != null) {
        await NotificationService().showSimple(
          'Проект удалён',
          'Проект "${projectToDelete.title}" был успешно удалён.',
        );
      }
      // --- КОНЕЦ НОВОГО ---

      // НЕ удаляем локально из _projects
      // Вместо этого, перезагружаем всё, чтобы гарантировать синхронизацию с базой данных
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ВСЕХ ПРОЕКТОВ ПОСЛЕ УДАЛЕНИЯ

    } catch (e, st) {
      _handleCrudError(e, st, "deleteProject");
    }
  }

  /// Проверяет, может ли текущий пользователь редактировать проект
  bool canEditProject(ProjectModel project) {
    if (isGuest || _userId == null) return false;

    // Владелец всегда может редактировать
    if (project.ownerId == _userId) return true;

    // Нельзя редактировать завершенные проекты, если не владелец
    if (project.statusEnum == ProjectStatus.completed) return false;

    // Проверяем, является ли пользователь участником с ролью 'owner' или 'editor'
    final member = project.participantsData.firstWhere(
          (p) => p.id == _userId,
      orElse: () => ProjectParticipant(id: '', fullName: '', role: 'viewer'), // <-- ИСПРАВЛЕНО: Возвращаем заглушку с ролью
    );

    // --- ИСПРАВЛЕНО: Проверка роли ---
    return member.id == _userId && (member.role == 'owner' || member.role == 'editor');
  }

  /// Проверяет, может ли текущий пользователь просматривать проект (учитывая, что он участник)
  bool canViewProject(ProjectModel project) {
    if (isGuest || _userId == null) return false;

    // Владелец всегда может просматривать
    if (project.ownerId == _userId) return true;

    // Проверяем, является ли пользователь участником (любой роли)
    final member = project.participantsData.firstWhere(
          (p) => p.id == _userId,
      orElse: () => ProjectParticipant(id: '', fullName: '', role: ''), // <-- ИСПРАВЛЕНО: Возвращаем заглушку с ролью
    );

    // --- ИСПРАВЛЕНО: Проверка участия ---
    return member.id == _userId;
  }

  // --- Управление участниками (доступно только авторизованным пользователям) ---
  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      return await _service.getParticipants(projectId);
    } catch (e) {
      debugPrint("getParticipants error: $e");
      return [];
    }
  }

  Future<void> addParticipant(String projectId, String userId, [String role = "editor"]) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;
    try {
      await _service.addParticipant(projectId, userId, role);

      // --- НОВОЕ: Отправка уведомления о добавлении участника ---
      final project = await _service.getById(projectId);
      if (project != null) {
        final newMember = project.participantsData.firstWhere(
              (p) => p.id == userId,
          orElse: () => ProjectParticipant(id: '', fullName: 'Неизвестный', role: 'viewer'), // <-- ИСПРАВЛЕНО: Возвращаем заглушку с ролью
        );
        await NotificationService().showSimple(
          'Участник добавлен',
          'Пользователь "${newMember.fullName}" добавлен в проект "${project.title}".',
        );
      }
      // --- КОНЕЦ НОВОГО ---

      // Обновляем проект после изменения списка участников
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ПРОЕКТОВ ПОСЛЕ ДОБАВЛЕНИЯ УЧАСТНИКА
    } catch (e, st) {
      _handleCrudError(e, st, "addParticipant");
    }
  }

  Future<void> removeParticipant(String projectId, String userId) async {
    if (isGuest || _userId == null) return;
    _errorMessage = null;
    try {
      await _service.removeParticipant(projectId, userId);

      // --- НОВОЕ: Отправка уведомления об удалении участника ---
      final project = await _service.getById(projectId);
      if (project != null) {
        await NotificationService().showSimple(
          'Участник удалён',
          'Пользователь "$userId" удален из проекта "${project.title}".',
        );
      }
      // --- КОНЕЦ НОВОГО ---

      // Обновляем проект после изменения списка участников
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ПРОЕКТОВ ПОСЛЕ УДАЛЕНИЯ УЧАСТНИКА
    } catch (e, st) {
      _handleCrudError(e, st, "removeParticipant");
    }
  }
  // --- Конец управления участниками ---

  // --- Управление вложениями (доступно только авторизованным пользователям) ---
  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (isGuest || _userId == null) {
      throw Exception("operation_denied_guest".tr());
    }
    _errorMessage = null;

    try {
      final updatedProject = await _service.uploadAttachment(projectId, file);

      // --- НОВОЕ: Отправка уведомления о загрузке вложения ---
      final fileName = file.path.split('/').last;
      await NotificationService().showSimple(
        'Файл загружен',
        'Файл "$fileName" добавлен к проекту "${updatedProject.title}".',
      );
      // --- КОНЕЦ НОВОГО ---

      // НЕ обновляем локальный список _projects напрямую
      // Вместо этого, перезагружаем всё, чтобы гарантировать синхронизацию с базой данных
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ПРОЕКТОВ ПОСЛЕ ЗАГРУЗКИ ВЛОЖЕНИЯ

      // Возвращаем обновленный проект (тот, что загружен из базы)
      final projectWithNewAttachment = _projects.firstWhere((proj) => proj.id == projectId, orElse: () => updatedProject);
      return projectWithNewAttachment;
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

      // --- НОВОЕ: Отправка уведомления об удалении вложения ---
      final fileName = filePath.split('/').last;
      await NotificationService().showSimple(
        'Файл удалён',
        'Файл "$fileName" удален из проекта "$projectId".',
      );
      // --- КОНЕЦ НОВОГО ---

      // Обновляем проект после удаления вложения
      await fetchProjects(); // <-- ПЕРЕЗАГРУЗКА ПРОЕКТОВ ПОСЛЕ УДАЛЕНИЯ ВЛОЖЕНИЯ
    } catch (e, st) {
      _handleCrudError(e, st, "deleteAttachment");
    }
  }
  // --- Конец управления вложениями ---

  /// Создаёт пустую модель проекта для заполнения в форме
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
      attachments: const [],
      participantsData: const [],
      participantIds: [_userId!],
      createdAt: DateTime.now(),
    );
  }

  /// Обрабатывает ошибки CRUD-операций
  void _handleCrudError(Object e, StackTrace st, String operation) {
    _errorMessage = 'Ошибка операции $operation: ${e.toString().split(':')[0].trim()}';
    debugPrint("ProjectProvider ERROR: $operation ошибка: $e\n$st");
    notifyListeners();
  }
}