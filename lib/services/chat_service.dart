import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import '../utils/app_logger.dart';

import 'ai_service.dart';
import 'chat_cache_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class ChatService {
  final SupabaseClient _client = SupabaseService.client;
  final Uuid _uuid = const Uuid();

  final ChatCacheService _cacheService = ChatCacheService();
  final NotificationService _notifications = NotificationService();
  final AIService _aiService = AIService();

  static const int _pageSize = 30;
  static const int _maxUserCacheSize = 150;
  static const int _maxProjectTitleCacheSize = 100;

  static const String _deletedMessageText = 'Message deleted';
  static const String _fallbackUserName = 'User';
  static const String _fallbackProjectTitle = 'Chat';
  static const String _currentUserName = 'You';

  final Map<String, RealtimeChannel> _chatChannels = {};
  final Map<String, StreamController<List<MessageModel>>> _controllers = {};
  final Map<String, List<MessageModel>> _cache = {};
  final Map<String, String> _userCache = {};
  final Map<String, Map<String, String?>> _userProfileCache = {};
  final Map<String, String> _projectTitleCache = {};

  final Set<String> _activeChats = {};
  final Set<String> _loadingProjects = {};
  final Set<String> _loadingMoreProjects = {};
  final Set<String> _disposingProjects = {};

  RealtimeChannel? _unreadChannel;
  String? _unreadUserId;

  final StreamController<Map<String, int>> _unreadController =
  StreamController<Map<String, int>>.broadcast();

  Map<String, int> _lastUnread = {};

  bool _notificationsInitialized = false;
  bool _disposed = false;

  // =========================================================
  // HELPERS
  // =========================================================

  String? get _currentUserId => _client.auth.currentUser?.id;

  bool _isProjectDisposed(String projectId) {
    return _disposed || _disposingProjects.contains(projectId);
  }

  String get _messageSelectQuery => '''
    *,
    profiles:sender_id(
      full_name,
      username,
      avatar_url
    ),
    reply:reply_to_message_id(
      id,
      content,
      type,
      sender_id,
      file_name,
      file_size,
      mime_type,
      preview_url,
      profiles:sender_id(
        full_name,
        username,
        avatar_url
      )
    ),
    message_reads!left(
      user_id
    )
  ''';

  void _sortMessages(List<MessageModel> list) {
    list.sort((a, b) {
      final cmp = b.createdAt.compareTo(a.createdAt);

      if (cmp != 0) {
        return cmp;
      }

      return b.id.compareTo(a.id);
    });
  }

  void _safeEmit(
      String projectId,
      List<MessageModel> list,
      ) {
    if (_isProjectDisposed(projectId)) {
      return;
    }

    final controller = _controllers[projectId];

    if (controller == null || controller.isClosed) {
      return;
    }

    controller.add(
      List<MessageModel>.unmodifiable(list),
    );
  }

  void _cacheMessages(
      String projectId,
      List<MessageModel> messages,
      ) {
    final copy = List<MessageModel>.from(messages);

    _sortMessages(copy);

    _cache[projectId] = copy;

    _cacheService.setMessages(
      projectId,
      copy,
    );
  }

  List<MessageModel> _getProjectCache(String projectId) {
    return List<MessageModel>.from(
      _cache[projectId] ?? const [],
    );
  }

  MessageModel? _findCachedMessage(
      String projectId,
      String? messageId,
      ) {
    if (messageId == null || messageId.isEmpty) {
      return null;
    }

    final list = _cache[projectId] ?? const [];

    for (final message in list) {
      if (message.id == messageId) {
        return message;
      }
    }

    return null;
  }

  Future<void> _ensureNotifications() async {
    if (_notificationsInitialized) {
      return;
    }

    await _notifications.init();

    _notificationsInitialized = true;
  }

  String _extensionFromFileName(String fileName) {
    final clean = fileName.trim();

    if (!clean.contains('.')) {
      return '';
    }

    return clean.split('.').last.toLowerCase().trim();
  }

  bool _isImageExtension(String extension) {
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
      'heif',
    }.contains(extension.toLowerCase());
  }

  MessageType _messageTypeFromFileName(
      String fileName,
      MessageType requestedType,
      ) {
    final extension = _extensionFromFileName(fileName);

    if (_isImageExtension(extension)) {
      return MessageType.image;
    }

    return MessageType.file;
  }

  String _mimeTypeFromFileName(String fileName) {
    final ext = _extensionFromFileName(fileName);

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'gif':
        return 'image/gif';

      case 'bmp':
        return 'image/bmp';

      case 'heic':
        return 'image/heic';

      case 'heif':
        return 'image/heif';

      case 'pdf':
        return 'application/pdf';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'xls':
        return 'application/vnd.ms-excel';

      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      case 'csv':
        return 'text/csv';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';

      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      case 'txt':
        return 'text/plain';

      case 'json':
        return 'application/json';

      case 'zip':
        return 'application/zip';

      case 'rar':
        return 'application/vnd.rar';

      case '7z':
        return 'application/x-7z-compressed';

      default:
        return 'application/octet-stream';
    }
  }

  String _safeStorageFileName(String rawName) {
    final clean = rawName.trim().isEmpty ? 'file' : rawName.trim();

    final safeName = clean.replaceAll(
      RegExp(r'[^a-zA-Z0-9а-яА-ЯёЁ._-]+'),
      '_',
    );

    return safeName.isEmpty ? 'file' : safeName;
  }

  String? _replyPreviewUrlForTemp(MessageModel? replyMessage) {
    if (replyMessage == null) {
      return null;
    }

    if (!replyMessage.isImage) {
      return null;
    }

    final preview = replyMessage.previewUrl?.trim();

    if (preview != null && preview.isNotEmpty) {
      return preview;
    }

    final content = replyMessage.content.trim();

    if (content.isNotEmpty) {
      return content;
    }

    return null;
  }

  // =========================================================
  // USER CACHE
  // =========================================================

  Future<Map<String, String?>> _getUserProfile(String userId) async {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }

    try {
      final res = await _client
          .from('profiles')
          .select(
        '''
            full_name,
            username,
            avatar_url
            ''',
      )
          .eq('id', userId)
          .maybeSingle();

      final fullName = res?['full_name']?.toString().trim();
      final username = res?['username']?.toString().trim();
      final avatarUrl = res?['avatar_url']?.toString().trim();

      final displayName = fullName != null && fullName.isNotEmpty
          ? fullName
          : username != null && username.isNotEmpty
          ? username
          : _fallbackUserName;

      final profile = <String, String?>{
        'full_name': displayName,
        'username': username,
        'avatar_url': avatarUrl != null && avatarUrl.isNotEmpty
            ? avatarUrl
            : null,
      };

      if (_userProfileCache.length >= _maxUserCacheSize) {
        _userProfileCache.remove(
          _userProfileCache.keys.first,
        );
      }

      _userProfileCache[userId] = profile;
      _userCache[userId] = displayName;

      return profile;
    } catch (e, st) {
      AppLogger.error(
        'Get user profile error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      return const {
        'full_name': _fallbackUserName,
        'username': null,
        'avatar_url': null,
      };
    }
  }

  // =========================================================
  // PROJECT TITLE CACHE
  // =========================================================

  Future<String> _getProjectTitle(String projectId) async {
    if (_projectTitleCache.containsKey(projectId)) {
      return _projectTitleCache[projectId]!;
    }

    try {
      final res = await _client
          .from('projects')
          .select('title')
          .eq('id', projectId)
          .maybeSingle();

      final title = res?['title']?.toString().trim();

      final result = title != null && title.isNotEmpty
          ? title
          : _fallbackProjectTitle;

      if (_projectTitleCache.length >= _maxProjectTitleCacheSize) {
        _projectTitleCache.remove(
          _projectTitleCache.keys.first,
        );
      }

      _projectTitleCache[projectId] = result;

      return result;
    } catch (e, st) {
      AppLogger.error(
        'Get project title error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      return _fallbackProjectTitle;
    }
  }

  String _notificationBody(MessageModel message) {
    switch (message.type) {
      case MessageType.image:
        return '📷 Image';

      case MessageType.file:
        final fileName = message.fileName?.trim();

        if (fileName != null && fileName.isNotEmpty) {
          return '📎 $fileName';
        }

        return '📎 File';

      case MessageType.text:
        return message.content;
    }
  }

  Future<void> _showIncomingMessageNotification({
    required String projectId,
    required MessageModel message,
  }) async {
    final projectTitle = await _getProjectTitle(projectId);
    final body = _notificationBody(message);

    await _ensureNotifications();

    await _notifications.showChatNotification(
      projectId: projectId,
      projectTitle: projectTitle,
      senderName: message.senderName,
      message: body,
      payload: projectId,
    );
  }

  // =========================================================
  // CHAT STATE
  // =========================================================

  void setChatActive(
      String projectId,
      bool active,
      ) {
    if (active) {
      _activeChats.add(projectId);
    } else {
      _activeChats.remove(projectId);
    }
  }

  // =========================================================
  // MESSAGE BUILD
  // =========================================================

  Future<MessageModel> _buildMessageFromRow(
      Map<String, dynamic> rawRow,
      ) async {
    final row = Map<String, dynamic>.from(rawRow);
    final currentUserId = _currentUserId;

    if (row['profiles'] == null && row['sender_id'] != null) {
      final senderProfile = await _getUserProfile(
        row['sender_id'].toString(),
      );

      row['profiles'] = {
        'full_name': senderProfile['full_name'],
        'username': senderProfile['username'],
        'avatar_url': senderProfile['avatar_url'],
      };
    }

    if (row['reply_to_message_id'] != null && row['reply'] == null) {
      try {
        final reply = await _client
            .from('project_messages')
            .select('''
              id,
              content,
              type,
              sender_id,
              file_name,
              file_size,
              mime_type,
              preview_url,
              profiles:sender_id(
                full_name,
                username,
                avatar_url
              )
            ''')
            .eq(
          'id',
          row['reply_to_message_id'],
        )
            .maybeSingle();

        if (reply != null) {
          row['reply'] = reply;
        }
      } catch (_) {
        // ignore
      }
    }

    final reads = row['message_reads'] is List
        ? row['message_reads'] as List
        : const [];

    final senderId = row['sender_id']?.toString();
    final isMine = senderId != null && senderId == currentUserId;

    final isRead = isMine ||
        reads.any(
              (r) => r is Map && r['user_id']?.toString() == currentUserId,
        );

    return MessageModel.fromJson(row).copyWith(
      isRead: isRead,
    );
  }
}

