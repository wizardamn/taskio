import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();

  Stream<List<MessageModel>>? messagesStream;

  List<MessageModel> cachedMessages = [];

  Set<String> readMessages = {};
  Set<String> otherReadMessages = {};

  final Set<String> _pendingReads = {};
  final Map<String, String> _userNameCache = {};

  String? typingUser;
  Map<String, bool> onlineUsers = {};

  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _typingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _presenceSub;
  StreamSubscription<List<Map<String, dynamic>>>? _readsSub;

  Timer? _typingDebounce;
  Timer? _readDebounce;

  String? _currentProjectId;

  bool _initialized = false;
  bool _isLoadingMore = false;
  bool _disposed = false;
  bool _isSwitchingProject = false;

  bool? _lastTypingState;

  String? get currentUserId =>
      SupabaseService.client.auth.currentUser?.id;

  bool get isLoadingMore => _isLoadingMore;

  String? get currentProjectId => _currentProjectId;

  // =========================================================
  // PROJECT CHANGE
  // =========================================================

  Future<void> handleProjectChange(
      String? projectId,
      ) async {
    if (_disposed || projectId == null || projectId.isEmpty) {
      return;
    }

    if (_currentProjectId == projectId &&
        _initialized &&
        _messagesSub != null) {
      return;
    }

    await init(projectId);
  }

  Stream<Map<String, int>> getAllUnreadCounts(
      String userId,
      ) {
    return _chatService.getAllUnreadCounts(userId);
  }

  // =========================================================
  // TRANSLATE
  // =========================================================

  Future<String> translateMessage(
      String text,
      String targetLanguage,
      ) async {
    return _chatService.translateMessage(
      text,
      targetLanguage,
    );
  }

  Future<String> detectMessageLanguage(
      String text,
      ) async {
    return _chatService.detectMessageLanguage(text);
  }

  // =========================================================
  // INIT
  // =========================================================

  Future<void> init(
      String projectId,
      ) async {
    if (_disposed || _isSwitchingProject) {
      return;
    }

    if (_initialized &&
        _currentProjectId == projectId &&
        _messagesSub != null) {
      return;
    }

    _isSwitchingProject = true;

    try {
      if (_currentProjectId != null &&
          _currentProjectId != projectId) {
        await disposeStreams(
          clearCurrent: false,
          markOffline: true,
        );
      }

      if (_disposed) {
        return;
      }

      _initialized = true;
      _currentProjectId = projectId;
      _lastTypingState = null;

      _resetChatState();

      await _loadParticipants(projectId);

      if (_disposed || _currentProjectId != projectId) {
        return;
      }

      _chatService.setChatActive(
        projectId,
        true,
      );

      messagesStream =
          _chatService.subscribeMessages(projectId);

      await _messagesSub?.cancel();

      _messagesSub = messagesStream?.listen(
            (messages) {
          if (_disposed ||
              _currentProjectId != projectId) {
            return;
          }

          cachedMessages =
          List<MessageModel>.from(messages);

          _markLocalRead();

          if (_pendingReads.isNotEmpty) {
            _scheduleRead(projectId);
          }

          _safeNotify();
        },
        onError: (e, st) {
          AppLogger.error(
            'Messages stream error',
            tag: 'ChatProvider',
            error: e,
            stackTrace: st,
          );
        },
      );

      _listenTyping(projectId);
      _listenPresence(projectId);
      _listenReads(projectId);

      await setOnline(
        projectId,
        true,
      );

      _markLocalRead();

      if (_pendingReads.isNotEmpty) {
        await markAsRead(projectId);
      }

      _safeNotify();
    } catch (e, st) {
      AppLogger.error(
        'ChatProvider init failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isSwitchingProject = false;
    }
  }

  void _resetChatState() {
    typingUser = null;
    onlineUsers = {};

    cachedMessages = [];

    readMessages = {};
    otherReadMessages = {};

    _pendingReads.clear();
    _userNameCache.clear();
  }

  Future<void> _loadParticipants(
      String projectId,
      ) async {
    try {
      final rows = await SupabaseService.client
          .from('project_members')
          .select(
        'member_id, profiles(full_name, username)',
      )
          .eq(
        'project_id',
        projectId,
      );

      _userNameCache.clear();

      for (final row in rows) {
        final userId =
        row['member_id']?.toString();

        if (userId == null || userId.isEmpty) {
          continue;
        }

        String? fullName;
        String? username;

        final profile = row['profiles'];

        if (profile is Map<String, dynamic>) {
          fullName =
              profile['full_name']?.toString();
          username =
              profile['username']?.toString();
        } else if (profile is List &&
            profile.isNotEmpty &&
            profile.first is Map<String, dynamic>) {
          final first =
          profile.first as Map<String, dynamic>;

          fullName =
              first['full_name']?.toString();
          username =
              first['username']?.toString();
        }

        final name =
        fullName != null && fullName.trim().isNotEmpty
            ? fullName.trim()
            : username != null &&
            username.trim().isNotEmpty
            ? '@${username.trim()}'
            : 'User';

        _userNameCache[userId] = name;
      }
    } catch (e, st) {
      AppLogger.error(
        'Load participants failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );
    }
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage(
      String projectId,
      String text,
      String? replyId,
      ) async {
    if (_disposed) {
      return;
    }

    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return;
    }

    try {
      await _chatService.sendMessage(
        projectId,
        trimmed,
        replyTo: replyId,
      );
    } catch (e, st) {
      AppLogger.error(
        'Send message failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );

      rethrow;
    } finally {
      setTyping(
        projectId,
        false,
      );
    }
  }

  // =========================================================
  // SEND FILE
  // =========================================================

  Future<void> sendFile({
    required String projectId,
    Uint8List? bytes,
    File? file,
    required String fileName,
    required MessageType type,
  }) async {
    if (_disposed) {
      return;
    }

    try {
      await _chatService.sendFileMessage(
        projectId: projectId,
        fileBytes: bytes,
        file: file,
        fileName: fileName,
        type: type,
      );
    } catch (e, st) {
      AppLogger.error(
        'Send file failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );

      rethrow;
    } finally {
      setTyping(
        projectId,
        false,
      );
    }
  }

  // =========================================================
  // EDIT / DELETE
  // =========================================================

  Future<void> editMessage(
      String messageId,
      String newText,
      ) async {
    if (_disposed) {
      return;
    }

    final trimmed = newText.trim();

    if (trimmed.isEmpty) {
      return;
    }

    try {
      await _chatService.editMessage(
        messageId,
        trimmed,
      );
    } catch (e, st) {
      AppLogger.error(
        'Edit message failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  Future<void> deleteMessage(
      String messageId,
      ) async {
    if (_disposed) {
      return;
    }

    try {
      await _chatService.deleteMessage(
        messageId,
      );
    } catch (e, st) {
      AppLogger.error(
        'Delete message failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }

  // =========================================================
  // READS
  // =========================================================

  void _scheduleRead(
      String projectId,
      ) {
    _readDebounce?.cancel();

    _readDebounce = Timer(
      const Duration(milliseconds: 500),
          () {
        if (_disposed ||
            _currentProjectId != projectId) {
          return;
        }

        unawaited(
          markAsRead(projectId),
        );
      },
    );
  }

  void _markLocalRead() {
    final userId = currentUserId;

    if (userId == null || _disposed) {
      return;
    }

    for (final message in cachedMessages.take(50)) {
      if (message.isDeleted) {
        continue;
      }

      if (message.senderId == userId) {
        continue;
      }

      if (readMessages.contains(message.id)) {
        continue;
      }

      readMessages.add(message.id);
      _pendingReads.add(message.id);
    }
  }

  Future<void> markAsRead(
      String projectId,
      ) async {
    if (_disposed ||
        _currentProjectId != projectId) {
      return;
    }

    final userId = currentUserId;

    if (userId == null || _pendingReads.isEmpty) {
      return;
    }

    final toSend =
    List<String>.from(_pendingReads);

    _pendingReads.clear();

    try {
      await SupabaseService.client
          .from('message_reads')
          .upsert(
        toSend
            .map(
              (id) => {
            'message_id': id,
            'user_id': userId,
            'project_id': projectId,
          },
        )
            .toList(),
        onConflict: 'message_id,user_id',
      );

      await _chatService.forceReloadUnread(
        userId,
      );
    } catch (e, st) {
      _pendingReads.addAll(toSend);

      AppLogger.error(
        'Mark as read failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _listenReads(
      String projectId,
      ) {
    unawaited(_readsSub?.cancel());

    _readsSub = SupabaseService.client
        .from('message_reads')
        .stream(
      primaryKey: [
        'message_id',
        'user_id',
      ],
    )
        .eq(
      'project_id',
      projectId,
    )
        .listen(
          (data) {
        if (_disposed ||
            _currentProjectId != projectId) {
          return;
        }

        final myId = currentUserId;

        if (myId == null) {
          return;
        }

        final myReads = <String>{};
        final otherReads = <String>{};

        for (final row in data) {
          final msgId =
          row['message_id']?.toString();

          final userId =
          row['user_id']?.toString();

          if (msgId == null || userId == null) {
            continue;
          }

          if (userId == myId) {
            myReads.add(msgId);
          } else {
            otherReads.add(msgId);
          }
        }

        readMessages = {
          ...myReads,
          ..._pendingReads,
        };

        otherReadMessages = otherReads;

        _safeNotify();
      },
      onError: (e, st) {
        AppLogger.error(
          'Reads stream error',
          tag: 'ChatProvider',
          error: e,
          stackTrace: st,
        );
      },
    );
  }

  // =========================================================
  // TYPING
  // =========================================================

  void _listenTyping(
      String projectId,
      ) {
    unawaited(_typingSub?.cancel());

    _typingSub = SupabaseService.client
        .from('chat_typing')
        .stream(
      primaryKey: [
        'project_id',
        'user_id',
      ],
    )
        .eq(
      'project_id',
      projectId,
    )
        .listen(
          (data) {
        if (_disposed ||
            _currentProjectId != projectId) {
          return;
        }

        String? typingName;

        for (final row in data) {
          final userId =
          row['user_id']?.toString();

          if (userId == null ||
              userId == currentUserId) {
            continue;
          }

          if (row['is_typing'] == true) {
            typingName =
                _userNameCache[userId] ?? 'User';
            break;
          }
        }

        if (typingUser != typingName) {
          typingUser = typingName;
          _safeNotify();
        }
      },
      onError: (e, st) {
        AppLogger.error(
          'Typing stream error',
          tag: 'ChatProvider',
          error: e,
          stackTrace: st,
        );
      },
    );
  }

  void setTyping(
      String projectId,
      bool isTyping,
      ) {
    if (_disposed ||
        currentUserId == null ||
        _currentProjectId != projectId) {
      return;
    }

    if (_lastTypingState == isTyping) {
      return;
    }

    _lastTypingState = isTyping;

    _typingDebounce?.cancel();

    _typingDebounce = Timer(
      const Duration(milliseconds: 400),
          () async {
        if (_disposed ||
            currentUserId == null ||
            _currentProjectId != projectId) {
          return;
        }

        try {
          await SupabaseService.client
              .from('chat_typing')
              .upsert({
            'project_id': projectId,
            'user_id': currentUserId,
            'is_typing': isTyping,
          });
        } catch (e, st) {
          AppLogger.error(
            'Typing update failed',
            tag: 'ChatProvider',
            error: e,
            stackTrace: st,
          );
        }
      },
    );
  }

  Future<void> _forceTypingOff(
      String projectId,
      ) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    try {
      await SupabaseService.client
          .from('chat_typing')
          .upsert({
        'project_id': projectId,
        'user_id': userId,
        'is_typing': false,
      });
    } catch (_) {}
  }

  // =========================================================
  // PRESENCE
  // =========================================================

  void _listenPresence(
      String projectId,
      ) {
    unawaited(_presenceSub?.cancel());

    _presenceSub = SupabaseService.client
        .from('chat_presence')
        .stream(
      primaryKey: [
        'project_id',
        'user_id',
      ],
    )
        .eq(
      'project_id',
      projectId,
    )
        .listen(
          (data) {
        if (_disposed ||
            _currentProjectId != projectId) {
          return;
        }

        final map = <String, bool>{};

        for (final row in data) {
          final userId =
          row['user_id']?.toString();

          if (userId == null) {
            continue;
          }

          map[userId] =
              row['is_online'] == true;
        }

        onlineUsers = map;
        _safeNotify();
      },
      onError: (e, st) {
        AppLogger.error(
          'Presence stream error',
          tag: 'ChatProvider',
          error: e,
          stackTrace: st,
        );
      },
    );
  }

  Future<void> setOnline(
      String projectId,
      bool isOnline,
      ) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    try {
      await SupabaseService.client
          .from('chat_presence')
          .upsert({
        'project_id': projectId,
        'user_id': userId,
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      AppLogger.error(
        'Presence update failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );
    }
  }

  // =========================================================
  // PAGINATION
  // =========================================================

  Future<void> loadMore(
      String projectId,
      ) async {
    if (_disposed ||
        _isLoadingMore ||
        _currentProjectId != projectId) {
      return;
    }

    _isLoadingMore = true;
    _safeNotify();

    try {
      await _chatService.loadMore(projectId);
    } catch (e, st) {
      AppLogger.error(
        'Load more messages failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isLoadingMore = false;
      _safeNotify();
    }
  }

  // =========================================================
  // NOTIFY
  // =========================================================

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  Future<void> disposeStreams({
    bool clearCurrent = true,
    bool markOffline = true,
  }) async {
    final projectId = _currentProjectId;
    _typingDebounce?.cancel();
    _typingDebounce = null;
    _readDebounce?.cancel();
    _readDebounce = null;
    if (projectId != null && markOffline) {
      await _forceTypingOff(projectId);
      await setOnline(
        projectId,
        false,
      );
      _chatService.setChatActive(
        projectId,
        false,
      );
    }
    await _typingSub?.cancel();
    _typingSub = null;
    await _messagesSub?.cancel();
    _messagesSub = null;
    await _presenceSub?.cancel();
    _presenceSub = null;
    await _readsSub?.cancel();
    _readsSub = null;
    if (projectId != null) {
      await _chatService.disposeProject(
        projectId,
      );
    }
    messagesStream = null;
    if (clearCurrent) {
      _currentProjectId = null;
    }
    _initialized = false;
    _lastTypingState = null;
    _resetChatState();
  }

  void disposeProject(
      String projectId,
      ) {
    if (_currentProjectId == projectId) {
      unawaited(
        disposeStreams(),
      );
    }
  }

  @override
  void dispose() {
    unawaited(
      disposeStreams(
        markOffline: true,
      ),
    );
    unawaited(
      _chatService.dispose(),
    );
    _disposed = true;
    super.dispose();
  }
}