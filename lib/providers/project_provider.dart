import 'dart:async';
import 'dart:io';

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

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service;

  ProjectProvider(this._service);

  String? _userId;
  String _currentUserName = '';

  bool _isLoading = false;
  bool _disposed = false;
  bool _fetchQueued = false;
  String? _errorMessage;

  String? _currentProjectId;

  final NotificationService _notifications =
  NotificationService();

  final Set<String> _completedShown = {};

  final List<ProjectModel> _projects = [];
  List<ProjectModel> _lastEmitted = [];

  SortBy _sortBy = SortBy.deadlineAsc;
  ProjectFilter _filter = ProjectFilter.all;
  DeadlineFilter _deadlineFilter = DeadlineFilter.all;

  String _searchQuery = '';

  Timer? _searchDebounce;
  Timer? _messagesRefreshDebounce;
  Timer? _projectsRefreshDebounce;
  Timer? _tasksRefreshDebounce;
  RealtimeChannel? _projectsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _tasksChannel;

  String? get currentProjectId => _currentProjectId;
  ProjectFilter get filter => _filter;
  SortBy get sortBy => _sortBy;
  DeadlineFilter get deadlineFilter => _deadlineFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isGuest => _userId == null;

  String get currentUserName {
    return _currentUserName.isEmpty
        ? 'profile.guest'.tr()
        : _currentUserName;
  }

  ProjectModel? get currentProject {
    if (_currentProjectId == null) return null;

    for (final p in _projects) {
      if (p.id == _currentProjectId) {
        return p;
      }
    }

    return null;
  }

  List<ProjectModel> get projects {
    var result = List<ProjectModel>.from(_projects);

    final now = DateTime.now();

    if (_deadlineFilter != DeadlineFilter.all) {
      result = result.where((p) {
        final d = p.deadline;

        switch (_deadlineFilter) {
          case DeadlineFilter.today:
            return d.year == now.year &&
                d.month == now.month &&
                d.day == now.day;

          case DeadlineFilter.week:
            return d.isAfter(now) &&
                d.isBefore(
                  now.add(const Duration(days: 7)),
                );

          case DeadlineFilter.overdue:
            return d.isBefore(now);

          case DeadlineFilter.all:
            return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();

      result = result.where((p) {
        final inTitle =
        p.title.toLowerCase().contains(q);

        final inDesc =
        p.description.toLowerCase().contains(q);

        final inParticipants = p.participantsData.any(
              (u) =>
              u.fullName.toLowerCase().contains(q),
        );

        final inFiles = p.attachments.any(
              (f) =>
              f.fileName.toLowerCase().contains(q),
        );

        return inTitle ||
            inDesc ||
            inParticipants ||
            inFiles;
      }).toList();
    }

    switch (_filter) {
      case ProjectFilter.inProgressOnly:
        result = result
            .where(
              (p) =>
          p.statusEnum ==
              ProjectStatus.inProgress,
        )
            .toList();
        break;

      case ProjectFilter.completedOnly:
        result = result
            .where(
              (p) =>
          p.statusEnum ==
              ProjectStatus.completed,
        )
            .toList();
        break;

      case ProjectFilter.all:
        break;
    }

    _sort(result);

    return result;
  }

  ProjectModel createEmptyProject() {
    if (_userId == null) {
      throw Exception(
        'projects.guest_cannot_create'.tr(),
      );
    }

    return ProjectModel.createEmpty(
      ownerId: _userId!,
    );
  }

  Future<void> setUser(
      String userId,
      String userName,
      ) async {
    _removeRealtime();

    _projects.clear();
    _lastEmitted.clear();
    _completedShown.clear();
    _currentProjectId = null;

    _userId = userId;
    _currentUserName = userName;

    _service.updateOwner(userId);

    await fetchProjects();

    _subscribeRealtime();
    _subscribeMessagesRealtime();
    _subscribeTasksRealtime();
  }

  void _subscribeMessagesRealtime() {
    if (_userId == null) return;


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
            fetchProjects();
          },
        );
      },
    );

    _messagesChannel!.subscribe();
  }

  void _subscribeTasksRealtime() {
    if (_userId == null) return;

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
            await fetchProjects();
            _checkCompletedProjects();
          },
        );
      },
    );

    _tasksChannel!.subscribe();
  }

  void _checkCompletedProjects() {
    for (final project in _projects) {
      final completed =
          project.totalTasks > 0 &&
              project.completedTasks == project.totalTasks;

      if (completed &&
          !_completedShown.contains(project.id)) {
        _completedShown.add(project.id);

        SnackbarManager.showSuccess(
          'projects.completed'.tr(
            namedArgs: {
              'title': project.title,
            },
          ),
        );
      }
    }
  }

  void setCurrentProject(String projectId) {
    if (_currentProjectId == projectId) return;

    _currentProjectId = projectId;

    notifyListeners();
  }

  Future<void> fetchProjects() async {
    if (_userId == null) return;

    if (_isLoading) {
      _fetchQueued = true;
      return;
    }

    try {
      _setLoading(true);

      final loaded = await _service.getAll();

      _sort(loaded);

      if (_isSame(loaded, _projects)) {
        return;
      }

      _projects
        ..clear()
        ..addAll(loaded);

      if (_projects.isEmpty) {
        _currentProjectId = null;
      } else {
        final exists = _projects.any(
              (p) => p.id == _currentProjectId,
        );

        if (!exists) {
          _currentProjectId = _projects.first.id;
        }
      }

      if (_projects.isNotEmpty) {
        await _notifications.scheduleProjects(_projects);
      }

      _checkCompletedProjects();

      _emitIfChanged();
    } catch (e, st) {
      _handleError(e, st, 'fetchProjects');
    } finally {
      _setLoading(false);

      if (_fetchQueued) {
        _fetchQueued = false;
        unawaited(fetchProjects());
      }
    }
  }

  void _subscribeRealtime() {
    if (_userId == null) return;

    _removeRealtime();

    _projectsChannel = SupabaseService.client.channel(
      'projects_user_$_userId',
    );

    void scheduleRefresh() {
      _projectsRefreshDebounce?.cancel();

      _projectsRefreshDebounce = Timer(
        const Duration(milliseconds: 400),
            () {
          if (_disposed) return;
          fetchProjects();
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

    _projectsChannel!.subscribe();
  }

  void _removeRealtime() {
    if (_projectsChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(_projectsChannel!),
      );

      _projectsChannel = null;
    }

    if (_messagesChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(_messagesChannel!),
      );

      _messagesChannel = null;
    }

    if (_tasksChannel != null) {
      unawaited(
        SupabaseService.client.removeChannel(_tasksChannel!),
      );

      _tasksChannel = null;
    }
  }

  /// Метод создания нового проекта.
  /// Выполняет проверку режима гостя, сохраняет проект в базе данных,
  /// обновляет локальный список проектов и создает уведомление о дедлайне.
  Future<ProjectModel?> addProject(
      ProjectModel project,
      ) async {
    // Проверка: гостевой пользователь не может создавать проекты
    if (isGuest) {
      _denyGuest();
      return null;
    }
    try {
      // Установка состояния загрузки для отображения индикатора в UI
      _setLoading(true);
      // Сохранение нового проекта через сервисный слой
      final created = await _service.add(project);
      // Добавление нового проекта в локальный список
      _projects.insert(0, created);
      // Сортировка списка проектов
      _sort(_projects);
      // Обновление пользовательского интерфейса
      _emitIfChanged();
      // Создание локального уведомления о сроке завершения проекта
      await NotificationService().scheduleProjectDeadline(
        projectId: created.id,
        title: created.title,
        deadline: created.deadline,
      );
      return created;
    } catch (e, st) {
      // Обработка ошибок при создании проекта
      _handleError(e, st, 'addProject');
      return null;
    } finally {
      // Снятие состояния загрузки
      _setLoading(false);
    }
  }

  /// Метод обновления существующего проекта.
  /// Проверяет права доступа пользователя, обновляет проект в базе данных
  /// и синхронизирует локальные данные.
  Future<void> updateProject(
      ProjectModel project,
      ) async {
    // Проверка гостевого режима
    if (isGuest) {
      debugPrint('UPDATE BLOCKED: guest');
      _denyGuest();
      return;
    }
    // Проверка прав на редактирование проекта
    if (!canEditProject(project)) {
      debugPrint('UPDATE BLOCKED: no permission');
      debugPrint('current user: $_userId');
      debugPrint('owner: ${project.ownerId}');
      debugPrint('participants: ${project.participantIds}');
      _denyGuest();
      return;
    }
    try {
      // Обновление проекта в базе данных
      await _service.update(project);
      // Получение актуальной версии проекта
      final fresh = await _service.getById(project.id);
      // Если проект не найден, выполняется полная перезагрузка списка
      if (fresh == null) {
        await fetchProjects();
        return;
      }
      // Поиск проекта в локальном списке
      final index = _projects.indexWhere(
            (p) => p.id == project.id,
      );
      // Обновление локальных данных
      if (index != -1) {
        _projects[index] = fresh;
        _emitIfChanged();
      }
      // Обновление уведомления о дедлайне
      await _notifications.scheduleProjectDeadline(
        projectId: fresh.id,
        title: fresh.title,
        deadline: fresh.deadline,
      );
    } catch (e, st) {
      // Обработка ошибок обновления
      _handleError(e, st, 'updateProject');
    }
  }

  /// Метод удаления проекта.
  /// Удаляет запись из базы данных, очищает локальный список
  /// и удаляет связанные уведомления.
  Future<void> deleteProject(String id) async {
    // Проверка гостевого режима
    if (isGuest) {
      _denyGuest();
      return;
    }
    try {
      // Удаление проекта из базы данных
      await _service.delete(id);
      // Удаление проекта из локального списка
      _projects.removeWhere(
            (p) => p.id == id,
      );
      // Обновление текущего выбранного проекта
      if (_currentProjectId == id) {
        _currentProjectId =
        _projects.isNotEmpty ? _projects.first.id : null;
      }
      // Обновление интерфейса
      _emitIfChanged();
      // Удаление уведомления
      await _notifications.cancel(id.hashCode);
    } catch (e, st) {
      // Обработка ошибок удаления
      _handleError(e, st, 'deleteProject');
    }
  }
  /// Проверка прав пользователя на редактирование проекта.
  /// Доступ разрешен владельцу проекта и редакторам.
  bool canEditProject(ProjectModel project) {
    // Если пользователь не авторизован
    if (_userId == null) return false;

    // Поиск текущего пользователя среди участников проекта
    for (final participant in project.participantsData) {
      if (participant.id != _userId) continue;

      // Проверка роли пользователя
      return participant.role == ProjectRole.owner ||
          participant.role == ProjectRole.editor;
    }
    return false;
  }

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

    try {
      final updated =
      await _service.uploadAttachments(
        projectId: projectId,
        fileNames: fileNames,
        files: files,
        filesBytes: filesBytes,
      );

      final index = _projects.indexWhere(
            (p) => p.id == projectId,
      );

      if (index != -1) {
        _projects[index] = updated;

        _emitIfChanged();
      }

      return updated;
    } catch (e, st) {
      _handleError(e, st, 'uploadAttachments');
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

    try {
      await _service.deleteAttachment(
        projectId,
        filePath,
      );

      final index = _projects.indexWhere(
            (p) => p.id == projectId,
      );

      if (index != -1) {
        final project = _projects[index];

        _projects[index] = project.copyWith(
          attachments: project.attachments
              .where(
                (a) => a.filePath != filePath,
          )
              .toList(),
        );

        _emitIfChanged();
      }
    } catch (e, st) {
      _handleError(e, st, 'deleteAttachment');
    }
  }

  void search(String query) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
          () {
        if (_disposed) return;

        _searchQuery = query.trim();

        notifyListeners();
      },
    );
  }

  void setSort(SortBy sortBy) {
    if (_sortBy == sortBy) return;

    _sortBy = sortBy;

    notifyListeners();
  }

  void setFilter(ProjectFilter filter) {
    if (_filter == filter) return;

    _filter = filter;

    notifyListeners();
  }

  void setDeadlineFilter(
      DeadlineFilter filter,
      ) {
    if (_deadlineFilter == filter) return;

    _deadlineFilter = filter;

    notifyListeners();
  }

  void resetFilters() {
    _filter = ProjectFilter.all;
    _deadlineFilter = DeadlineFilter.all;
    _sortBy = SortBy.deadlineAsc;
    _searchQuery = '';

    notifyListeners();
  }

  void clear({
    bool keepProjects = false,
  }) {
    _userId = null;
    _currentUserName = '';
    _errorMessage = null;
    _searchQuery = '';
    _currentProjectId = null;
    _completedShown.clear();
    _searchDebounce?.cancel();
    _messagesRefreshDebounce?.cancel();
    _tasksRefreshDebounce?.cancel();

    if (!keepProjects) {
      _projects.clear();
    }

    _lastEmitted.clear();

    _removeRealtime();

    unawaited(_notifications.cancelAll());

    _service.updateOwner(null);

    notifyListeners();
  }

  void _sort(List<ProjectModel> list) {
    switch (_sortBy) {
      case SortBy.deadlineAsc:
        list.sort(
              (a, b) =>
              a.deadline.compareTo(b.deadline),
        );
        break;

      case SortBy.deadlineDesc:
        list.sort(
              (a, b) =>
              b.deadline.compareTo(a.deadline),
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

  void _emitIfChanged() {
    if (_isSame(_projects, _lastEmitted)) {
      return;
    }

    _lastEmitted = List<ProjectModel>.from(
      _projects,
    );

    notifyListeners();
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

      final attachments1 =
      p1.attachments.map((e) => e.id).toList();

      final attachments2 =
      p2.attachments.map((e) => e.id).toList();

      final participants1 = p1.participantsData
          .map((e) => '${e.id}_${e.role.value}')
          .toList();

      final participants2 = p2.participantsData
          .map((e) => '${e.id}_${e.role.value}')
          .toList();

      if (
      p1.id != p2.id ||
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
          p1.deadline.toIso8601String() !=
              p2.deadline.toIso8601String() ||
          p1.createdAt.toIso8601String() !=
              p2.createdAt.toIso8601String() ||
          p1.lastMessageAt?.toIso8601String() !=
              p2.lastMessageAt?.toIso8601String() ||
          !listEquals(attachments1, attachments2) ||
          !listEquals(participants1, participants2)
      ) {
        return false;
      }
    }

    return true;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;

    _isLoading = value;

    notifyListeners();
  }

  void _denyGuest() {
    SnackbarManager.showError(
      'projects.operation_denied_guest'.tr());
  }

  void _handleError(
      Object e,
      StackTrace st,
      String operation,
      ) {
    AppLogger.error('ProjectProvider ERROR in $operation', error: e, stackTrace: st,);

    _errorMessage = ErrorMapper.map(e);

    SnackbarManager.showError(
      _errorMessage ?? 'errors.unknown'.tr());
  }

  @override
  void dispose() {
    _disposed = true;

    _searchDebounce?.cancel();
    _messagesRefreshDebounce?.cancel();
    _tasksRefreshDebounce?.cancel();
    _projectsRefreshDebounce?.cancel();

    _completedShown.clear();
    _removeRealtime();
    _projects.clear();
    _lastEmitted.clear();

    super.dispose();
  }
}