extension ChatServiceSubscriptions on ChatService {
  // =========================================================
  // LOAD MESSAGES
  // =========================================================

  Future<List<MessageModel>> loadMessages(
      String projectId,
      ) async {
    if (_isProjectDisposed(projectId)) {
      return [];
    }

    if (_loadingProjects.contains(projectId)) {
      return _getProjectCache(projectId);
    }

    _loadingProjects.add(projectId);

    try {
      final rows = await _client
          .from('project_messages')
          .select(_messageSelectQuery)
          .eq('project_id', projectId)
          .order(
        'created_at',
        ascending: false,
      )
          .limit(ChatService._pageSize);

      if (_isProjectDisposed(projectId)) {
        return [];
      }

      final loaded = <MessageModel>[];

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        loaded.add(
          await _buildMessageFromRow(row),
        );
      }

      final existing = _getProjectCache(projectId);

      final merged = {
        for (final message in existing) message.id: message,
      };

      for (final message in loaded) {
        merged[message.id] = message;
      }

      final result = merged.values.toList();

      _cacheMessages(
        projectId,
        result,
      );

      _safeEmit(
        projectId,
        result,
      );

      return result;
    } catch (e, st) {
      AppLogger.error(
        'Load messages error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      return _getProjectCache(projectId);
    } finally {
      _loadingProjects.remove(projectId);
    }
  }

