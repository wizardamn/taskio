import 'package:universal_io/io.dart'; // Поддержка Web и Mobile
import 'package:flutter/foundation.dart'; // Для Uint8List, kIsWeb и debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'supabase_service.dart';

class ChatService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<List<MessageModel>> getMessagesStream(String projectId) {
    debugPrint('[ChatService] Подписка на сообщения проекта: $projectId');
    return _client
        .from('project_messages')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .map((data) {
      // Примечание: В stream мы не получаем joined данные (profiles),
      // поэтому имя подставляется на уровне UI через список участников.
      return data.map((json) {
        // Ручной маппинг, так как fromJson ожидает структуру с profiles
        MessageType msgType = MessageType.text;
        final typeString = json['type'] as String? ?? 'text';
        if (typeString == 'image') msgType = MessageType.image;
        if (typeString == 'file') msgType = MessageType.file;

        return MessageModel(
          id: json['id'],
          projectId: json['project_id'],
          senderId: json['sender_id'],
          senderName: '...',
          content: json['content'],
          createdAt: DateTime.parse(json['created_at']).toLocal(),
          type: msgType,
          isRead: json['is_read'] ?? false,
        );
      }).toList();
    });
  }

  /// Отправка текстового сообщения
  Future<void> sendMessage(String projectId, String content) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('[ChatService] Отправка сообщения в проект $projectId: "$content"');
    await _client.from('project_messages').insert({
      'project_id': projectId,
      'sender_id': userId,
      'content': content,
      'type': 'text',
    });
    debugPrint('[ChatService] Сообщение успешно отправлено.');
  }

  /// Отправка файла или изображения (Универсальный метод)
  Future<void> sendFileMessage({
    required String projectId,
    required MessageType type,
    File? file,           // Для Mobile
    Uint8List? fileBytes, // Для Web
    String? fileName,     // Имя файла
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final name = fileName ?? (file != null ? file.path.split('/').last : 'unknown_file');
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$name';
    final path = 'chat_files/$projectId/$uniqueName';

    debugPrint('[ChatService] Начало загрузки файла: $name ($type)');

    try {
      if (fileBytes != null) {
        // Web: Загрузка байтов
        await _client.storage.from(SupabaseService.bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(upsert: false),
        );
      } else if (file != null) {
        // Mobile: Загрузка файла
        await _client.storage.from(SupabaseService.bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
      } else {
        throw Exception("Файл не предоставлен для загрузки");
      }

      debugPrint('[ChatService] Файл загружен в Storage: $path');

      // Получаем публичную ссылку
      final fullPath = _client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);

      // Отправляем сообщение с ссылкой
      await _client.from('project_messages').insert({
        'project_id': projectId,
        'sender_id': userId,
        'content': fullPath,
        'type': type == MessageType.image ? 'image' : 'file',
      });

      debugPrint('[ChatService] Сообщение с файлом успешно отправлено.');
    } catch (e) {
      debugPrint('[ChatService] Ошибка отправки файла: $e');
      throw Exception('Ошибка отправки файла: $e');
    }
  }

  /// Пометить сообщения как прочитанные (вызывать при открытии чата)
  Future<void> markAsRead(String projectId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('[ChatService] Помечаем сообщения как прочитанные в проекте: $projectId');

    // Обновляем все сообщения в проекте, где sender_id НЕ я, и is_read = false
    await _client.from('project_messages')
        .update({'is_read': true})
        .eq('project_id', projectId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }
}