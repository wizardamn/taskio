import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import '../services/supabase_service.dart';

class ProjectService {
  final SupabaseClient client = SupabaseService.client;
  final String bucketName = SupabaseService.bucket;
  String? _currentUserId;

  /// Обновляет ID текущего пользователя, используемого сервисом для проверок прав.
  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  // ------------------------------------------------
  // 1. ВАЛИДАЦИЯ И САМОВОССТАНОВЛЕНИЕ
  // ------------------------------------------------

  /// Проверяет существование профилей и возвращает список валидных ID
  Future<List<String>> _filterValidUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final unique = userIds.toSet().toList();
    try {
      final res = await client.from('profiles').select('id').inFilter('id', unique);
      return (res as List).map<String>((e) => e['id'].toString()).toList();
    } catch (e) {
      debugPrint('[ProjectService] Error filtering user IDs: $e');
      return [];
    }
  }

  /// Гарантирует, что профиль текущего пользователя существует
  Future<void> _ensureCurrentUserProfile() async {
    if (_currentUserId == null) return;

    try {
      // Проверяем существование
      final check = await client
          .from('profiles')
          .select('id')
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (check == null) {
        final user = client.auth.currentUser;
        final email = user?.email ?? '';
        final name = user?.userMetadata?['full_name'] ?? email.split('@').first;

        await client.from('profiles').insert({
          'id': _currentUserId,
          'full_name': name,
          'email': email,
          'role': 'user', // Значение по умолчанию
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[ProjectService] Auto-created missing profile for $_currentUserId');
      }
    } catch (e) {
      debugPrint('[ProjectService] Failed to ensure profile existence: $e');
    }
  }

  // ------------------------------------------------
  // 2. ЗАГРУЗКА ДАННЫХ
  // ------------------------------------------------

  /// Загружает данные участников для указанного проекта
  Future<List<ProjectParticipant>> _fetchParticipantDetails(String projectId) async {
    try {
      final data = await client
          .from('project_members')
          .select('member_id, role, profiles:member_id (id, full_name)')
          .eq('project_id', projectId);

      return (data as List).map((row) {
        final memberId = row['member_id'] as String;
        final role = (row['role'] as String?) ?? 'viewer';
        final profile = row['profiles'] as Map<String, dynamic>?;
        final fullName = profile?['full_name'] as String? ?? 'Без имени';

        return ProjectParticipant(
          id: memberId,
          fullName: fullName,
          role: role,
        );
      }).toList();
    } catch (e) {
      debugPrint('[ProjectService] Error fetching participants: $e');
      return [];
    }
  }

  /// Загружает все проекты, в которых участвует текущий пользователь
  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) return [];
    final userId = _currentUserId!;

    try {
      // 1. Получаем ID проектов, где пользователь - участник или владелец
      final memberData = await client.from('project_members').select('project_id').eq('member_id', userId);
      final ownerData = await client.from('projects').select('id').eq('owner_id', userId);

      final allIds = {
        ...(memberData as List).map((e) => e['project_id']),
        ...(ownerData as List).map((e) => e['id'])
      }.toList();

      if (allIds.isEmpty) return [];

      // 2. Загружаем проекты
      final response = await client
          .from('projects')
          .select()
          .inFilter('id', allIds)
          .order('created_at', ascending: false);

      final List<ProjectModel> projects = [];
      for (final raw in response as List) {
        try {
          final project = ProjectModel.fromJson(raw as Map<String, dynamic>);

          final participants = await _fetchParticipantDetails(project.id);

          projects.add(project.copyWith(
            participantsData: participants,
            participantIds: participants.map((p) => p.id).toList(),
          ));
        } catch (e) {
          debugPrint('Error parsing project: $e');
        }
      }
      return projects;
    } catch (e) {
      debugPrint('getAll error: $e');
      throw Exception('Ошибка при загрузке проектов');
    }
  }

  /// Загружает один проект по его ID
  Future<ProjectModel?> getById(String id) async {
    try {
      final data = await client.from('projects').select().eq('id', id).maybeSingle();
      if (data == null) return null;

      final project = ProjectModel.fromJson(data as Map<String, dynamic>);
      final participants = await _fetchParticipantDetails(project.id);

      return project.copyWith(
        participantsData: participants,
        participantIds: participants.map((p) => p.id).toList(),
      );
    } catch (e) {
      debugPrint('getById error: $e');
      return null;
    }
  }

  // ------------------------------------------------
  // 3. CRUD ОПЕРАЦИИ
  // ------------------------------------------------

  /// Создаёт новый проект
  Future<ProjectModel> add(ProjectModel project) async {
    // 1. Гарантируем, что профиль создателя существует
    await _ensureCurrentUserProfile();

    final ownerId = project.ownerId;
    // Собираем всех участников + владельца
    final rawMemberIds = {...project.participantIds, ownerId}.toList();

    // 2. ФИЛЬТРУЕМ ID: Оставляем только тех, кто реально есть в базе profiles
    final validMemberIds = await _filterValidUserIds(rawMemberIds);

    // 3. Сохраняем проект. Удаляем поле participants, которое не нужно для таблицы projects.
    final projectJson = project.toJson();
    projectJson.remove('participants'); // Убедитесь, что эта колонка не вызывает конфликта

    final res = await client.from('projects').insert(projectJson).select().single();
    final savedProject = ProjectModel.fromJson(res);

    // 4. Сохраняем участников только из валидного списка
    for (final memberId in validMemberIds) {
      final role = memberId == ownerId ? 'owner' : 'editor';
      // Используем safe-call, так как project.id должен быть установлен Supabase
      await _upsertMember(savedProject.id, memberId, role);
    }

    // Возвращаем полную модель
    return (await getById(savedProject.id))!;
  }

  /// Обновляет существующий проект
  Future<void> update(ProjectModel project) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    // 1. Обновляем проект
    final projectJson = project.toJson();
    projectJson.remove('participants'); // Убедитесь, что эта колонка не вызывает конфликта
    await client.from('projects').update(projectJson).eq('id', project.id);

    // 2. Синхронизация участников
    final currentIds = await getParticipantIds(project.id);

    // Собираем желаемый список и валидируем его
    final desiredRawIds = {...project.participantIds, project.ownerId}.toList();
    final validDesiredIds = await _filterValidUserIds(desiredRawIds);

    // Удаляем лишних (кроме владельца)
    final toRemove = currentIds.where((id) => !validDesiredIds.contains(id) && id != project.ownerId).toList();
    if (toRemove.isNotEmpty) {
      await client.from('project_members').delete().inFilter('member_id', toRemove).eq('project_id', project.id);
    }

    // Добавляем/Обновляем нужных
    for (final memberId in validDesiredIds) {
      // Роль владельца всегда 'owner', остальных - 'editor' (или согласно вашей логике)
      final role = memberId == project.ownerId ? 'owner' : 'editor';
      await _upsertMember(project.id, memberId, role);
    }
  }

  /// Вспомогательный метод для добавления/обновления записи участника
  Future<void> _upsertMember(String projectId, String memberId, String role) async {
    // Используем upsert с onConflict для атомарности
    await client.from('project_members').upsert(
      {
        'project_id': projectId,
        'member_id': memberId,
        'role': role,
      },
      onConflict: 'project_id, member_id',
    );
  }

  /// Удаляет проект
  Future<void> delete(String id) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final project = await getById(id);
    if (project != null && project.ownerId != _currentUserId) {
      throw Exception('Только владелец может удалить проект');
    }

    // Удаляем файлы
    if (project != null && project.attachments.isNotEmpty) {
      final paths = project.attachments.map((a) => a.filePath).toList();
      try { await client.storage.from(bucketName).remove(paths); } catch (_) {}
    }

    // Удаляем связи (если не настроен CASCADE в БД)
    await client.from('project_members').delete().eq('project_id', id);
    await client.from('projects').delete().eq('id', id);
  }

  // ------------------------------------------------
  // 4. ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ------------------------------------------------

  /// Получает список ID участников проекта
  Future<List<String>> getParticipantIds(String projectId) async {
    final data = await client.from('project_members').select('member_id').eq('project_id', projectId);
    return (data as List).map((e) => e['member_id'] as String).toList();
  }

  /// Получает список участников проекта (ID, имя, роль)
  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      final data = await client
          .from('project_members')
          .select('member_id, role, profiles:member_id(id, full_name)')
          .eq('project_id', projectId);

      return (data as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        return {
          'id': row['member_id'],
          'full_name': profile?['full_name'] ?? 'Без имени',
          'role': row['role'] ?? 'viewer',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Добавляет участника в проект
  Future<void> addParticipant(String projectId, String memberId, [String role = "editor"]) async {
    // Проверяем существование перед добавлением
    final valid = await _filterValidUserIds([memberId]);
    if (valid.isNotEmpty) {
      await _upsertMember(projectId, memberId, role);
    }
  }

  /// Удаляет участника из проекта
  Future<void> removeParticipant(String projectId, String memberId) async {
    await client.from('project_members').delete().match({
      'project_id': projectId, 'member_id': memberId
    });
  }

  // ------------------------------------------------
  // 5. ВЛОЖЕНИЯ
  // ------------------------------------------------

  /// Загружает вложение в проект
  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final fileName = file.path.split('/').last;
    // Определение расширения для более точного MIME-типа (если нет специализированной библиотеки)
    final fileExtension = fileName.split('.').last;

    // В Supabase Storage лучше использовать уникальный путь: [project_id]/[file_hash]
    final filePath = '$projectId/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      // В Supabase Storage рекомендуется использовать уникальный, неперезаписываемый путь.
      await client.storage.from(bucketName).upload(filePath, file, fileOptions: const FileOptions(upsert: false));
    } on StorageException catch (e) {
      throw Exception('Ошибка загрузки: ${e.message}');
    }

    final project = await getById(projectId);
    if (project == null) {
      // Откат: если проект не найден, удаляем загруженный файл
      await client.storage.from(bucketName).remove([filePath]);
      throw Exception('Проект не найден');
    }

    final newAttachment = Attachment(
      fileName: fileName,
      filePath: filePath,
      uploadedAt: DateTime.now(),
      // Улучшение: хотя это не идеальный MIME-тип, оно лучше, чем ничего
      mimeType: fileExtension,
      uploaderId: _currentUserId!,
    );

    final updatedAttachments = [...project.attachments, newAttachment];

    // Обновляем поле attachments в БД
    await client.from('projects').update({
      'attachments': updatedAttachments.map((a) => a.toJson()).toList()
    }).eq('id', projectId);

    return (await getById(projectId))!;
  }

  /// Удаляет вложение из проекта
  Future<void> deleteAttachment(String projectId, String filePath) async {
    try { await client.storage.from(bucketName).remove([filePath]); } catch (_) {}

    final project = await getById(projectId);
    if (project == null) return;

    final updatedAttachments = project.attachments.where((a) => a.filePath != filePath).toList();
    await client.from('projects').update({
      'attachments': updatedAttachments.map((a) => a.toJson()).toList()
    }).eq('id', projectId);
  }


  Future<File?> downloadAttachment(String filePath, String fileName) async {

    throw UnimplementedError('Download attachment is not implemented in this stub.');
  }
}