  // =========================================================
  // SUBSCRIBE
  // =========================================================

  Stream<List<MessageModel>> subscribeMessages(
      String projectId,
      ) {
    if (_disposed) {
      throw Exception('ChatService disposed');
    }

    final existing = _controllers[projectId];

    if (existing != null && !existing.isClosed) {
      return existing.stream;
    }

    _cache.putIfAbsent(
      projectId,
          () => [],
    );

    late final StreamController<List<MessageModel>> controller;

    controller = StreamController<List<MessageModel>>.broadcast(
      onCancel: () async {
        if (!controller.hasListener) {
          await disposeProject(projectId);
        }
      },
    );

    _controllers[projectId] = controller;

    final cached = _cacheService.getMessages(projectId);

    if (cached.isNotEmpty) {
      _cache[projectId] = List<MessageModel>.from(cached);

      _safeEmit(
        projectId,
        cached,
      );
    }

    unawaited(
      loadMessages(projectId),
    );

    _subscribeProjectRealtime(projectId);

    return controller.stream;
  }

  // =========================================================
  // REALTIME SUBSCRIBE
  // =========================================================

  void _subscribeProjectRealtime(
      String projectId,
      ) {
    if (_chatChannels.containsKey(projectId)) {
      return;
    }

    if (_isProjectDisposed(projectId)) {
      return;
    }

    final channel = _client.channel('chat:$projectId');

    _chatChannels[projectId] = channel;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'project_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: (payload) async {
        await _handleInsertRealtime(
          projectId,
          payload,
        );
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'project_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: (payload) async {
        await _handleUpdateRealtime(
          projectId,
          payload,
        );
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'project_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: (payload) async {
        await _handleDeleteRealtime(
          projectId,
          payload,
        );
      },
    );

    channel.subscribe(
          (status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          AppLogger.info(
            'Chat realtime subscribed: $projectId',
            tag: 'ChatService',
          );
          return;
        }

        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          AppLogger.error(
            'Chat realtime error',
            error: error,
            tag: 'ChatService',
          );

          _chatChannels.remove(projectId);

          if (!_isProjectDisposed(projectId)) {
            Future.delayed(
              const Duration(seconds: 2),
                  () {
                if (!_isProjectDisposed(projectId) &&
                    !_chatChannels.containsKey(projectId)) {
                  _subscribeProjectRealtime(projectId);
                }
              },
            );
          }
        }
      },
    );
  }
}

