import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_model.dart';
import 'supabase_service.dart';
import '../utils/app_logger.dart';

class TaskService {
  final SupabaseClient _client = SupabaseService.client;

  final Map<String, List<TaskModel>> _cache = {};
  final Map<String, StreamController<List<TaskModel>>> _controllers = {};
  final Map<String, RealtimeChannel> _channels = {};

  final Set<String> _initializing = {};
  final Set<String> _disposing = {};

  // =========================================================
  // STREAM
  // =========================================================

  Stream<List<TaskModel>> getTasksStream(
      String projectId,
      ) {
    _disposing.remove(projectId);

    final existing = _controllers[projectId];

    if (existing != null && !existing.isClosed) {
      if (_cache.containsKey(projectId)) {
        unawaited(_emitAsync(projectId));
      }

      return existing.stream;
    }

    AppLogger.info(
      'INIT stream: $projectId',
      tag: 'TaskService',
    );

    late final StreamController<List<TaskModel>> controller;

    controller = StreamController<List<TaskModel>>.broadcast(
      onCancel: () async {
        if (!controller.hasListener) {
          await disposeProject(projectId);
        }
      },
    );

    _controllers[projectId] = controller;

    if (_cache.containsKey(projectId)) {
      unawaited(_emitAsync(projectId));
    }

    unawaited(_init(projectId));

    return controller.stream;
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
  // INITIAL LOAD
  // =========================================================

  Future<void> _loadInitial(String projectId) async {
    try {
      final data = await _client
          .from('project_tasks')
          .select()
          .eq('project_id', projectId)
          .order(
        'created_at',
        ascending: false,
      );

      if (_disposing.contains(projectId)) {
        return;
      }

      final tasks = List<Map<String, dynamic>>.from(data)
          .map((e) => TaskModel.fromJson(e))
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

    final channel = _client.channel(
      'tasks:$projectId',
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_tasks',
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

    channel.subscribe((status, [error]) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          AppLogger.info(
            'Realtime subscribed: $projectId',
            tag: 'TaskService',
          );
          break;

        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          AppLogger.error(
            'Realtime error',
            error: error,
            tag: 'TaskService',
          );

          _channels.remove(projectId);

          Future.delayed(
            const Duration(seconds: 2),
                () {
              if (!_disposing.contains(projectId)) {
                _subscribeRealtime(projectId);
              }
            },
          );
          break;

        default:
          break;
      }
    });

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

      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      final event = payload.eventType.name;

      switch (event) {
        case 'INSERT':
          if (newRecord.isNotEmpty) {
            final task = TaskModel.fromJson(newRecord);

            final exists = list.any(
                  (t) => t.id == task.id,
            );

            if (!exists) {
              list.add(task);
            }
          }
          break;

        case 'UPDATE':
          if (newRecord.isNotEmpty) {
            final updated = TaskModel.fromJson(newRecord);

            final index = list.indexWhere(
                  (t) => t.id == updated.id,
            );

            if (index != -1) {
              list[index] = updated;
            } else {
              list.add(updated);
            }
          }
          break;

        case 'DELETE':
          if (oldRecord.isNotEmpty) {
            final id = oldRecord['id'];

            list.removeWhere(
                  (t) => t.id == id,
            );
          }
          break;
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
    }
  }

  // =========================================================
  // CRUD
  // =========================================================

  Future<void> addTask(
      String projectId,
      String title,
      ) async {
    final text = title.trim();

    if (text.isEmpty) {
      return;
    }

    try {
      await _client.from('project_tasks').insert({
        'project_id': projectId,
        'title': text,
        'is_completed': false,
      });
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

  Future<void> toggleTask(
      String taskId,
      bool current,
      ) async {
    try {
      await _client
          .from('project_tasks')
          .update({
        'is_completed': !current,
      })
          .eq('id', taskId);
    } catch (e, st) {
      AppLogger.error(
        'toggleTask error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _client
          .from('project_tasks')
          .delete()
          .eq('id', taskId);
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

  // =========================================================
  // HELPERS
  // =========================================================

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
        _cache[projectId] ?? [],
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
    if (_disposing.contains(projectId)) {
      return;
    }

    _disposing.add(projectId);

    AppLogger.info(
      'DISPOSE: $projectId',
      tag: 'TaskService',
    );

    try {
      final channel = _channels.remove(projectId);

      if (channel != null) {
        await channel.unsubscribe();
        await _client.removeChannel(channel);
      }

      final controller = _controllers.remove(projectId);

      if (controller != null && !controller.isClosed) {
        await controller.close();
      }

      _cache.remove(projectId);
      _initializing.remove(projectId);
    } catch (e, st) {
      AppLogger.error(
        'disposeProject error',
        error: e,
        stackTrace: st,
        tag: 'TaskService',
      );
    } finally {
      _disposing.remove(projectId);
    }
  }

  Future<void> dispose() async {
    final ids = _controllers.keys.toList();

    for (final id in ids) {
      await disposeProject(id);
    }

    _channels.clear();
    _cache.clear();
    _initializing.clear();
    _disposing.clear();
  }
}