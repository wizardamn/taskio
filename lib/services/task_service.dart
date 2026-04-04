import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_model.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class TaskService {
  final SupabaseClient _client = SupabaseService.client;

  // =========================================================
  // STREAM TASKS
  // =========================================================

  Stream<List<TaskModel>> getTasksStream(String projectId) {
    AppLogger.info(
        '[TaskService] Subscribe tasks for project: $projectId');

    try {
      return _client
          .from('project_tasks')
          .stream(primaryKey: ['id'])
          .eq('project_id', projectId)
          .order('created_at', ascending: true)
          .map(
            (data) => data
            .map((e) => TaskModel.fromJson(e))
            .toList(),
      );
    } catch (e, st) {
      AppLogger.error(
          'TaskService getTasksStream error', e);
      AppLogger.error('StackTrace', st);

      rethrow;
    }
  }

  // =========================================================
  // ADD TASK
  // =========================================================

  Future<void> addTask(
      String projectId, String title) async {
    try {
      AppLogger.info(
          '[TaskService] Add task "$title"');

      await _client.from('project_tasks').insert({
        'project_id': projectId,
        'title': title,
        'is_completed': false,
      });

    } catch (e, st) {
      AppLogger.error(
          'TaskService addTask error', e);
      AppLogger.error('StackTrace', st);

      throw Exception(ErrorMapper.map(e));
    }
  }

  // =========================================================
  // TOGGLE TASK
  // =========================================================

  Future<void> toggleTask(
      String taskId, bool currentValue) async {
    try {
      AppLogger.info(
          '[TaskService] Toggle task $taskId');

      await _client
          .from('project_tasks')
          .update({
        'is_completed': !currentValue,
      })
          .eq('id', taskId);

    } catch (e, st) {
      AppLogger.error(
          'TaskService toggleTask error', e);
      AppLogger.error('StackTrace', st);

      throw Exception(ErrorMapper.map(e));
    }
  }

  // =========================================================
  // DELETE TASK
  // =========================================================

  Future<void> deleteTask(String taskId) async {
    try {
      AppLogger.info(
          '[TaskService] Delete task $taskId');

      await _client
          .from('project_tasks')
          .delete()
          .eq('id', taskId);

    } catch (e, st) {
      AppLogger.error(
          'TaskService deleteTask error', e);
      AppLogger.error('StackTrace', st);

      throw Exception(ErrorMapper.map(e));
    }
  }
}