extension ChatServiceMessaging on ChatService {
  // =========================================================
  // REALTIME INSERT
  // =========================================================

  Future<void> _handleInsertRealtime(
      String projectId,
      PostgresChangePayload payload,
      ) async {
    if (_isProjectDisposed(projectId)) {
      return;
    }

    try {
      final row = Map<String, dynamic>.from(payload.newRecord);

      if (row.isEmpty) {
        return;
      }

      final currentUserId = _currentUserId;
      final list = _getProjectCache(projectId);

      final incomingId = row['id']?.toString();

      if (incomingId == null || incomingId.isEmpty) {
        return;
      }

      if (list.any((m) => m.id == incomingId)) {
        return;
      }

      list.removeWhere(
            (m) =>
        m.status == MessageStatus.sending &&
            m.senderId == row['sender_id']?.toString() &&
            m.content == row['content']?.toString(),
      );

      final isMine = row['sender_id']?.toString() == currentUserId;

      bool isRead = false;

      if (!isMine &&
          _activeChats.contains(projectId) &&
          currentUserId != null) {
        isRead = true;

        try {
          await _client.from('message_reads').upsert(
            {
              'message_id': incomingId,
              'user_id': currentUserId,
              'project_id': projectId,
              'read_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'message_id,user_id',
          );
        } catch (e, st) {
          AppLogger.error(
            'Auto read failed',
            error: e,
            stackTrace: st,
            tag: 'ChatService',
          );
        }
      }

      final built = await _buildMessageFromRow(row);

      final message = built.copyWith(
        isRead: isRead || built.isRead,
      );

      list.insert(0, message);

      _cacheMessages(
        projectId,
        list,
      );

      _safeEmit(
        projectId,
        list,
      );

      if (!isMine && !_activeChats.contains(projectId)) {
        await _showIncomingMessageNotification(
          projectId: projectId,
          message: message,
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Realtime INSERT error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );
    }
  }

  // =========================================================
  // REALTIME UPDATE
  // =========================================================

  Future<void> _handleUpdateRealtime(
      String projectId,
      PostgresChangePayload payload,
      ) async {
    if (_isProjectDisposed(projectId)) {
      return;
    }

    try {
      final row = Map<String, dynamic>.from(payload.newRecord);

      if (row.isEmpty) {
        return;
      }

      final incomingId = row['id']?.toString();

      if (incomingId == null || incomingId.isEmpty) {
        return;
      }

      final list = _getProjectCache(projectId);

      final index = list.indexWhere(
            (m) => m.id == incomingId,
      );

      if (index == -1) {
        await loadMessages(projectId);
        return;
      }

      final old = list[index];

      final updated = await _buildMessageFromRow(row);

      list[index] = updated.copyWith(
        isRead: old.isRead,
      );

      _cacheMessages(
        projectId,
        list,
      );

      _safeEmit(
        projectId,
        list,
      );
    } catch (e, st) {
      AppLogger.error(
        'Realtime UPDATE error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );
    }
  }

  // =========================================================
  // REALTIME DELETE
  // =========================================================

  Future<void> _handleDeleteRealtime(
      String projectId,
      PostgresChangePayload payload,
      ) async {
    if (_isProjectDisposed(projectId)) {
      return;
    }

    try {
      final row = Map<String, dynamic>.from(payload.oldRecord);

      if (row.isEmpty) {
        return;
      }

      final id = row['id']?.toString();

      if (id == null || id.isEmpty) {
        return;
      }

      final list = _getProjectCache(projectId);

      list.removeWhere(
            (m) => m.id == id,
      );

      _cacheMessages(
        projectId,
        list,
      );

      _safeEmit(
        projectId,
        list,
      );
    } catch (e, st) {
      AppLogger.error(
        'Realtime DELETE error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );
    }
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage(
      String projectId,
      String content, {
        String? replyTo,
      }) async {
    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    final text = content.trim();

    if (text.isEmpty || text.length > 1000) {
      return;
    }

    final tempId = 'temp_${_uuid.v4()}';
    final replyMessage = _findCachedMessage(projectId, replyTo);
    final senderProfile = await _getUserProfile(userId);

    final temp = MessageModel(
      id: tempId,
      projectId: projectId,
      senderId: userId,
      senderName: senderProfile['full_name'] ?? ChatService._currentUserName,
      senderAvatarUrl: senderProfile['avatar_url'],
      content: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      replyToMessageId: replyTo,
      replyPreview: replyMessage?.replyRawContent.isNotEmpty == true
          ? replyMessage!.replyRawContent
          : replyMessage?.content,
      replySenderName: replyMessage?.senderName,
      replyType: replyMessage?.type,
      replyFileName: replyMessage?.fileName,
      replyPreviewUrl: _replyPreviewUrlForTemp(replyMessage),
      replyMimeType: replyMessage?.mimeType,
      isRead: true,
    );

    final list = _getProjectCache(projectId);

    list.insert(0, temp);

    _cacheMessages(
      projectId,
      list,
    );

    _safeEmit(
      projectId,
      list,
    );

    try {
      await _client.from('project_messages').insert({
        'project_id': projectId,
        'sender_id': userId,
        'content': text,
        'type': 'text',
        'reply_to_message_id': replyTo,
        'is_deleted': false,
        'status': 'sent',
      });
    } catch (e, st) {
      AppLogger.error(
        'Send message error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      list.removeWhere(
            (m) => m.id == tempId,
      );

      _cacheMessages(
        projectId,
        list,
      );

      _safeEmit(
        projectId,
        list,
      );

      rethrow;
    }
  }
}

extension ChatServiceFinal on ChatService {
  // =========================================================
  // EDIT MESSAGE
  // =========================================================

  Future<void> editMessage(
      String messageId,
      String newContent,
      ) async {
    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    final text = newContent.trim();

    if (text.isEmpty) {
      return;
    }

    String? affectedProjectId;
    List<MessageModel>? rollbackList;

    for (final entry in _cache.entries) {
      final projectId = entry.key;
      final list = List<MessageModel>.from(entry.value);

      final index = list.indexWhere(
            (m) => m.id == messageId,
      );

      if (index == -1) {
        continue;
      }

      final current = list[index];

      if (current.senderId != userId ||
          current.isDeleted ||
          !current.isText) {
        return;
      }

      affectedProjectId = projectId;
      rollbackList = List<MessageModel>.from(list);

      list[index] = current.copyWith(
        content: text,
        editedAt: DateTime.now(),
      );

      _cacheMessages(projectId, list);
      _safeEmit(projectId, list);

      break;
    }

    if (affectedProjectId == null) {
      return;
    }

    try {
      await _client
          .from('project_messages')
          .update({
        'content': text,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', messageId)
          .eq('sender_id', userId);
    } catch (e, st) {
      if (rollbackList != null) {
        _cacheMessages(affectedProjectId, rollbackList);
        _safeEmit(affectedProjectId, rollbackList);
      }

      AppLogger.error(
        'Edit message error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      rethrow;
    }
  }

  // =========================================================
  // DELETE MESSAGE
  // =========================================================

  Future<void> deleteMessage(
      String messageId,
      ) async {
    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    String? affectedProjectId;
    List<MessageModel>? rollbackList;

    for (final entry in _cache.entries) {
      final projectId = entry.key;
      final list = List<MessageModel>.from(entry.value);

      final index = list.indexWhere(
            (m) => m.id == messageId,
      );

      if (index == -1) {
        continue;
      }

      final current = list[index];

      if (current.senderId != userId) {
        return;
      }

      affectedProjectId = projectId;
      rollbackList = List<MessageModel>.from(list);

      list[index] = current.copyWith(
        isDeleted: true,
        content: ChatService._deletedMessageText,
      );

      _cacheMessages(projectId, list);
      _safeEmit(projectId, list);

      break;
    }

    if (affectedProjectId == null) {
      return;
    }

    try {
      await _client
          .from('project_messages')
          .update({
        'is_deleted': true,
        'content': ChatService._deletedMessageText,
      })
          .eq('id', messageId)
          .eq('sender_id', userId);
    } catch (e, st) {
      if (rollbackList != null) {
        _cacheMessages(affectedProjectId, rollbackList);
        _safeEmit(affectedProjectId, rollbackList);
      }

      AppLogger.error(
        'Delete message error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      rethrow;
    }
  }

  // =========================================================
  // FILE MESSAGE
  // =========================================================

  Future<void> sendFileMessage({
    required String projectId,
    required MessageType type,
    File? file,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    try {
      final rawName = fileName?.trim().isNotEmpty == true
          ? fileName!.trim()
          : file != null
          ? file.path.split('/').last
          : 'file';

      final safeName = _safeStorageFileName(rawName);

      final uniqueName =
          '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_$safeName';

      final path = 'chat_files/$projectId/$uniqueName';

      final messageType = _messageTypeFromFileName(
        rawName,
        type,
      );

      final mimeType = _mimeTypeFromFileName(rawName);

      int fileSize = 0;

      if (fileBytes != null) {
        fileSize = fileBytes.length;

        await _client.storage.from(SupabaseService.bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
      } else if (file != null) {
        fileSize = await file.length();

        await _client.storage.from(SupabaseService.bucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
      } else {
        return;
      }

      final url = _client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);

      await _client.from('project_messages').insert({
        'project_id': projectId,
        'sender_id': userId,
        'content': url,
        'type': messageType == MessageType.image ? 'image' : 'file',
        'file_name': rawName,
        'file_size': fileSize,
        'mime_type': mimeType,
        'preview_url': messageType == MessageType.image ? url : null,
        'status': 'sent',
        'is_deleted': false,
      });
    } catch (e, st) {
      AppLogger.error(
        'File send error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );

      rethrow;
    }
  }

  // =========================================================
  // LOAD MORE
  // =========================================================

  Future<void> loadMore(
      String projectId,
      ) async {
    if (_loadingMoreProjects.contains(projectId)) {
      return;
    }

    final current = _getProjectCache(projectId);

    if (current.isEmpty) {
      return;
    }

    _loadingMoreProjects.add(projectId);

    try {
      final last = current.last;

      final rows = await _client
          .from('project_messages')
          .select(_messageSelectQuery)
          .eq('project_id', projectId)
          .lt(
        'created_at',
        last.createdAt.toUtc().toIso8601String(),
      )
          .order(
        'created_at',
        ascending: false,
      )
          .limit(ChatService._pageSize);

      if (rows.isEmpty) {
        return;
      }

      final loaded = <MessageModel>[];

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        loaded.add(
          await _buildMessageFromRow(row),
        );
      }

      final merged = {
        for (final message in current) message.id: message,
      };

      for (final message in loaded) {
        merged[message.id] = message;
      }

      final result = merged.values.toList();

      _cacheMessages(projectId, result);
      _safeEmit(projectId, result);
    } catch (e, st) {
      AppLogger.error(
        'Load more messages error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );
    } finally {
      _loadingMoreProjects.remove(projectId);
    }
  }

  // =========================================================
  // TRANSLATE
  // =========================================================

  Future<String> translateMessage(
      String text,
      String targetLanguage,
      ) async {
    return _aiService.translate(
      text: text,
      targetLanguage: targetLanguage,
    );
  }

  Future<String> detectMessageLanguage(
      String text,
      ) async {
    return _aiService.detectLanguage(text);
  }

  // =========================================================
  // MARK READ
  // =========================================================

  Future<void> markProjectMessagesAsRead(
      String projectId,
      ) async {
    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    try {
      final rows = await _client
          .from('project_messages')
          .select('id, sender_id')
          .eq('project_id', projectId)
          .neq('sender_id', userId);

      if (rows.isEmpty) {
        return;
      }

      final inserts = rows.map((m) {
        return {
          'message_id': m['id'],
          'user_id': userId,
          'project_id': projectId,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();

      await _client.from('message_reads').upsert(
        inserts,
        onConflict: 'message_id,user_id',
      );

      final list = _getProjectCache(projectId);

      for (int i = 0; i < list.length; i++) {
        if (list[i].senderId != userId) {
          list[i] = list[i].copyWith(
            isRead: true,
          );
        }
      }

      _cacheMessages(projectId, list);
      _safeEmit(projectId, list);
    } catch (e, st) {
      AppLogger.error(
        'Mark read error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );
    }
  }

  // =========================================================
  // UNREAD COUNTS
  // =========================================================

  Stream<Map<String, int>> getAllUnreadCounts(
      String userId,
      ) {
    if (_unreadUserId != userId) {
      _resetUnreadRealtime();
      _subscribeUnread(userId);
    }

    unawaited(
      _loadUnread(userId),
    );

    return _unreadController.stream;
  }

  void _subscribeUnread(
      String userId,
      ) {
    if (_disposed) {
      return;
    }

    final channel = _client.channel('unread:$userId');

    _unreadUserId = userId;
    _unreadChannel = channel;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reads',
      callback: (_) async {
        await _loadUnread(userId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_messages',
      callback: (_) async {
        await _loadUnread(userId);
      },
    );

    channel.subscribe(
          (status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          AppLogger.error(
            'Unread realtime error',
            error: error,
            tag: 'ChatService',
          );
        }
      },
    );
  }

  Future<void> _loadUnread(
      String userId,
      ) async {
    try {
      final rows = await _client
          .from('unread_counts')
          .select()
          .eq('user_id', userId);

      final map = <String, int>{};

      for (final row in rows) {
        final projectId = row['project_id']?.toString();

        if (projectId == null || projectId.isEmpty) {
          continue;
        }

        final unreadValue =
            row['unread'] ?? row['unread_count'] ?? row['count'];

        map[projectId] = unreadValue is num
            ? unreadValue.toInt()
            : int.tryParse(unreadValue?.toString() ?? '0') ?? 0;
      }

      if (_mapEquals(
        map,
        _lastUnread,
      )) {
        return;
      }

      _lastUnread = Map<String, int>.from(map);

      if (!_unreadController.isClosed) {
        _unreadController.add(
          Map<String, int>.unmodifiable(map),
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Unread load error',
        error: e,
        stackTrace: st,
        tag: 'ChatService',
      );
    }
  }

  bool _mapEquals(
      Map<String, int> a,
      Map<String, int> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (final key in a.keys) {
      if (a[key] != b[key]) {
        return false;
      }
    }

    return true;
  }

  void _resetUnreadRealtime() {
    final channel = _unreadChannel;

    _unreadChannel = null;
    _unreadUserId = null;
    _lastUnread = {};

    if (channel != null) {
      unawaited(
        _client.removeChannel(channel),
      );
    }
  }

  Future<void> forceReloadUnread(
      String userId,
      ) async {
    await _loadUnread(userId);
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  Future<void> disposeProject(
      String projectId,
      ) async {
    if (_disposingProjects.contains(projectId)) {
      return;
    }

    _disposingProjects.add(projectId);

    try {
      final channel = _chatChannels.remove(projectId);

      if (channel != null) {
        await channel.unsubscribe();
        await _client.removeChannel(channel);
      }

      final controller = _controllers.remove(projectId);

      if (controller != null && !controller.isClosed) {
        await controller.close();
      }

      _cache.remove(projectId);
      _activeChats.remove(projectId);
      _loadingProjects.remove(projectId);
      _loadingMoreProjects.remove(projectId);
      _projectTitleCache.remove(projectId);

      _cacheService.clearProject(projectId);
    } finally {
      _disposingProjects.remove(projectId);
    }
  }

  Future<void> dispose() async {
    _disposed = true;

    for (final id in _chatChannels.keys.toList()) {
      await disposeProject(id);
    }

    _resetUnreadRealtime();

    if (!_unreadController.isClosed) {
      await _unreadController.close();
    }

    _controllers.clear();
    _cache.clear();
    _activeChats.clear();
    _lastUnread = {};
    _userCache.clear();
    _userProfileCache.clear();
    _projectTitleCache.clear();

    _cacheService.clearAll();
  }
}