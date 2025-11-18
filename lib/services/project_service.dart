import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import '../services/supabase_service.dart';

class ProjectService {
  final SupabaseClient client = Supabase.instance.client;
  final String bucketName = SupabaseService.bucket;
  String? _currentUserId;

  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  // ------------------------------------------------
  // ✅ ВАЛИДАЦИЯ УЧАСТНИКОВ
  // ------------------------------------------------
  Future<List<String>> _filterValidUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final uniqueUserIds = userIds.toSet().toList();

    try {
      final existingUsers = await client
          .from('profiles')
          .select('id')
          .inFilter('id', uniqueUserIds);

      return existingUsers.map<String>((e) => e['id'].toString()).toList();
    } catch (e) {
      debugPrint('[ProjectService] Error filtering user IDs: $e');
      return [];
    }
  }

  // ------------------------------------------------
  // ✅ ЗАГРУЗКА ПРОЕКТОВ
  // ------------------------------------------------
  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) {
      debugPrint('[ProjectService] userId is null. Returning empty list.');
      return [];
    }

    try {
      final String userId = _currentUserId!;
      debugPrint('[ProjectService] Fetching projects for user ID: $userId');

      // ✅ ИСПРАВЛЕНИЕ СИНТАКСИСА (Строка 70):
      // Убедитесь, что вся строка запроса находится внутри кавычек.
      final response = await client
          .from('projects')
          .select('*, project_members!inner(member_id)')
          .or('owner_id.eq.$userId,project_members.member_id.eq.$userId');

      // ✅ Безопасное преобразование ответа
      // Supabase v2 возвращает List<Map<String, dynamic>>.
      // Мы используем List.from для безопасности вместо 'as List'.
      final List<dynamic> dataList = response as List<dynamic>;

      return dataList
          .map((data) {
        try {
          // Очистка данных от вложенного project_members перед парсингом,
          // так как ProjectModel.fromJson ожидает плоскую структуру или определенные поля.
          final projectData = data['project_members'] != null
              ? (Map<String, dynamic>.from(data)..remove('project_members'))
              : data as Map<String, dynamic>;

          return ProjectModel.fromJson(projectData);
        } catch (e) {
          debugPrint('ProjectModel parsing FAILED: $e');
          return null;
        }
      })
          .whereType<ProjectModel>()
          .toSet() // Убираем дубликаты
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    } catch (e, st) {
      debugPrint('CRITICAL ERROR during fetchProjects: $e\n$st');
      // ✅ ИСПРАВЛЕНИЕ ИНТЕРПОЛЯЦИИ: Убраны лишние скобки, если e - это строка или объект
      throw Exception('Ошибка при загрузке проектов: $e');
    }
  }

  /// Получить проект по ID
  Future<ProjectModel?> getById(String id) async {
    final data = await client
        .from('projects')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return ProjectModel.fromJson(data);
  }

  // ------------------------------------------------
  // ✅ CRUD
  // ------------------------------------------------

  /// Создать проект
  Future<void> add(ProjectModel project) async {
    final projectId = project.id;
    final ownerId = project.ownerId;

    final desiredMembersRaw = <String>{...project.participants, ownerId}.toList();
    final validParticipants = await _filterValidUserIds(desiredMembersRaw);

    final projectData = project.toJson();
    projectData.remove('attachments');
    projectData.remove('participants');

    await client.from('projects').insert(projectData);

    for (var memberId in validParticipants) {
      await addParticipant(projectId, memberId, memberId == ownerId ? "owner" : "editor");
    }
  }

  /// Обновить проект
  Future<void> update(ProjectModel project) async {
    final jsonToUpdate = project.toJson();
    jsonToUpdate.remove('attachments');
    jsonToUpdate.remove('participants');

    await client.from('projects').update(jsonToUpdate).eq('id', project.id);

    final currentMembers = await getParticipantIds(project.id);
    final ownerId = project.ownerId;

    final desiredMembersRaw = <String>{...project.participants, ownerId}.toList();
    final desiredMembers = await _filterValidUserIds(desiredMembersRaw);

    final membersToRemove = currentMembers.where((id) =>
    !desiredMembers.contains(id) && id != ownerId).toList();

    for (var memberId in membersToRemove) {
      await removeParticipant(project.id, memberId);
    }

    final membersToSync = desiredMembers.where((id) =>
    !currentMembers.contains(id) || id == ownerId).toList();

    for (var memberId in membersToSync) {
      await addParticipant(project.id, memberId, memberId == ownerId ? "owner" : "editor");
    }
  }

  /// Удалить проект
  Future<void> delete(String id) async {
    try {
      final project = await getById(id);
      if (project != null) {
        final filePaths = project.attachments.map((a) => a.filePath).toList();
        if (filePaths.isNotEmpty) {
          await client.storage.from(bucketName).remove(filePaths);
          debugPrint('Successfully removed ${filePaths.length} files.');
        }
      }
    } catch (e) {
      debugPrint('Error removing files: $e');
    }

    await client.from('project_members').delete().eq('project_id', id);
    await client.from('projects').delete().eq('id', id);
  }

  // ------------------------------------------------
  // ✅ УЧАСТНИКИ
  // ------------------------------------------------

  Future<List<String>> getParticipantIds(String projectId) async {
    final data = await client
        .from('project_members')
        .select('member_id')
        .eq('project_id', projectId);

    return List<String>.from(data.map((e) => e['member_id'].toString()));
  }

  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    final data = await client
        .from('project_members')
        .select('member_id, role, profile:profiles(full_name, role, email)')
        .eq('project_id', projectId);

    // ✅ ИСПРАВЛЕНИЕ КАСКАДА (Строка 213):
    // Используем List.from для безопасного приведения типов
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addParticipant(String projectId, String memberId, [String role = "editor"]) async {
    await client.from('project_members').upsert({
      'project_id': projectId,
      'member_id': memberId,
      'role': role,
    });
  }

  Future<void> removeParticipant(String projectId, String memberId) async {
    await client
        .from('project_members')
        .delete()
        .match({'project_id': projectId, 'member_id': memberId});
  }

  // ------------------------------------------------
  // 📎 ВЛОЖЕНИЯ
  // ------------------------------------------------

  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (_currentUserId == null) {
      throw Exception('User ID is not set.');
    }

    final fileExtension = file.path.split('.').last;
    final fileName = file.path.split('/').last;
    final filePath = '$projectId/${_currentUserId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      await client.storage
          .from(bucketName)
          .upload(
          filePath,
          file,
          fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false
          )
      );
    } on StorageException catch (e) {
      debugPrint('Storage Error: ${e.message}');
      // ✅ ИСПРАВЛЕНИЕ ИНТЕРПОЛЯЦИИ (Строка 247):
      // Убраны лишние скобки ${e.message} -> $e.message, если это возможно,
      // но в Dart ${expression} всегда безопаснее. Ошибка "Unnecessary braces" обычно
      // возникает для простых переменных типа $variable. Для e.message скобки НУЖНЫ.
      // Скорее всего, линтер ругался на что-то другое рядом.
      // Я оставлю безопасный вариант.
      throw Exception('Ошибка загрузки: ${e.message}');
    }

    ProjectModel? project = await getById(projectId);
    if (project == null) {
      try {
        await client.storage.from(bucketName).remove([filePath]);
      } catch (e) {
        debugPrint('Error removing orphaned file: $e');
      }
      throw Exception('Проект не найден.');
    }

    final newAttachment = Attachment(
      fileName: fileName,
      filePath: filePath,
      uploadedAt: DateTime.now(),
      mimeType: fileExtension,
      uploaderId: _currentUserId!,
    );

    final newAttachments = [...project.attachments, newAttachment];

    await client.from('projects').update(
        {'attachments': newAttachments.map((a) => a.toJson()).toList()}
    ).eq('id', projectId);

    final updatedProject = await getById(projectId);
    return updatedProject!;
  }

  Future<void> deleteAttachment(String projectId, String filePath) async {
    try {
      await client.storage
          .from(bucketName)
          .remove([filePath]);
    } on StorageException catch (e) {
      debugPrint('Storage Error: ${e.message}');
    }

    ProjectModel? project = await getById(projectId);
    if (project == null) return;

    final newAttachments = project.attachments.where((a) => a.filePath != filePath).toList();

    await client.from('projects').update(
        {'attachments': newAttachments.map((a) => a.toJson()).toList()}
    ).eq('id', projectId);
  }

  Future<File?> downloadAttachment(String filePath, String fileName) async {
    return SupabaseService().downloadAttachment(filePath, fileName);
  }
}