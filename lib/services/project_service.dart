import 'dart:io';
import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class ProjectService {
  final SupabaseClient client =
      SupabaseService.client;

  final String bucketName =
      SupabaseService.bucket;

  final NotificationService _notifications =
  NotificationService();

  String? _currentUserId;

  // =========================================================
  // OWNER
  // =========================================================

  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  // =========================================================
  // ERROR
  // =========================================================

  Never _handleError(
      Object e,
      StackTrace st,
      String operation,
      ) {
    debugPrint(
      '[ProjectService] $operation: $e',
    );

    Error.throwWithStackTrace(
      Exception('$operation: $e'),
      st,
    );
  }

  // =========================================================
  // ENSURE PROFILE
  // =========================================================

  Future<void> _ensureCurrentUserProfile() async {
    if (_currentUserId == null) return;

    try {
      final exists = await client
          .from('profiles')
          .select('id')
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (exists != null) return;

      final user = client.auth.currentUser;

      final email = user?.email ?? '';

      final fullName =
          user?.userMetadata?['full_name'] ??
              email.split('@').first;

      final username =
          user?.userMetadata?['username'] ??
              email
                  .split('@')
                  .first
                  .toLowerCase();

      await client.from('profiles').upsert({
        'id': _currentUserId,
        'username': username,
        'full_name': fullName,
        'role': 'student',
        'created_at':
        DateTime.now().toUtc().toIso8601String(),
        'updated_at':
        DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      _handleError(
        e,
        st,
        'ensure profile failed',
      );
    }
  }

  // =========================================================
// PERMISSIONS
// Проверка прав текущего пользователя на редактирование проекта
// =========================================================

  bool canEditProject(ProjectModel project) {
    // Получение ID текущего авторизованного пользователя
    final userId = _currentUserId;
    // Если пользователь не авторизован — доступ запрещён
    if (userId == null) {
      return false;
    }
    // Поиск текущего пользователя среди участников проекта
    for (final participant in project.participantsData) {
      // Если это не текущий пользователь — переходим к следующему участнику
      if (participant.id != userId) {
        continue;
      }
      // Разрешаем редактирование только владельцу или редактору проекта
      return participant.role == ProjectRole.owner ||
          participant.role == ProjectRole.editor;
    }
    // Если пользователь не найден среди участников — доступ запрещён
    return false;
  }

  bool isOwner(ProjectModel project) {
    return project.ownerId == _currentUserId;
  }

  // =========================================================
  // GET ALL
  // =========================================================

  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) {
      return [];
    }

    try {
      final idsRaw = await client.rpc(
        'get_my_project_ids',
      );

      final ids =
      List<String>.from(idsRaw ?? []);

      if (ids.isEmpty) {
        return [];
      }

      final response = await client
          .from('projects_view')
          .select()
          .inFilter('id', ids)
          .order(
        'created_at',
        ascending: false,
      );

      return response
          .map<ProjectModel>(
            (raw) =>
            ProjectModel.fromJson(raw),
      )
          .toList();
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load projects failed',
      );
    }
  }

  // =========================================================
  // GET BY ID
  // =========================================================

  Future<ProjectModel?> getById(
      String id,
      ) async {
    try {
      final data = await client
          .from('projects_view')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return ProjectModel.fromJson(data);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'load project failed',
      );
    }
  }

  // =========================================================
  // SYNC PARTICIPANTS
  // =========================================================

  Future<void> syncParticipants({
    required String projectId,
    required String ownerId,
    required List<String> participantIds,
  }) async {
    try {
      final existing = await client
          .from('project_members')
          .select('member_id')
          .eq('project_id', projectId);

      final existingIds = existing
          .map<String>(
            (e) =>
            e['member_id'].toString(),
      )
          .toSet();

      final targetIds =
      participantIds.toSet();

      targetIds.add(ownerId);

      final toAdd =
      targetIds.difference(existingIds);

      final toRemove = existingIds
          .difference(targetIds)
          .where((id) => id != ownerId)
          .toSet();

      // REMOVE
      if (toRemove.isNotEmpty) {
        await client
            .from('project_members')
            .delete()
            .eq('project_id', projectId)
            .inFilter(
          'member_id',
          toRemove.toList(),
        );
      }

      // ADD
      if (toAdd.isNotEmpty) {
        final rows = toAdd.map((id) {
          return {
            'project_id': projectId,
            'member_id': id,
            'role': id == ownerId
                ? 'owner'
                : 'editor',
          };
        }).toList();

        await client
            .from('project_members')
            .insert(rows);
      }

      // ENSURE OWNER
      await client
          .from('project_members')
          .upsert(
        [
          {
            'project_id': projectId,
            'member_id': ownerId,
            'role': 'owner',
          }
        ],
        onConflict:
        'project_id,member_id',
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'sync participants failed',
      );
    }
  }

