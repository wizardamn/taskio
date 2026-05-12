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

  String? typingUser;
  Map<String, bool> onlineUsers = {};

  final Map<String, String> _userNameCache = {};

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

  bool? _lastTypingState;

  String? get currentUserId =>
      SupabaseService.client.auth.currentUser?.id;

  bool get isLoadingMore => _isLoadingMore;

  // =========================================================
  // PROJECT CHANGE
  // =========================================================

  Future<void> handleProjectChange(String? projectId) async {
    if (_disposed || projectId == null) {
      return;
    }

    if (_currentProjectId == projectId &&
        _messagesSub != null) {
      return;
    }

    AppLogger.info(
      'OPEN CHAT: $projectId',
      tag: 'ChatProvider',
    );

    await init(projectId);
  }

  Stream<Map<String, int>> getAllUnreadCounts(
      String userId,
      ) {
    return _chatService.getAllUnreadCounts(userId);
  }

  // =========================================================
  // INIT
  // =========================================================

  Future<void> init(String projectId) async {
    if (_disposed) {
      return;
    }

    if (_initialized &&
        _currentProjectId == projectId &&
        _messagesSub != null) {
      return;
    }

    if (_currentProjectId != null &&
        _currentProjectId != projectId) {
      await disposeStreams(clearCurrent: false);
    }

    _initialized = true;
    _currentProjectId = projectId;
    _lastTypingState = null;

    typingUser = null;
    onlineUsers.clear();
    cachedMessages = <MessageModel>[];

    readMessages = <String>{};
    otherReadMessages = <String>{};
    _pendingReads.clear();

    _userNameCache.clear();

    _chatService.setChatActive(projectId, true);

    final currentId = projectId;

    messagesStream =
        _chatService.subscribeMessages(currentId);

    unawaited(_messagesSub?.cancel());

    _messagesSub = messagesStream?.listen(
          (messages) {
        if (_disposed ||
            _currentProjectId != currentId) {
          return;
        }

        cachedMessages = List<MessageModel>.from(messages);

        _markLocalRead();

        if (_pendingReads.isNotEmpty) {
          _scheduleRead(currentId);
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

    _listenTyping(currentId);
    _listenPresence(currentId);
    _listenReads(currentId);

    unawaited(setOnline(currentId, true));
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
    } finally {
      setTyping(projectId, false);
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
    } finally {
      setTyping(projectId, false);
    }
  }

  // =========================================================
  // READS
  // =========================================================

  void _scheduleRead(String projectId) {
    _readDebounce?.cancel();

    _readDebounce = Timer(
      const Duration(milliseconds: 500),
          () {
        if (_disposed ||
            _currentProjectId != projectId) {
          return;
        }

        unawaited(markAsRead(projectId));
      },
    );
  }

  void _markLocalRead() {
    final userId = currentUserId;

    if (userId == null || _disposed) {
      return;
    }

    bool changed = false;

    for (final m in cachedMessages.take(50)) {
      if (m.isDeleted) continue;
      if (m.senderId == userId) continue;
      if (readMessages.contains(m.id)) continue;

      readMessages.add(m.id);
      _pendingReads.add(m.id);
      changed = true;
    }

    if (changed) {
      _safeNotify();
    }
  }

  Future<void> markAsRead(String projectId) async {
    if (_disposed) {
      return;
    }

    final userId = currentUserId;

    if (userId == null || _pendingReads.isEmpty) {
      return;
    }

    final toSend = _pendingReads.toList();
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

      await _chatService.forceReloadUnread(userId);
    } catch (e, st) {
      _pendingReads.addAll(toSend);

      AppLogger.error(
        'markAsRead failed',
        tag: 'ChatProvider',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _listenReads(String projectId) {
    unawaited(_readsSub?.cancel());

    _readsSub = SupabaseService.client
        .from('message_reads')
        .stream(
      primaryKey: ['message_id', 'user_id'],
    )
        .eq('project_id', projectId)
        .listen((data) {
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
        final msgId = row['message_id'].toString();
        final userId = row['user_id'].toString();

        if (userId == myId) {
          myReads.add(msgId);
        } else {
          otherReads.add(msgId);
        }
      }

      if (!_setEquals(myReads, readMessages) ||
          !_setEquals(
            otherReads,
            otherReadMessages,
          )) {
        otherReadMessages = Set<String>.from(otherReads);
        readMessages = Set<String>.from(myReads);
        _safeNotify();
      }
    });
  }

  // =========================================================
  // TYPING
  // =========================================================

  void _listenTyping(String projectId) {
    unawaited(_typingSub?.cancel());

    _typingSub = SupabaseService.client
        .from('chat_typing')
        .stream(
      primaryKey: ['project_id', 'user_id'],
    )
        .eq('project_id', projectId)
        .listen((data) async {
      if (_disposed ||
          _currentProjectId != projectId) {
        return;
      }

      String? typingName;

      for (final row in data) {
        final userId = row['user_id'].toString();

        if (row['is_typing'] == true &&
            userId != currentUserId) {
          typingName =
              _userNameCache[userId] ?? 'User';
          break;
        }
      }

      if (typingUser != typingName) {
        typingUser = typingName;
        _safeNotify();
      }
    });
  }

  void setTyping(
      String projectId,
      bool isTyping,
      ) {
    if (_disposed || currentUserId == null) {
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

  Future<void> _forceTypingOff(String projectId) async {
    final userId = currentUserId;

    if (userId == null || _disposed) {
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

  void _listenPresence(String projectId) {
    unawaited(_presenceSub?.cancel());

    _presenceSub = SupabaseService.client
        .from('chat_presence')
        .stream(
      primaryKey: ['project_id', 'user_id'],
    )
        .eq('project_id', projectId)
        .listen((data) {
      if (_disposed ||
          _currentProjectId != projectId) {
        return;
      }

      final newOnline = <String, bool>{};

      for (final row in data) {
        newOnline[row['user_id'].toString()] =
            row['is_online'] == true;
      }

      if (!_mapEquals(newOnline, onlineUsers)) {
        onlineUsers = newOnline;
        _safeNotify();
      }
    });
  }

  Future<void> setOnline(
      String projectId,
      bool isOnline,
      ) async {
    if (_disposed) {
      return;
    }

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
        'last_seen':
        DateTime.now().toIso8601String(),
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

  Future<void> loadMore(String projectId) async {
    if (_disposed || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    _safeNotify();

    try {
      await _chatService.loadMore(projectId);
    } finally {
      _isLoadingMore = false;
      _safeNotify();
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  bool _mapEquals(
      Map<String, bool> a,
      Map<String, bool> b,
      ) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }

    return true;
  }

  bool _setEquals(
      Set<String> a,
      Set<String> b,
      ) {
    if (a.length != b.length) return false;

    for (final item in a) {
      if (!b.contains(item)) {
        return false;
      }
    }

    return true;
  }

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
  }) async {
    if (_disposed) return;

    final projectId = _currentProjectId;

    if (projectId != null) {
      unawaited(_forceTypingOff(projectId));
      unawaited(setOnline(projectId, false));
      _chatService.setChatActive(projectId, false);
    }

    await _typingSub?.cancel();
    _typingSub = null;

    await _messagesSub?.cancel();
    _messagesSub = null;

    await _presenceSub?.cancel();
    _presenceSub = null;

    await _readsSub?.cancel();
    _readsSub = null;

    _typingDebounce?.cancel();
    _readDebounce?.cancel();

    if (projectId != null) {
      await _chatService.disposeProject(projectId);
    }

    if (clearCurrent) {
      _currentProjectId = null;
    }

    _initialized = false;
    _lastTypingState = null;

    typingUser = null;
    onlineUsers.clear();
    cachedMessages = <MessageModel>[];

    readMessages = <String>{};
    otherReadMessages = <String>{};
    _pendingReads.clear();

    _userNameCache.clear();
    messagesStream = null;
  }

  void disposeProject(String projectId) {
    if (_currentProjectId == projectId) {
      unawaited(disposeStreams());
    }
  }

  @override
  void dispose() {
    _disposed = true;

    unawaited(disposeStreams());
    unawaited(_chatService.dispose());

    super.dispose();
  }
}