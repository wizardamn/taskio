import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import 'supabase_service.dart';

class TaskService {
  final SupabaseClient _client = SupabaseService.client;

  /// Получает поток задач для проекта (Realtime)
  Stream<List<TaskModel>> getTasksStream(String projectId) {
    return _client
        .from('project_tasks')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => TaskModel.fromJson(e)).toList());
  }

  /// Добавить задачу
  Future<void> addTask(String projectId, String title) async {
    await _client.from('project_tasks').insert({
      'project_id': projectId,
      'title': title,
      'is_completed': false,
    });
  }

  /// Переключить статус (выполнено/нет)
  Future<void> toggleTask(String taskId, bool currentValue) async {
    await _client
        .from('project_tasks')
        .update({'is_completed': !currentValue})
        .eq('id', taskId);
  }

  /// Удалить задачу
  Future<void> deleteTask(String taskId) async {
    await _client.from('project_tasks').delete().eq('id', taskId);
  }
}