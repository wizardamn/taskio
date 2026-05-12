import '../models/message_model.dart';

class ChatCacheService {
  static final ChatCacheService _instance =
  ChatCacheService._internal();

  factory ChatCacheService() => _instance;

  ChatCacheService._internal();

  final Map<String, List<MessageModel>> _cache = {};

  // =========================================================
  // GET
  // =========================================================

  List<MessageModel> getMessages(String projectId) {
    final messages = _cache[projectId];

    if (messages == null) {
      return [];
    }

    return List<MessageModel>.from(messages);
  }

  bool hasProject(String projectId) {
    return _cache.containsKey(projectId);
  }

  bool hasMessages(String projectId) {
    final messages = _cache[projectId];
    return messages != null && messages.isNotEmpty;
  }

  // =========================================================
  // SET
  // =========================================================

  void setMessages(
      String projectId,
      List<MessageModel> messages,
      ) {
    _cache[projectId] =
    List<MessageModel>.from(messages);
  }

  // =========================================================
  // ADD
  // =========================================================

  void addMessage(
      String projectId,
      MessageModel message,
      ) {
    final list =
    _cache.putIfAbsent(projectId, () => []);

    final exists = list.any(
          (m) => m.id == message.id,
    );

    if (exists) {
      updateMessage(projectId, message);
      return;
    }

    list.insert(0, message);
  }

  // =========================================================
  // UPDATE
  // =========================================================

  void updateMessage(
      String projectId,
      MessageModel updatedMessage,
      ) {
    final list = _cache[projectId];

    if (list == null) {
      _cache[projectId] = [updatedMessage];
      return;
    }

    final index = list.indexWhere(
          (m) => m.id == updatedMessage.id,
    );

    if (index == -1) {
      list.insert(0, updatedMessage);
      return;
    }

    list[index] = updatedMessage;
  }

  // =========================================================
  // REMOVE
  // =========================================================

  void removeMessage(
      String projectId,
      String messageId,
      ) {
    final list = _cache[projectId];

    if (list == null) return;

    list.removeWhere(
          (m) => m.id == messageId,
    );

    if (list.isEmpty) {
      _cache.remove(projectId);
    }
  }

  // =========================================================
  // CLEAR
  // =========================================================

  void clearProject(String projectId) {
    _cache.remove(projectId);
  }

  void clearAll() {
    _cache.clear();
  }
}