// =========================================================
// ADD PROJECT - создание нового проекта
// =========================================================
  Future<ProjectModel> add(
      ProjectModel project,
      ) async {
    // Проверка авторизации пользователя
    if (_currentUserId == null) {
      throw Exception(
        'errors.not_authenticated',
      );
    }
    // Убеждаемся, что профиль пользователя существует
    await _ensureCurrentUserProfile();
    try {
      // Преобразуем проект в JSON и назначаем текущего пользователя владельцем
      final json = project.toJson()
        ..['owner_id'] = _currentUserId;
      // Создаём проект в базе данных
      final response = await client
          .from('projects')
          .insert(json)
          .select()
          .single();
      // Получаем ID созданного проекта
      final createdId =
      response['id'].toString();
      // Получаем список участников проекта
      final participantIds = project
          .participantsData
          .map((e) => e.id)
          .toSet();
      // Добавляем владельца проекта в список участников
      participantIds.add(_currentUserId!);
      // Сохраняем участников в таблицу project_members
      await client
          .from('project_members')
          .upsert(
        participantIds.map((id) {
          return {
            'project_id': createdId,
            'member_id': id,
            // Назначаем роль: owner для создателя, editor для остальных
            'role': id == _currentUserId
                ? 'owner'
                : 'editor',
          };
        }).toList(),
        onConflict: 'project_id,member_id',
      );
      // Показываем уведомление о создании проекта
      await _notifications.showSimple(
        'project_created',
        project.title,
      );
      // Возвращаем полностью загруженный созданный проект
      return (await getById(createdId))!;
    } catch (e, st) {
      // Обработка ошибок
      _handleError(
        e,
        st,
        'create project failed',
      );
    }
  }

  // =========================================================
  // UPDATE PROJECT
  // =========================================================

  Future<void> update(
      ProjectModel project,
      ) async {
    if (_currentUserId == null) {
      throw Exception(
        'User not authenticated',
      );
    }

    try {
      if (!canEditProject(project)) {
        throw Exception(
          'errors.no_permission',
        );
      }

      final json = project.toJson();

      await client
          .from('projects')
          .update(json)
          .eq('id', project.id);

      await syncParticipants(
        projectId: project.id,
        ownerId: project.ownerId,
        participantIds: project
            .participantsData
            .map((e) => e.id)
            .toList(),
      );

      await _notifications.showSimple(
        'project_updated',
        project.title,
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'update project failed',
      );
    }
  }

  // =========================================================
  // DELETE PROJECT
  // =========================================================

  Future<void> delete(String id) async {
    if (_currentUserId == null) {
      throw Exception(
        'User not authenticated',
      );
    }

    try {
      final project =
      await getById(id);

      if (project == null) {
        return;
      }

      if (!isOwner(project)) {
        throw Exception(
          'errors.no_permission',
        );
      }

      // DELETE FILES
      if (project.attachments.isNotEmpty) {
        final paths = project.attachments
            .map((e) => e.filePath)
            .toList();

        try {
          await client.storage
              .from(bucketName)
              .remove(paths);
        } catch (e) {
          debugPrint(
            'storage cleanup failed: $e',
          );
        }
      }

      // DELETE ATTACHMENTS
      await client
          .from('project_attachments')
          .delete()
          .eq('project_id', id);

      // DELETE MEMBERS
      await client
          .from('project_members')
          .delete()
          .eq('project_id', id);

      // DELETE PROJECT
      await client
          .from('projects')
          .delete()
          .eq('id', id);

      await _notifications.showSimple(
        'project_deleted',
        '',
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'delete project failed',
      );
    }
  }

  // =========================================================
  // UPLOAD ATTACHMENTS
  // =========================================================

  Future<ProjectModel> uploadAttachments({
    required String projectId,
    required List<String> fileNames,
    List<File>? files,
    List<Uint8List>? filesBytes,
  }) async {
    if (_currentUserId == null) {
      throw Exception(
        'User not authenticated',
      );
    }

    try {
      final project =
      await getById(projectId);

      if (project == null) {
        throw Exception(
          'errors.project_not_found',
        );
      }

      if (!canEditProject(project)) {
        throw Exception(
          'errors.no_permission',
        );
      }

      final List<Attachment> uploaded =
      [];

      if (kIsWeb) {
        if (filesBytes == null ||
            filesBytes.length !=
                fileNames.length) {
          throw Exception(
            'errors.invalid_files_bytes',
          );
        }
      } else {
        if (files == null ||
            files.length !=
                fileNames.length) {
          throw Exception(
            'errors.invalid_files',
          );
        }
      }

      for (int i = 0;
      i < fileNames.length;
      i++) {
        final originalName =
        fileNames[i];

        final ext =
        originalName.contains('.')
            ? originalName
            .split('.')
            .last
            : 'bin';

        final safeName =
            '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        final path =
            'projects/$projectId/$_currentUserId/$safeName';

        // STORAGE
        if (kIsWeb &&
            filesBytes != null) {
          await client.storage
              .from(bucketName)
              .uploadBinary(
            path,
            filesBytes[i],
            fileOptions:
            const FileOptions(
              upsert: true,
            ),
          );
        } else if (files != null) {
          await client.storage
              .from(bucketName)
              .upload(
            path,
            files[i],
            fileOptions:
            const FileOptions(
              upsert: true,
            ),
          );
        }

        final attachmentId =
        const Uuid().v4();

        final attachment =
        Attachment(
          id: attachmentId,
          projectId: projectId,
          fileName: originalName,
          filePath: path,
          mimeType: ext,
          uploadedAt: DateTime.now(),
          uploaderId: _currentUserId!,
        );

        uploaded.add(attachment);

        // SAVE DB
        await client
            .from('project_attachments')
            .insert({
          'id': attachmentId,
          'project_id': projectId,
          'uploaded_by':
          _currentUserId,
          'file_name':
          originalName,
          'file_path': path,
          'mime_type': ext,
          'file_size': 0,
          'created_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        });
      }

      await _notifications.showSimple(
        'file_added',
        '',
      );

      return project.copyWith(
        attachments: [
          ...project.attachments,
          ...uploaded,
        ],
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'upload attachments failed',
      );
    }
  }

  // =========================================================
  // DELETE ATTACHMENT
  // =========================================================

  Future<void> deleteAttachment(
      String projectId,
      String filePath,
      ) async {
    try {
      final project =
      await getById(projectId);

      if (project == null) {
        return;
      }

      if (!canEditProject(project)) {
        throw Exception(
          'errors.no_permission',
        );
      }

      await client.storage
          .from(bucketName)
          .remove([filePath]);

      await client
          .from('project_attachments')
          .delete()
          .eq('project_id', projectId)
          .eq('file_path', filePath);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'delete attachment failed',
      );
    }
  }
}