import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'supabase_service.dart';

class ChatService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<List<MessageModel>> getMessagesStream(String projectId) {
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

    await _client.from('project_messages').insert({
      'project_id': projectId,
      'sender_id': userId,
      'content': content,
      'type': 'text',
    });
  }

  /// Отправка файла или изображения
  Future<void> sendFileMessage(String projectId, File file, MessageType type) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final path = 'chat_files/$projectId/$fileName';

      // 1. Загружаем файл в Storage
      await _client.storage
          .from(SupabaseService.bucket)
          .upload(path, file);

      // 2. Получаем публичную ссылку (в качестве content)
      // Примечание: Можно хранить path и генерировать URL в UI, но для простоты сохраним путь
      final fullPath = await _client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);

      // 3. Отправляем сообщение с ссылкой
      await _client.from('project_messages').insert({
        'project_id': projectId,
        'sender_id': userId,
        'content': fullPath, // Ссылка на файл
        'type': type == MessageType.image ? 'image' : 'file',
      });
    } catch (e) {
      throw Exception('Ошибка отправки файла: $e');
    }
  }

  /// Пометить сообщения как прочитанные (вызывать при открытии чата)
  Future<void> markAsRead(String projectId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Обновляем все сообщения в проекте, где sender_id НЕ я, и is_read = false
    await _client.from('project_messages')
        .update({'is_read': true})
        .eq('project_id', projectId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }
}