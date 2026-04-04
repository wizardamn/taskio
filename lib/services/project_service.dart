import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class ProjectService {
  final SupabaseClient client = SupabaseService.client;
  final String bucketName = SupabaseService.bucket;

  String? _currentUserId;

  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  // =========================================================
  // ERROR HANDLER
  // =========================================================

  Never _handleError(Object e, String operation) {
    debugPrint('[ProjectService] $operation: $e');
    throw Exception(
      '$operation: ${e.toString().split(':').first.trim()}',
    );
  }

  // =========================================================
  // VALIDATION
  // =========================================================

  Future<List<String>> _filterValidUserIds(
      List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final unique = userIds.toSet().toList();

    try {
      final res = await client
          .from('profiles')
          .select('id')
          .filter('id', 'in', unique);

      return (res as List)
          .map<String>((e) => e['id'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _ensureCurrentUserProfile() async {
    if (_currentUserId == null) return;

    try {
      final check = await client
          .from('profiles')
          .select('id')
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (check == null) {
        final user = client.auth.currentUser;
        final email = user?.email ?? '';
        final name =
            user?.userMetadata?['full_name'] ??
                email.split('@').first;

        await client.from('profiles').insert({
          'id': _currentUserId,
          'full_name': name,
          'role': 'student',
          'created_at':
          DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _handleError(e, 'Ошибка создания профиля');
    }
  }

  // =========================================================
  // READ
  // =========================================================

  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) return [];

    try {
      final memberData = await client
          .from('project_members')
          .select('project_id')
          .eq('member_id', _currentUserId!);

      final ownerData = await client
          .from('projects')
          .select('id')
          .eq('owner_id', _currentUserId!);

      final Set<String> allIds = {};

      for (var item in memberData) {
        allIds.add(item['project_id'] as String);
      }
      for (var item in ownerData) {
        allIds.add(item['id'] as String);
      }

      if (allIds.isEmpty) return [];

      final response = await client
          .from('projects_view')
          .select(
          '*, project_members(*, profiles:member_id(id, full_name))')
          .filter('id', 'in', allIds.toList())
          .order('created_at',
          ascending: false);

      final List<ProjectModel> projects = [];

      for (final raw in response) {
        final project = ProjectModel.fromJson(
            raw as Map<String, dynamic>);

        final participants =
        _parseParticipants(raw);

        projects.add(
          project.copyWith(
            participantsData: participants,
            participantIds:
            participants.map((p) => p.id).toList(),
          ),
        );
      }

      return projects;
    } catch (e) {
      _handleError(e, 'Ошибка загрузки проектов');
    }
  }

  Future<ProjectModel?> getById(String id) async {
    try {
      final data = await client
          .from('projects_view')
          .select(
          '*, project_members(*, profiles:member_id(id, full_name))')
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;

      final project = ProjectModel.fromJson(
          data as Map<String, dynamic>);

      final participants =
      _parseParticipants(data);

      return project.copyWith(
        participantsData: participants,
        participantIds:
        participants.map((p) => p.id).toList(),
      );
    } catch (e) {
      _handleError(e, 'Ошибка загрузки проекта');
    }
  }

  List<ProjectParticipant> _parseParticipants(
      Map<String, dynamic> raw) {
    final participantsRaw =
        (raw['project_members'] as List?) ?? [];

    return participantsRaw.map((row) {
      final memberId =
      row['member_id'] as String;

      final role =
          (row['role'] as String?) ??
              'viewer';

      final profile =
      row['profiles']
      as Map<String, dynamic>?;

      final fullName =
          profile?['full_name']
          as String? ??
              'Без имени';

      return ProjectParticipant(
        id: memberId,
        fullName: fullName,
        role: role,
      );
    }).toList();
  }

  // =========================================================
  // CREATE
  // =========================================================

  Future<ProjectModel> add(
      ProjectModel project) async {
    if (_currentUserId == null) {
      throw Exception(
          'User not authenticated');
    }

    await _ensureCurrentUserProfile();

    try {
      final projectJson =
      project.toJson()
        ..remove('participants');

      final res = await client
          .from('projects')
          .insert(projectJson)
          .select()
          .single();

      final saved =
      ProjectModel.fromJson(res);

      await NotificationService()
          .showSimple(
        'Проект создан',
        'Проект "${saved.title}" создан.',
      );

      return (await getById(saved.id))!;
    } catch (e) {
      _handleError(e, 'Ошибка создания проекта');
    }
  }

  // =========================================================
  // UPDATE
  // =========================================================

  Future<void> update(
      ProjectModel project) async {
    if (_currentUserId == null) {
      throw Exception(
          'User not authenticated');
    }

    try {
      final projectJson =
      project.toJson()
        ..remove('participants');

      await client
          .from('projects')
          .update(projectJson)
          .eq('id', project.id);

      await NotificationService()
          .showSimple(
        'Проект обновлён',
        'Проект "${project.title}" обновлён.',
      );
    } catch (e) {
      _handleError(e, 'Ошибка обновления проекта');
    }
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> delete(String id) async {
    if (_currentUserId == null) {
      throw Exception(
          'User not authenticated');
    }

    try {
      final project = await getById(id);

      if (project != null &&
          project.ownerId != _currentUserId) {
        throw Exception(
            'Только владелец может удалить проект');
      }

      if (project != null &&
          project.attachments.isNotEmpty) {
        final paths = project.attachments
            .map((a) => a.filePath)
            .toList();

        await client.storage
            .from(bucketName)
            .remove(paths);
      }

      await client
          .from('project_members')
          .delete()
          .eq('project_id', id);

      await client
          .from('projects')
          .delete()
          .eq('id', id);

      await NotificationService()
          .showSimple(
        'Проект удалён',
        'Проект удалён.',
      );
    } catch (e) {
      _handleError(e, 'Ошибка удаления проекта');
    }
  }

  // =========================================================
// DELETE ATTACHMENT
// =========================================================

  Future<void> deleteAttachment(
      String projectId,
      String filePath,
      ) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // 1️⃣ Удаляем файл из Storage
      await client.storage
          .from(bucketName)
          .remove([filePath]);

      // 2️⃣ Получаем проект
      final project = await getById(projectId);
      if (project == null) {
        throw Exception('Проект не найден');
      }

      // 3️⃣ Обновляем attachments
      final updatedList = project.attachments
          .where((a) => a.filePath != filePath)
          .toList();

      await client.from('projects').update({
        'attachments':
        updatedList.map((a) => a.toJson()).toList(),
      }).eq('id', projectId);

    } catch (e) {
      _handleError(e, 'Ошибка удаления файла');
    }
  }
  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Future<ProjectModel> uploadAttachments({
    required String projectId,
    required List<String> fileNames,
    List<File>? files,
    List<Uint8List>? filesBytes,
  }) async {
    if (_currentUserId == null) {
      throw Exception(
          'User not authenticated');
    }

    final project =
    await getById(projectId);

    if (project == null) {
      throw Exception('Проект не найден');
    }

    final List<Attachment> newAttachments =
    [];

    try {
      for (int i = 0;
      i < fileNames.length;
      i++) {
        final name = fileNames[i];

        final extension =
        name.contains('.')
            ? name.split('.').last
            : 'bin';

        final safeName =
            'file_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

        final path =
            'projects/$projectId/$_currentUserId/$safeName';

        if (kIsWeb &&
            filesBytes != null &&
            i < filesBytes.length) {
          await client.storage
              .from(bucketName)
              .uploadBinary(
            path,
            filesBytes[i],
          );
        } else if (files != null &&
            i < files.length) {
          await client.storage
              .from(bucketName)
              .upload(
            path,
            files[i],
          );
        }

        newAttachments.add(
          Attachment(
            fileName: name,
            filePath: path,
            mimeType: extension,
            uploadedAt:
            DateTime.now(),
            uploaderId:
            _currentUserId!,
          ),
        );
      }

      final updatedList = [
        ...project.attachments,
        ...newAttachments,
      ];

      await client
          .from('projects')
          .update({
        'attachments': updatedList
            .map((a) => a.toJson())
            .toList()
      }).eq('id', projectId);

      return project.copyWith(
        attachments: updatedList,
      );
    } catch (e) {
      _handleError(e, 'Ошибка загрузки файлов');
    }
  }
}
