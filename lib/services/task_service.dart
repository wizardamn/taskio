import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_model.dart';
import '../utils/app_logger.dart';
import 'supabase_service.dart';

class TaskService {
  final SupabaseClient _client = SupabaseService.client;

  static const String _tasksTable = 'project_tasks';

  static const String _taskSelect = '''
    id,
    project_id,
    title,
    is_completed,
    created_at
  ''';

  final Map<String, List<TaskModel>> _cache = {};
  final Map<String, StreamController<List<TaskModel>>> _controllers = {};
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Timer> _disposeTimers = {};
  final Map<String, Timer> _refreshDebounce = {};

  final Set<String> _initializing = {};
  final Set<String> _disposing = {};

  // =========================================================
  // STREAM
  // =========================================================

  Stream<List<TaskModel>> getTasksStream(String projectId) {
    final cleanProjectId = projectId.trim();

    if (cleanProjectId.isEmpty) {
      return const Stream.empty();
    }

    _disposing.remove(cleanProjectId);
    _disposeTimers.remove(cleanProjectId)?.cancel();

    final existingController = _controllers[cleanProjectId];

    if (existingController != null && !existingController.isClosed) {
      if (_cache.containsKey(cleanProjectId)) {
        unawaited(_emitAsync(cleanProjectId));
      } else {
        unawaited(_loadInitial(cleanProjectId));
      }

      return existingController.stream;
    }

    AppLogger.info(
      'INIT task stream: $cleanProjectId',
      tag: 'TaskService',
    );

    late final StreamController<List<TaskModel>> controller;

    controller = StreamController<List<TaskModel>>.broadcast(
      onListen: () {
        _disposeTimers.remove(cleanProjectId)?.cancel();

        if (!_cache.containsKey(cleanProjectId)) {
          unawaited(_init(cleanProjectId));
        } else {
          unawaited(_emitAsync(cleanProjectId));
          _subscribeRealtime(cleanProjectId);
        }
      },
      onCancel: () {
        _scheduleDispose(cleanProjectId);
      },
    );

    _controllers[cleanProjectId] = controller;

    unawaited(_init(cleanProjectId));

    return controller.stream;
  }

  void _scheduleDispose(String projectId) {
    _disposeTimers.remove(projectId)?.cancel();

    _disposeTimers[projectId] = Timer(
      const Duration(seconds: 8),
          () async {
        final controller = _controllers[projectId];

        if (controller != null &&
            !controller.isClosed &&
            controller.hasListener) {
          return;
        }

        await disposeProject(projectId);
      },
    );
  }

  // =========================================================
  // INIT
  // =========================================================

  Future<void> _init(String projectId) async {
    if (_initializing.contains(projectId)) {
      return;
    }

    if (_disposing.contains(projectId)) {
      return;
    }

    _initializing.add(projectId);

    try {
      await _loadInitial(projectId);

      if (_disposing.contains(projectId)) {
        return;
      }

      if (!_controllers.containsKey(projectId)) {
        return;
      }

      _subscribeRealtime(projectId);
    } finally {
      _initializing.remove(projectId);
    }
  }

  // =========================================================
  // INITIAL LOAD / REFRESH
  // =========================================================

