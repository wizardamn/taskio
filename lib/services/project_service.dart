import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart'; // <-- ИМПОРТ NotificationService

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
      return res.map<String>((e) => e['id'] as String).toList();
    } catch (e) {
      _handleError(e, 'Ошибка фильтрации ID пользователей');
      return [];
    }
  }

  /// Гарантирует, что профиль текущего пользователя существует
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
          'role': 'user',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[ProjectService] Auto-created missing profile for $_currentUserId');
      }
    } catch (e) {
      _handleError(e, 'Ошибка создания профиля');
    }
  }

  // ------------------------------------------------
  // 2. ЗАГРУЗКА ДАННЫХ
  // ------------------------------------------------

  /// Загружает все проекты, в которых участвует текущий пользователь
  Future<List<ProjectModel>> getAll() async {
    if (_currentUserId == null) return [];

    try {
      final memberData = await client.from('project_members').select('project_id').eq('member_id', _currentUserId!);
      final ownerData = await client.from('projects').select('id').eq('owner_id', _currentUserId!);

      final allIds = {
        ...(memberData as List).map((e) => e['project_id'] as String),
        ...(ownerData as List).map((e) => e['id'] as String)
      }.toList();

      if (allIds.isEmpty) return [];

      final response = await client
          .from('projects')
          .select('*, project_members(*, profiles:member_id(id, full_name))')
          .inFilter('id', allIds)
          .order('created_at', ascending: false);

      final List<ProjectModel> projects = [];
      for (final raw in response as List) {
        try {
          final project = ProjectModel.fromJson(raw as Map<String, dynamic>);
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

          // --- НОВОЕ: Планирование уведомления о дедлайне ---
          // Проверяем, близок ли дедлайн (например, в течение 24 часов)
          final now = DateTime.now();
          final deadline = project.deadline;
          final timeToDeadline = deadline.difference(now);

          if (timeToDeadline.inHours <= 24 && timeToDeadline.inHours > 0) {
            // Планируем уведомление за 1 час до дедлайна
            final notificationTime = deadline.subtract(const Duration(hours: 1));

            // Используем NotificationService для планирования уведомления
            await NotificationService().scheduleNotification(
              id: project.id.hashCode, // Уникальный ID для уведомления на основе ID проекта
              title: 'Напоминание: ${project.title}',
              body: 'Дедлайн проекта "${project.title}" наступает ${deadline.hour}:${deadline.minute.toString().padLeft(2, '0')} ${deadline.day}.${deadline.month}.${deadline.year}.',
              scheduledTime: notificationTime,
            );
          }
          // --- КОНЕЦ НОВОГО ---
        } catch (e) {
          _handleError(e, 'Ошибка парсинга проекта');
        }
      }
      return projects;
    } catch (e) {
      _handleError(e, 'Ошибка загрузки проектов');
      return [];
    }
  }

  /// Загружает один проект по его ID
  Future<ProjectModel?> getById(String id) async {
    try {
      final data = await client
          .from('projects')
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
  // 3. CRUD ОПЕРАЦИИ
  // ------------------------------------------------

  /// Создаёт новый проект
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

      // --- НОВОЕ: Отправка уведомления о создании ---
      await NotificationService().showSimple(
        'Проект создан',
        'Проект "${savedProject.title}" успешно создан.',
      );
      // --- КОНЕЦ НОВОГО ---

      return (await getById(savedProject.id))!;
    } catch (e) {
      _handleError(e, 'Ошибка создания проекта');
      rethrow;
    }
  }

  /// Обновляет существующий проект
  Future<void> update(ProjectModel project) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final projectJson = project.toJson();
    projectJson.remove('participants');

    try {
      // --- НОВОЕ: Получаем старый проект для сравнения ---
      final oldProject = await getById(project.id);
      // --- КОНЕЦ НОВОГО ---

      await client.from('projects').update(projectJson).eq('id', project.id);

      final currentIds = await getParticipantIds(project.id);
      final desiredRawIds = {...project.participantIds, project.ownerId}.toList();
      final validDesiredIds = await _filterValidUserIds(desiredRawIds);

      final toRemove = currentIds.where((id) => !validDesiredIds.contains(id) && id != project.ownerId).toList();
      if (toRemove.isNotEmpty) {
        await client.from('project_members').delete().inFilter('member_id', toRemove).eq('project_id', project.id);
      }

      for (final memberId in validDesiredIds) {
        final role = memberId == project.ownerId ? 'owner' : 'editor';
        await _upsertMember(project.id, memberId, role);
      }

      // --- НОВОЕ: Отправка уведомления об изменении ---
      if (oldProject != null) {
        String notificationTitle = 'Проект обновлён';
        String notificationBody = 'Проект "${project.title}" был изменён.';

        if (oldProject.status != project.status) {
          notificationBody += ' Статус изменён с "${oldProject.statusEnum.text}" на "${project.statusEnum.text}".';
        }
        if (oldProject.deadline != project.deadline) {
          notificationBody += ' Дедлайн изменён с "${oldProject.deadline}" на "${project.deadline}".';
        }
        if (oldProject.title != project.title) {
          notificationTitle = 'Проект переименован';
          notificationBody = 'Проект "${oldProject.title}" переименован в "${project.title}".';
        }

        await NotificationService().showSimple(notificationTitle, notificationBody);
      }
      // --- КОНЕЦ НОВОГО ---

    } catch (e) {
      _handleError(e, 'Ошибка обновления проекта');
      rethrow;
    }
  }

  /// Удаляет проект
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

      // --- НОВОЕ: Отправка уведомления об удалении ---
      if (project != null) {
        await NotificationService().showSimple(
          'Проект удалён',
          'Проект "${project.title}" был успешно удалён.',
        );
      }
      // --- КОНЕЦ НОВОГО ---

    } catch (e) {
      _handleError(e, 'Ошибка удаления проекта');
      rethrow;
    }
  }

  // ------------------------------------------------
  // 4. ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ------------------------------------------------

  /// Получает список ID участников проекта
  Future<List<String>> getParticipantIds(String projectId) async {
    try {
      final data = await client.from('project_members').select('member_id').eq('project_id', projectId);
      return (data as List).map((e) => e['member_id'] as String).toList();
    } catch (e) {
      _handleError(e, 'Ошибка получения ID участников');
      return [];
    }
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
          'id': row['member_id'] as String,
          'full_name': profile?['full_name'] ?? 'Без имени',
          'role': row['role'] ?? 'viewer',
        };
      }).toList();
    } catch (e) {
      _handleError(e, 'Ошибка получения участников');
      return [];
    }
  }

  /// Добавляет участника в проект
  Future<void> addParticipant(String projectId, String memberId, [String role = "editor"]) async {
    final valid = await _filterValidUserIds([memberId]);
    if (valid.isNotEmpty) {
      await _upsertMember(projectId, memberId, role);

      // --- НОВОЕ: Отправка уведомления о добавлении участника ---
      final project = await getById(projectId);
      if (project != null) {
        final newMember = project.participantsData.firstWhere(
              (p) => p.id == memberId,
          orElse: () => ProjectParticipant(id: '', fullName: 'Неизвестный', role: 'viewer'), // <-- ИСПРАВЛЕНО: Возвращаем заглушку с ролью
        );
        await NotificationService().showSimple(
          'Участник добавлен',
          'Пользователь "${newMember.fullName}" добавлен в проект "${project.title}".',
        );
      }
      // --- КОНЕЦ НОВОГО ---
    }
  }

  /// Удаляет участника из проекта
  Future<void> removeParticipant(String projectId, String memberId) async {
    try {
      await client.from('project_members').delete().match({'project_id': projectId, 'member_id': memberId});

      // --- НОВОЕ: Отправка уведомления об удалении участника ---
      final project = await getById(projectId);
      if (project != null) {
        await NotificationService().showSimple(
          'Участник удалён',
          'Пользователь "$memberId" удален из проекта "${project.title}".',
        );
      }
      // --- КОНЕЦ НОВОГО ---

    } catch (e) {
      _handleError(e, 'Ошибка удаления участника');
    }
  }

  /// Вспомогательный метод для добавления/обновления записи участника
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
      _handleError(e, 'Ошибка добавления/обновления участника');
    }
  }

  // ------------------------------------------------
  // 5. ВЛОЖЕНИЯ
  // ------------------------------------------------

  /// Загружает вложение в проект
  Future<ProjectModel> uploadAttachment(String projectId, File file) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final fileName = file.path.split('/').last;
    final filePath = '$projectId/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      await client.storage.from(bucketName).upload(filePath, file, fileOptions: const FileOptions(upsert: false));
    } on StorageException catch (e) {
      _handleError(e, 'Ошибка загрузки вложения');
      rethrow;
    }

    final project = await getById(projectId);
    if (project == null) {
      await client.storage.from(bucketName).remove([filePath]);
      throw Exception('Проект не найден');
    }

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

    // --- НОВОЕ: Отправка уведомления о загрузке вложения ---
    await NotificationService().showSimple(
      'Файл загружен',
      'Файл "$fileName" добавлен к проекту "${project.title}".',
    );
    // --- КОНЕЦ НОВОГО ---

    return (await getById(projectId))!;
  }

  /// Удаляет вложение из проекта
  Future<void> deleteAttachment(String projectId, String filePath) async {
    try {
      await client.storage.from(bucketName).remove([filePath]);
    } catch (_) {}

    final project = await getById(projectId);
    if (project == null) return;

    final updatedAttachments = project.attachments.where((a) => a.filePath != filePath).toList();
    await client.from('projects').update({
      'attachments': updatedAttachments.map((a) => a.toJson()).toList()
    }).eq('id', projectId);

    // --- НОВОЕ: Отправка уведомления об удалении вложения ---
    final fileName = filePath.split('/').last;
    await NotificationService().showSimple(
      'Файл удалён',
      'Файл "$fileName" удален из проекта "${project.title}".',
    );
    // --- КОНЕЦ НОВОГО ---
  }

  /// Скачивает вложение
  Future<File> downloadAttachment(String filePath, String fileName) async {
    try {
      final response = await client.storage.from(bucketName).download(filePath);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response);
      return file;
    } catch (e) {
      _handleError(e, 'Ошибка скачивания вложения');
      rethrow;
    }
  }

  // ------------------------------------------------
  // 6. ОБЩАЯ ОБРАБОТКА ОШИБОК
  // ------------------------------------------------

  void _handleError(Object e, String operation) {
    debugPrint('[ProjectService] $operation: ${e.toString()}');
    throw Exception('$operation: ${e.toString().split(':')[0].trim()}');
  }
}