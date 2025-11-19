import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart'; // Используем предоставленный SupabaseService

// ----------------------------------------------------------------------
// СЕРВИС ДЛЯ УПРАВЛЕНИЯ ПРОЕКТАМИ И УЧАСТНИКАМИ
// ----------------------------------------------------------------------
class ProjectService {
  // Используем статический клиент из SupabaseService
  final SupabaseClient client = SupabaseService.client;
  final String bucketName = SupabaseService.bucket;
  String? _currentUserId;

  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  // ------------------------------------------------
  // 1. ВАЛИДАЦИЯ УЧАСТНИКОВ (Проверка существования ID)
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
  // 2. ОБОГАЩЕНИЕ ДАННЫХ (ID -> Имя)
  // ------------------------------------------------
  /// Получает информацию о членах проекта (ID + Имя) через таблицу project_members,
  /// выполняя JOIN на profiles.
  Future<List<ProjectParticipant>> _fetchParticipantDetails(String projectId) async {
    try {
      // ИСПОЛЬЗУЕМ JOIN: project_members -> profiles
      final data = await client
          .from('project_members')
          .select('member_id, profiles!inner(full_name)') // !inner гарантирует, что профиль существует
          .eq('project_id', projectId);

      return data.map((item) {
        final memberId = item['member_id'] as String;
        final profileData = item['profiles'] as Map<String, dynamic>?;

        // Безопасное извлечение имени
        String fullName = 'Участник (ID: $memberId)';
        if (profileData != null) {
          fullName = profileData['full_name'] as String? ?? fullName;
        } else {
          // Это сработает, если RLS запрещает чтение профиля
          debugPrint('[ProjectService] RLS or data issue: profile data missing for $memberId');
        }

        return ProjectParticipant(
          id: memberId,
          fullName: fullName,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('[ProjectService] CRITICAL Error fetching participant details for project $projectId: $e\n$st');
      return [];
    }
  }


  // ------------------------------------------------
  // 3. ЗАГРУЗКА ПРОЕКТОВ (Fetch All)
  // ------------------------------------------------
  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) {
      debugPrint('[ProjectService] userId is null. Returning empty list.');
      return [];
    }

    try {
      final String userId = _currentUserId!;

      // 1. Получаем ID всех проектов, где пользователь является участником
      final memberProjectsResponse = await client
          .from('project_members')
          .select('project_id')
          .eq('member_id', userId);

      final memberProjectIds = memberProjectsResponse
          .map<String>((e) => e['project_id'].toString())
          .toList();

      // 2. Также добавляем проекты, где пользователь - владелец
      final ownerProjectsResponse = await client
          .from('projects')
          .select('id')
          .eq('owner_id', userId);

      final ownerProjectIds = ownerProjectsResponse
          .map<String>((e) => e['id'].toString())
          .toList();

      // Объединяем и удаляем дубликаты
      final allProjectIds = {...memberProjectIds, ...ownerProjectIds}.toList();

      if (allProjectIds.isEmpty) {
        return [];
      }

      // 3. Запрашиваем полные данные проектов по ID
      final response = await client
          .from('projects')
          .select()
          .inFilter('id', allProjectIds)
          .order('created_at', ascending: false);

      final List<dynamic> rawDataList = response as List;
      final List<ProjectModel> projects = [];

      // 4. Итерируемся по проектам и обогащаем их данными участников.
      for (var data in rawDataList) {
        try {
          final rawProject = ProjectModel.fromJson(data as Map<String, dynamic>);

          // ✅ ОБОГАЩЕНИЕ: Получаем полные данные участников (ID + Имя)
          final participantDetails = await _fetchParticipantDetails(rawProject.id);

          final finalProject = rawProject.copyWith(
            participantsData: participantDetails, // Заполняем поле для UI
            participantIds: participantDetails.map((p) => p.id).toList(), // Обновляем список ID
          );

          projects.add(finalProject);

        } catch (e, st) {
          debugPrint('ProjectModel parsing FAILED for project data: $e\n$st');
        }
      }

      return projects;

    } catch (e, st) {
      debugPrint('CRITICAL ERROR during fetchProjects: $e\n$st');
      throw Exception('Ошибка при загрузке проектов: ${e.toString()}'.tr());
    }
  }


  /// Получить проект по ID (с обогащением)
  Future<ProjectModel?> getById(String id) async {
    final data = await client
        .from('projects')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;

    final rawProject = ProjectModel.fromJson(data);

    // ✅ ОБОГАЩЕНИЕ
    final participantDetails = await _fetchParticipantDetails(rawProject.id);

    return rawProject.copyWith(
      participantsData: participantDetails,
      participantIds: participantDetails.map((p) => p.id).toList(),
    );
  }

  // ------------------------------------------------
  // 4. CRUD
  // ------------------------------------------------

  /// Создать проект
  Future<void> add(ProjectModel project) async {
    final projectId = project.id;
    final ownerId = project.ownerId;

    // 1. Валидация участников
    final desiredMembersRaw = <String>{...project.participantIds, ownerId}.toList();
    final validParticipants = await _filterValidUserIds(desiredMembersRaw);

    final projectData = project.toJson();

    // 2. Вставляем проект
    await client.from('projects').insert(projectData);

    // 3. Добавляем всех участников (включая владельца) в project_members
    for (var memberId in validParticipants) {
      await addParticipant(projectId, memberId, memberId == ownerId ? "owner" : "editor");
    }
  }

  /// Обновить проект
  Future<void> update(ProjectModel project) async {
    final jsonToUpdate = project.toJson();

    // 1. Обновляем основную таблицу
    await client.from('projects').update(jsonToUpdate).eq('id', project.id);

    // 2. СИНХРОНИЗАЦИЯ ЧЛЕНОВ В project_members
    final currentMembers = await getParticipantIds(project.id);
    final ownerId = project.ownerId;

    final desiredMembersRaw = <String>{...project.participantIds, ownerId}.toList();
    final desiredMembers = await _filterValidUserIds(desiredMembersRaw);

    // Участники для удаления (те, кто был, но кого нет в новом списке, кроме владельца)
    final membersToRemove = currentMembers.where((id) =>
    !desiredMembers.contains(id) && id != ownerId).toList();

    for (var memberId in membersToRemove) {
      await removeParticipant(project.id, memberId);
    }

    // Участники для добавления/обновления (новые или владелец)
    final membersToSync = desiredMembers;

    for (var memberId in membersToSync) {
      // addParticipant использует upsert: добавит нового или обновит существующего
      await addParticipant(project.id, memberId, memberId == ownerId ? "owner" : "editor");
    }
  }

  /// Удалить проект
  Future<void> delete(String id) async {
    try {
      // Удаление файлов
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

    // Удаляем записи в project_members перед удалением проекта
    await client.from('project_members').delete().eq('project_id', id);
    // Удаляем проект
    await client.from('projects').delete().eq('id', id);
  }

  // ------------------------------------------------
  // 5. УЧАСТНИКИ (СВЯЗАННЫЕ С project_members)
  // ------------------------------------------------

  Future<List<String>> getParticipantIds(String projectId) async {
    final data = await client
        .from('project_members')
        .select('member_id')
        .eq('project_id', projectId);

    return List<String>.from(data.map((e) => e['member_id'].toString()));
  }

  /// ✅ ВОССТАНОВЛЕННЫЙ МЕТОД
  /// Получает полный список участников проекта (ID, роль, профиль)
  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    final data = await client
        .from('project_members')
    // Запрашиваем ID члена, роль и профиль (с полным именем, ролью и почтой)
        .select('member_id, role, profile:profiles!inner(full_name, role, email)')
        .eq('project_id', projectId);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addParticipant(String projectId, String memberId, [String role = "editor"]) async {
    // Используем upsert для добавления или обновления роли
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
  // 6. ВЛОЖЕНИЯ
  // ------------------------------------------------

  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (_currentUserId == null) {
      throw Exception('User ID is not set.');
    }

    final fileExtension = file.path.split('.').last;
    final fileName = file.path.split('/').last;
    final filePath = '$projectId/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

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
      throw Exception('Ошибка загрузки: ${e.message}'.tr());
    }

    ProjectModel? project = await getById(projectId);
    if (project == null) {
      try {
        await client.storage.from(bucketName).remove([filePath]);
      } catch (e) {
        debugPrint('Error removing orphaned file: $e');
      }
      throw Exception('Проект не найден.'.tr());
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
    // Используем метод из SupabaseService
    return SupabaseService().downloadAttachment(filePath, fileName);
  }
}