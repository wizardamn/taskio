import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import 'supabase_service.dart';

class TaskService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<List<TaskModel>> getTasksStream(String projectId) {
    debugPrint('[TaskService] Subscribing to tasks for project: $projectId');
    return _client
        .from('project_tasks')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => TaskModel.fromJson(e)).toList());
  }

  Future<void> addTask(String projectId, String title) async {
    debugPrint('[TaskService] Adding task: "$title" to project $projectId');
    await _client.from('project_tasks').insert({
      'project_id': projectId,
      'title': title,
      'is_completed': false,
    });
    debugPrint('[TaskService] Task added.');
  }

  Future<void> toggleTask(String taskId, bool currentValue) async {
    debugPrint('[TaskService] Toggling task $taskId to ${!currentValue}');
    await _client
        .from('project_tasks')
        .update({'is_completed': !currentValue})
        .eq('id', taskId);
  }

  Future<void> deleteTask(String taskId) async {
    debugPrint('[TaskService] Deleting task $taskId');
    await _client.from('project_tasks').delete().eq('id', taskId);
  }
}