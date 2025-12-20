import 'package:universal_io/io.dart'; // ИСПРАВЛЕНО: Поддержка Web и Mobile
import 'package:flutter/foundation.dart'; // Для Uint8List
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class ProjectService {
  final SupabaseClient client = SupabaseService.client;
  final String bucketName = SupabaseService.bucket;
  String? _currentUserId;

  /// Обновляет ID текущего пользователя
  void updateOwner(String? userId) {
    _currentUserId = userId;
  }

  // ------------------------------------------------
  // 1. ВАЛИДАЦИЯ И ПОДГОТОВКА
  // ------------------------------------------------

  /// Проверяет существование профилей и возвращает список валидных ID
  Future<List<String>> _filterValidUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final unique = userIds.toSet().toList();
    try {
      // Используем .filter('col', 'in', list)
      final res = await client.from('profiles').select('id').filter('id', 'in', unique);
      // res уже является списком
      return res.map<String>((e) => e['id'] as String).toList();
    } catch (e) {
      _handleError(e, 'Ошибка фильтрации ID пользователей');
      return [];
    }
  }

  /// Гарантирует создание профиля для текущего юзера, если его нет
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
        final name = user?.userMetadata?['full_name'] ?? email.split('@').first;

        await client.from('profiles').insert({
          'id': _currentUserId,
          'full_name': name,
          'email': email,
          'role': 'student', // Дефолтная роль
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[ProjectService] Профиль автоматически создан для $_currentUserId');
      }
    } catch (e) {
      _handleError(e, 'Ошибка создания профиля');
    }
  }

  // ------------------------------------------------
  // 2. ЗАГРУЗКА ДАННЫХ (Чтение из VIEW)
  // ------------------------------------------------

  /// Загружает проекты пользователя (где он владелец или участник)
  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) return [];

    try {
      // 1. Находим проекты, где юзер - участник
      final memberData = await client
          .from('project_members')
          .select('project_id')
          .eq('member_id', _currentUserId!);

      // 2. Находим проекты, где юзер - владелец
      final ownerData = await client
          .from('projects')
          .select('id')
          .eq('owner_id', _currentUserId!);

      // Собираем уникальные ID проектов
      final Set<String> allIds = {};
      for (var item in memberData) {
        allIds.add(item['project_id'] as String);
      }
      for (var item in ownerData) {
        allIds.add(item['id'] as String);
      }

      if (allIds.isEmpty) return [];

      // 3. Загружаем полные данные проектов с участниками из VIEW
      final response = await client
          .from('projects_view')
          .select('*, project_members(*, profiles:member_id(id, full_name))')
          .filter('id', 'in', allIds.toList())
          .order('created_at', ascending: false);

      final List<ProjectModel> projects = [];

      for (final raw in response) {
        try {
          final project = ProjectModel.fromJson(raw as Map<String, dynamic>);

          // Парсим участников из join-запроса
          final participantsRaw = (raw['project_members'] as List?) ?? [];
          final participants = participantsRaw.map((row) {
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

          projects.add(project.copyWith(
            participantsData: participants,
            participantIds: participants.map((p) => p.id).toList(),
          ));

          // --- Проверка дедлайна для уведомления ---
          _checkDeadlineNotification(project);

        } catch (e) {
          debugPrint('Ошибка парсинга конкретного проекта: $e');
        }
      }
      return projects;
    } catch (e) {
      _handleError(e, 'Ошибка загрузки списка проектов');
      return [];
    }
  }

  /// Получение одного проекта
  Future<ProjectModel?> getById(String id) async {
    try {
      final data = await client
          .from('projects_view')
          .select('*, project_members(*, profiles:member_id(id, full_name))')
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;

      final project = ProjectModel.fromJson(data as Map<String, dynamic>);

      final participantsRaw = (data['project_members'] as List?) ?? [];
      final participants = participantsRaw.map((row) {
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

      return project.copyWith(
        participantsData: participants,
        participantIds: participants.map((p) => p.id).toList(),
      );
    } catch (e) {
      _handleError(e, 'Ошибка загрузки проекта по ID');
      return null;
    }
  }

  // ------------------------------------------------
  // 3. CRUD ОПЕРАЦИИ (Запись в TABLE)
  // ------------------------------------------------

  Future<ProjectModel> add(ProjectModel project) async {
    await _ensureCurrentUserProfile();

    final ownerId = project.ownerId;
    final rawMemberIds = {...project.participantIds, ownerId}.toList();
    final validMemberIds = await _filterValidUserIds(rawMemberIds);

    final projectJson = project.toJson();
    projectJson.remove('participants');

    try {
      final res = await client.from('projects').insert(projectJson).select().single();
      final savedProject = ProjectModel.fromJson(res);

      for (final memberId in validMemberIds) {
        final role = memberId == ownerId ? 'owner' : 'editor';
        await _upsertMember(savedProject.id, memberId, role);
      }

      await NotificationService().showSimple(
        'Проект создан',
        'Проект "${savedProject.title}" успешно создан.',
      );

      return (await getById(savedProject.id))!;
    } catch (e) {
      _handleError(e, 'Ошибка создания проекта');
      rethrow;
    }
  }

  Future<void> update(ProjectModel project) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final projectJson = project.toJson();
    projectJson.remove('participants');

    try {
      final oldProject = await getById(project.id);

      await client.from('projects').update(projectJson).eq('id', project.id);

      final currentIds = await getParticipantIds(project.id);
      final desiredRawIds = {...project.participantIds, project.ownerId}.toList();
      final validDesiredIds = await _filterValidUserIds(desiredRawIds);

      final toRemove = currentIds.where((id) => !validDesiredIds.contains(id) && id != project.ownerId).toList();
      if (toRemove.isNotEmpty) {
        await client
            .from('project_members')
            .delete()
            .filter('member_id', 'in', toRemove)
            .eq('project_id', project.id);
      }

      for (final memberId in validDesiredIds) {
        final role = memberId == project.ownerId ? 'owner' : 'editor';
        await _upsertMember(project.id, memberId, role);
      }

      if (oldProject != null) {
        _sendUpdateNotification(oldProject, project);
      }

    } catch (e) {
      _handleError(e, 'Ошибка обновления проекта');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final project = await getById(id);
    if (project != null && project.ownerId != _currentUserId) {
      throw Exception('Только владелец может удалить проект');
    }

    try {
      if (project != null && project.attachments.isNotEmpty) {
        final paths = project.attachments.map((a) => a.filePath).toList();
        await client.storage.from(bucketName).remove(paths);
      }

      await client.from('project_members').delete().eq('project_id', id);
      await client.from('projects').delete().eq('id', id);

      if (project != null) {
        await NotificationService().showSimple(
          'Проект удалён',
          'Проект "${project.title}" был успешно удалён.',
        );
      }
    } catch (e) {
      _handleError(e, 'Ошибка удаления проекта');
      rethrow;
    }
  }

  // ------------------------------------------------
  // 4. УПРАВЛЕНИЕ УЧАСТНИКАМИ
  // ------------------------------------------------

  Future<List<String>> getParticipantIds(String projectId) async {
    try {
      final data = await client
          .from('project_members')
          .select('member_id')
          .eq('project_id', projectId);

      return data.map((e) => e['member_id'] as String).toList();
    } catch (e) {
      _handleError(e, 'Ошибка получения ID участников');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getParticipants(String projectId) async {
    try {
      final data = await client
          .from('project_members')
          .select('member_id, role, profiles:member_id(id, full_name)')
          .eq('project_id', projectId);

      return data.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        return {
          'id': row['member_id'] as String,
          'full_name': profile?['full_name'] ?? 'Без имени',
          'role': row['role'] ?? 'viewer',
        };
      }).toList();
    } catch (e) {
      _handleError(e, 'Ошибка получения списка участников');
      return [];
    }
  }

  Future<void> addParticipant(String projectId, String memberId, [String role = "editor"]) async {
    final valid = await _filterValidUserIds([memberId]);
    if (valid.isNotEmpty) {
      await _upsertMember(projectId, memberId, role);

      final project = await getById(projectId);
      if (project != null) {
        await NotificationService().showSimple(
          'Участник добавлен',
          'Пользователь добавлен в проект "${project.title}".',
        );
      }
    }
  }

  Future<void> removeParticipant(String projectId, String memberId) async {
    try {
      await client
          .from('project_members')
          .delete()
          .match({'project_id': projectId, 'member_id': memberId});

      final project = await getById(projectId);
      if (project != null) {
        await NotificationService().showSimple(
          'Участник удалён',
          'Пользователь удален из проекта "${project.title}".',
        );
      }
    } catch (e) {
      _handleError(e, 'Ошибка удаления участника');
    }
  }

  Future<void> _upsertMember(String projectId, String memberId, String role) async {
    try {
      await client.from('project_members').upsert(
        {
          'project_id': projectId,
          'member_id': memberId,
          'role': role,
        },
        onConflict: 'project_id, member_id',
      );
    } catch (e) {
      debugPrint("Ошибка upsert участника: $e");
    }
  }

  // ------------------------------------------------
  // 5. ВЛОЖЕНИЯ (УНИВЕРСАЛЬНЫЙ МЕТОД WEB/MOBILE)
  // ------------------------------------------------

  Future<ProjectModel> uploadAttachment({
    required String projectId,
    required String fileName,
    File? file,           // Для Mobile
    Uint8List? fileBytes, // Для Web
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final filePath = '$projectId/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      if (fileBytes != null) {
        // Web: Загрузка байтов
        await client.storage.from(bucketName).uploadBinary(
          filePath,
          fileBytes,
          fileOptions: const FileOptions(upsert: false),
        );
      } else if (file != null) {
        // Mobile: Загрузка файла
        await client.storage.from(bucketName).upload(
          filePath,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
      } else {
        throw Exception("Файл не предоставлен");
      }
    } on StorageException catch (e) {
      _handleError(e, 'Ошибка загрузки файла в Storage');
      rethrow;
    }

    final project = await getById(projectId);
    if (project == null) throw Exception('Проект не найден');

    final newAttachment = Attachment(
      fileName: fileName,
      filePath: filePath,
      uploadedAt: DateTime.now(),
      mimeType: fileName.split('.').last,
      uploaderId: _currentUserId!,
    );

    final updatedAttachments = [...project.attachments, newAttachment];
    await client.from('projects').update({
      'attachments': updatedAttachments.map((a) => a.toJson()).toList()
    }).eq('id', projectId);

    await NotificationService().showSimple(
      'Файл загружен',
      'Файл "$fileName" добавлен к проекту.',
    );

    return (await getById(projectId))!;
  }

  Future<ProjectModel> deleteAttachment(String projectId, String filePath) async {
    try {
      await client.storage.from(bucketName).remove([filePath]);
    } catch (_) {}

    final project = await getById(projectId);
    if (project == null) throw Exception('Проект не найден');

    final updatedAttachments = project.attachments.where((a) => a.filePath != filePath).toList();

    await client.from('projects').update({
      'attachments': updatedAttachments.map((a) => a.toJson()).toList()
    }).eq('id', projectId);

    await NotificationService().showSimple(
      'Файл удалён',
      'Файл удален из проекта.',
    );

    return (await getById(projectId))!;
  }

  // ------------------------------------------------
  // ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
  // ------------------------------------------------

  void _handleError(Object e, String operation) {
    debugPrint('[ProjectService] $operation: $e');
    throw Exception('$operation: ${e.toString().split(':')[0].trim()}');
  }

  Future<void> _checkDeadlineNotification(ProjectModel project) async {
    final now = DateTime.now();
    final deadline = project.deadline;
    final timeToDeadline = deadline.difference(now);

    if (timeToDeadline.inHours <= 24 && timeToDeadline.inHours > 0) {
      final notificationTime = deadline.subtract(const Duration(hours: 1));
      await NotificationService().scheduleNotification(
        id: project.id.hashCode,
        title: 'Дедлайн близко: ${project.title}',
        body: 'Остался 1 час до дедлайна.',
        scheduledTime: notificationTime,
      );
    }
  }

  Future<void> _sendUpdateNotification(ProjectModel oldProject, ProjectModel newProject) async {
    String title = 'Проект обновлён';
    String body = 'Проект "${newProject.title}" изменён.';

    if (oldProject.status != newProject.status) {
      body += ' Статус: ${newProject.statusEnum.text}.';
    }
    if (oldProject.deadline != newProject.deadline) {
      body += ' Новый дедлайн.';
    }

    await NotificationService().showSimple(title, body);
  }
}