  Future<void> _loadInitial(String projectId) async {
    try {
      final data = await _client
          .from(_tasksTable)
          .select(_taskSelect)
          .eq('project_id', projectId)
          .order(
        'created_at',
        ascending: false,
      );

      if (_disposing.contains(projectId)) {
        return;
      }

      final tasks = List<Map<String, dynamic>>.from(data)
          .map(TaskModel.fromJson)
          .toList();

      _sort(tasks);

      _cache[projectId] = tasks;

      _emit(projectId);
    } catch (e, st) {
      AppLogger.error(
        'Load tasks error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );
    }
  }

  void _scheduleRefresh(String projectId) {
    _refreshDebounce.remove(projectId)?.cancel();

    _refreshDebounce[projectId] = Timer(
      const Duration(milliseconds: 250),
          () {
        if (_disposing.contains(projectId)) {
          return;
        }

        unawaited(_loadInitial(projectId));
      },
    );
  }

  // =========================================================
  // REALTIME
  // =========================================================

  void _subscribeRealtime(String projectId) {
    if (_channels.containsKey(projectId)) {
      return;
    }

    if (_disposing.contains(projectId)) {
      return;
    }

    final channelName = 'project_tasks_$projectId';

    final channel = _client.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: _tasksTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: (payload) {
        _handleRealtime(
          projectId,
          payload,
        );
      },
    );

    channel.subscribe(
          (status, [error]) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            AppLogger.info(
              'Task realtime subscribed: $projectId',
              tag: 'TaskService',
            );
            break;

          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            AppLogger.error(
              'Task realtime error',
              error: error,
              tag: 'TaskService',
            );

            _channels.remove(projectId);

            Future.delayed(
              const Duration(seconds: 2),
                  () {
                if (_disposing.contains(projectId)) {
                  return;
                }

                if (!_controllers.containsKey(projectId)) {
                  return;
                }

                _subscribeRealtime(projectId);
              },
            );
            break;

          default:
            break;
        }
      },
    );

    _channels[projectId] = channel;
  }

  // =========================================================
  // HANDLE REALTIME
  // =========================================================

  void _handleRealtime(
      String projectId,
      PostgresChangePayload payload,
      ) {
    if (_disposing.contains(projectId)) {
      return;
    }

    try {
      _cache.putIfAbsent(projectId, () => []);

      final list = _cache[projectId]!;
      final newRecord = Map<String, dynamic>.from(payload.newRecord);
      final oldRecord = Map<String, dynamic>.from(payload.oldRecord);

      final event = payload.eventType.name.toLowerCase();

      if (event.contains('insert')) {
        if (newRecord.isNotEmpty) {
          _upsertTaskInList(
            list,
            TaskModel.fromJson(newRecord),
          );
        } else {
          _scheduleRefresh(projectId);
          return;
        }
      } else if (event.contains('update')) {
        if (newRecord.isNotEmpty) {
          _upsertTaskInList(
            list,
            TaskModel.fromJson(newRecord),
          );
        } else {
          _scheduleRefresh(projectId);
          return;
        }
      } else if (event.contains('delete')) {
        final id = oldRecord['id']?.toString();

        if (id != null && id.isNotEmpty) {
          list.removeWhere(
                (task) => task.id == id,
          );
        } else {
          _scheduleRefresh(projectId);
          return;
        }
      } else {
        _scheduleRefresh(projectId);
        return;
      }

      _sort(list);
      _emit(projectId);
    } catch (e, st) {
      AppLogger.error(
        'Realtime task error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );

      _scheduleRefresh(projectId);
    }
  }

  // =========================================================
  // CRUD
  // =========================================================

  /// Добавление задачи.
  ///
  /// ВАЖНО:
  /// viewer не должен вызывать этот метод из UI.
  /// Проверка роли должна быть в ProjectTasksWidget/родительском экране.
  Future<void> addTask(
      String projectId,
      String title,
      ) async {
    final cleanProjectId = projectId.trim();
    final text = title.trim();

    if (cleanProjectId.isEmpty || text.isEmpty) {
      return;
    }

    try {
      final data = await _client
          .from(_tasksTable)
          .insert({
        'project_id': cleanProjectId,
        'title': text,
        'is_completed': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      })
          .select(_taskSelect)
          .single();

      final task = TaskModel.fromJson(
        Map<String, dynamic>.from(data),
      );

      _cache.putIfAbsent(cleanProjectId, () => []);

      _upsertTaskInList(
        _cache[cleanProjectId]!,
        task,
      );

      _sort(_cache[cleanProjectId]!);
      _emit(cleanProjectId);
    } catch (e, st) {
      AppLogger.error(
        'addTask error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );

      rethrow;
    }
  }

  /// Старый метод оставлен для совместимости.
  ///
  /// Он меняет только поле is_completed.
  /// Это подходит для viewer, потому что наблюдатель должен иметь право
  /// только выполнять/снимать выполнение задач.
  Future<void> toggleTask(
      String taskId,
      bool current,
      ) async {
    await setTaskCompleted(
      taskId: taskId,
      isCompleted: !current,
    );
  }

  /// Безопасное обновление статуса выполнения задачи.
  ///
  /// Метод не меняет title, project_id и другие поля.
  Future<void> setTaskCompleted({
    required String taskId,
    required bool isCompleted,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      return;
    }

    final projectIdFromCache = _projectIdByTaskId(cleanTaskId);

    try {
      final data = await _client
          .from(_tasksTable)
          .update({
        'is_completed': isCompleted,
      })
          .eq('id', cleanTaskId)
          .select(_taskSelect)
          .maybeSingle();

      if (data == null) {
        throw Exception('tasks.update_failed');
      }

      final task = TaskModel.fromJson(
        Map<String, dynamic>.from(data),
      );

      final effectiveProjectId = task.projectId.isNotEmpty
          ? task.projectId
          : projectIdFromCache;

      if (effectiveProjectId != null && effectiveProjectId.isNotEmpty) {
        _cache.putIfAbsent(effectiveProjectId, () => []);

        _upsertTaskInList(
          _cache[effectiveProjectId]!,
          task,
        );

        _sort(_cache[effectiveProjectId]!);
        _emit(effectiveProjectId);
      }
    } catch (e, st) {
      AppLogger.error(
        'setTaskCompleted error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );

      rethrow;
    }
  }

  /// Удаление задачи.
  ///
  /// ВАЖНО:
  /// viewer не должен вызывать этот метод из UI.
  /// Проверка роли должна быть в ProjectTasksWidget/родительском экране.
  Future<void> deleteTask(String taskId) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      return;
    }

    final projectId = _projectIdByTaskId(cleanTaskId);

    try {
      await _client
          .from(_tasksTable)
          .delete()
          .eq('id', cleanTaskId);

      if (projectId != null && projectId.isNotEmpty) {
        final list = _cache[projectId];

        if (list != null) {
          list.removeWhere(
                (task) => task.id == cleanTaskId,
          );

          _sort(list);
          _emit(projectId);
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'deleteTask error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );

      rethrow;
    }
  }

  Future<void> refreshTasks(String projectId) async {
    final cleanProjectId = projectId.trim();

    if (cleanProjectId.isEmpty) {
      return;
    }

    await _loadInitial(cleanProjectId);
  }

  // =========================================================
  // HELPERS
  // =========================================================

  void _upsertTaskInList(
      List<TaskModel> list,
      TaskModel task,
      ) {
    final index = list.indexWhere(
          (item) => item.id == task.id,
    );

    if (index == -1) {
      list.add(task);
    } else {
      list[index] = task;
    }
  }

  String? _projectIdByTaskId(String taskId) {
    for (final entry in _cache.entries) {
      final exists = entry.value.any(
            (task) => task.id == taskId,
      );

      if (exists) {
        return entry.key;
      }
    }

    return null;
  }

  void _sort(List<TaskModel> list) {
    list.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  void _emit(String projectId) {
    final controller = _controllers[projectId];

    if (controller == null || controller.isClosed) {
      return;
    }

    controller.add(
      List.unmodifiable(
        _cache[projectId] ?? const <TaskModel>[],
      ),
    );
  }

  Future<void> _emitAsync(String projectId) async {
    await Future.microtask(() {
      _emit(projectId);
    });
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  Future<void> disposeProject(String projectId) async {
    final cleanProjectId = projectId.trim();

    if (cleanProjectId.isEmpty) {
      return;
    }

    if (_disposing.contains(cleanProjectId)) {
      return;
    }

    _disposing.add(cleanProjectId);

    AppLogger.info(
      'DISPOSE task project: $cleanProjectId',
      tag: 'TaskService',
    );

    try {
      _disposeTimers.remove(cleanProjectId)?.cancel();
      _refreshDebounce.remove(cleanProjectId)?.cancel();

      final channel = _channels.remove(cleanProjectId);

      if (channel != null) {
        await _client.removeChannel(channel);
      }

      final controller = _controllers.remove(cleanProjectId);

      if (controller != null && !controller.isClosed) {
        await controller.close();
      }

      _cache.remove(cleanProjectId);
      _initializing.remove(cleanProjectId);
    } catch (e, st) {
      AppLogger.error(
        'disposeProject error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );
    } finally {
      _disposing.remove(cleanProjectId);
    }
  }

  Future<void> dispose() async {
    final ids = _controllers.keys.toList();

    for (final id in ids) {
      await disposeProject(id);
    }

    for (final timer in _disposeTimers.values) {
      timer.cancel();
    }

    for (final timer in _refreshDebounce.values) {
      timer.cancel();
    }

    _disposeTimers.clear();
    _refreshDebounce.clear();
    _channels.clear();
    _cache.clear();
    _initializing.clear();
    _disposing.clear();
  }
}