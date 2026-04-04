import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_model.dart';
import 'supabase_service.dart';
import 'ai_service.dart';

class ChatService {

  final SupabaseClient _client = SupabaseService.client;
  final AIService _aiService = AIService();

  RealtimeChannel? _messageChannel;

  final Map<String,List<MessageModel>> _messageCache = {};

  Timer? _presenceTimer;
  Timer? _typingTimer;

  // =========================================================
  // REALTIME MESSAGES CHANNEL
  // =========================================================

  Stream<List<MessageModel>> subscribeMessages(String projectId) {

    final controller = StreamController<List<MessageModel>>.broadcast();

    _messageCache.putIfAbsent(projectId, () => []);

    _messageChannel?.unsubscribe();

    _messageChannel = _client.channel('chat:$projectId');

    _messageChannel!
        .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'project_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: projectId),
        callback: (payload) {

          final newRow = payload.newRecord;

          if(newRow.isEmpty) return;

          final message = MessageModel.fromJson(newRow);

          final list = _messageCache[projectId]!;

          list.insert(0,message);

          controller.add(List.from(list));
        })
        .subscribe();

    return controller.stream;
  }

  // =========================================================
  // INITIAL LOAD + PAGINATION
  // =========================================================

  Future<List<MessageModel>> loadMessages(
      String projectId,
      {int limit = 30}
      ) async {

    final rows = await _client
        .from('project_messages')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(limit);

    final messages =
    rows.map<MessageModel>((r)=>MessageModel.fromJson(r)).toList();

    _messageCache[projectId] = messages;

    return messages;
  }

  // =========================================================
  // LOAD MORE (LAZY PAGINATION)
  // =========================================================

  Future<List<MessageModel>> loadMoreMessages(
      String projectId,
      DateTime before
      ) async {

    final rows = await _client
        .from('project_messages')
        .select()
        .eq('project_id', projectId)
        .lt('created_at', before.toIso8601String())
        .order('created_at', ascending: false)
        .limit(30);

    final messages =
    rows.map<MessageModel>((r)=>MessageModel.fromJson(r)).toList();

    _messageCache[projectId]?.addAll(messages);

    return messages;
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage(
      String projectId,
      String content,
      {String? replyTo}
      ) async {

    final userId = _client.auth.currentUser?.id;
    if(userId == null) return;

    final text = content.trim();
    if(text.isEmpty) return;

    final detectedLang =
    await _aiService.detectLanguage(text);

    await _client.from('project_messages').insert({

      'project_id': projectId,
      'sender_id': userId,

      'content': text,
      'type': 'text',

      'reply_to_message_id': replyTo,

      'created_at': DateTime.now().toIso8601String(),

      'is_read': false,

      'original_language': detectedLang,
      'translated_content': null,

      'edited_at': null,
      'is_deleted': false,
    });
  }

  // =========================================================
  // EDIT MESSAGE
  // =========================================================

  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {

    final text = newContent.trim();
    if(text.isEmpty) return;

    await _client
        .from('project_messages')
        .update({

      'content': text,
      'edited_at': DateTime.now().toIso8601String(),

    })
        .eq('id', messageId);
  }

  // =========================================================
  // DELETE MESSAGE
  // =========================================================

  Future<void> deleteMessage(String messageId) async {

    await _client
        .from('project_messages')
        .update({

      'is_deleted': true,
      'content': 'Message deleted',
      'edited_at': DateTime.now().toIso8601String()

    })
        .eq('id', messageId);
  }

  // =========================================================
  // FILE UPLOAD
  // =========================================================

  Future<void> sendFileMessage({

    required String projectId,
    required MessageType type,

    File? file,
    Uint8List? fileBytes,
    String? fileName,

  }) async {

    final userId = _client.auth.currentUser?.id;
    if(userId == null) return;

    final name =
        fileName ??
            (file!=null
                ? file.path.split('/').last
                : 'file');

    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_$name';

    final path =
        'chat_files/$projectId/$uniqueName';

    if(fileBytes != null){

      await _client.storage
          .from(SupabaseService.bucket)
          .uploadBinary(path,fileBytes);

    }else if(file != null){

      await _client.storage
          .from(SupabaseService.bucket)
          .upload(path,file);
    }

    final url =
    _client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(path);

    await _client.from('project_messages').insert({

      'project_id': projectId,
      'sender_id': userId,

      'content': url,

      'type': type == MessageType.image
          ? 'image'
          : 'file',

      'created_at': DateTime.now().toIso8601String(),

      'is_read': false,
      'edited_at': null,
      'is_deleted': false,
    });
  }

  // =========================================================
  // UNREAD COUNT
  // =========================================================

  Stream<int> getUnreadCount(
      String projectId,
      String userId
      ) {

    return _client
        .from('project_unread_counts')
        .stream(primaryKey: ['project_id','user_id'])
        .map((rows){

      final row = rows.firstWhere(
            (r)=> r['project_id']==projectId
            && r['user_id']==userId,
        orElse: ()=>{},
      );

      if(row.isEmpty) return 0;

      return row['unread_count'] ?? 0;
    });
  }

  // =========================================================
  // TYPING INDICATOR
  // =========================================================

  Future<void> setTyping(
      String projectId,
      bool typing
      ) async {

    final userId = _client.auth.currentUser?.id;
    if(userId == null) return;

    await _client
        .from('chat_typing')
        .upsert({

      'project_id': projectId,
      'user_id': userId,
      'is_typing': typing,
      'updated_at': DateTime.now().toIso8601String(),

    });

    _typingTimer?.cancel();

    if(typing){

      _typingTimer =
          Timer(const Duration(seconds: 3),(){

            setTyping(projectId,false);

          });
    }
  }

  Stream<List<String>> getTypingUsers(String projectId){

    return _client
        .from('chat_typing')
        .stream(primaryKey: ['project_id','user_id'])
        .map((rows){

      return rows
          .where((r)=>
      r['project_id']==projectId &&
          r['is_typing']==true
      )
          .map<String>((r)=> r['user_id'])
          .toList();
    });
  }

  // =========================================================
  // ONLINE PRESENCE HEARTBEAT
  // =========================================================

  void startPresenceHeartbeat(){

    _presenceTimer?.cancel();

    updatePresence();

    _presenceTimer =
        Timer.periodic(
            const Duration(seconds:30),
                (_)=>updatePresence());
  }

  Future<void> updatePresence() async{

    final userId = _client.auth.currentUser?.id;
    if(userId == null) return;

    await _client
        .from('user_presence')
        .upsert({

      'user_id': userId,
      'last_seen': DateTime.now().toIso8601String()

    });
  }

  Stream<List<String>> getOnlineUsers(){

    return _client
        .from('user_presence')
        .stream(primaryKey:['user_id'])
        .map((rows){

      final now = DateTime.now();

      return rows
          .where((r){

        final lastSeen =
        DateTime.tryParse(r['last_seen']);

        if(lastSeen == null) return false;

        return now
            .difference(lastSeen)
            .inSeconds < 60;

      })
          .map<String>((r)=>r['user_id'])
          .toList();
    });
  }

  // =========================================================
  // MARK READ
  // =========================================================

  Future<void> markProjectMessagesAsRead(
      String projectId
      ) async{

    final userId =
        _client.auth.currentUser?.id;

    if(userId == null) return;

    await _client
        .from('project_messages')
        .update({'is_read': true})
        .eq('project_id', projectId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  Stream<MessageModel?> getLastMessage(String projectId) {

    return _client
        .from('project_messages')
        .stream(primaryKey: ['id'])
        .map((rows){

      final filtered = rows
          .where((r)=> r['project_id'] == projectId)
          .map((r)=> MessageModel.fromJson(r))
          .toList();

      if(filtered.isEmpty) return null;

      filtered.sort(
            (a,b)=> b.createdAt.compareTo(a.createdAt),
      );

      return filtered.first;
    });
  }
}

