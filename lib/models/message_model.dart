enum MessageType {
  text,
  image,
  file,
}

class MessageModel {
  final String id;
  final String projectId;
  final String senderId;
  final String senderName;

  final String content;
  final DateTime createdAt;

  final MessageType type;

  final bool isRead;

  /// AI translation
  final String? originalLanguage;
  final String? translatedContent;

  /// message edited
  final DateTime? editedAt;

  /// soft delete
  final bool isDeleted;

  /// reply
  final String? replyTo;

  const MessageModel({
    required this.id,
    required this.projectId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.type = MessageType.text,
    this.isRead = false,
    this.originalLanguage,
    this.translatedContent,
    this.editedAt,
    this.isDeleted = false,
    this.replyTo,
  });

  // =====================================================
  // FACTORY FROM JSON (Supabase)
  // =====================================================

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final profile = _extractProfile(json);

    final sender =
        profile?['full_name'] ??
            json['sender_name'] ??
            '';

    return MessageModel(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: sender.toString(),

      content: json['content']?.toString() ?? '',

      createdAt: _parseDate(json['created_at']),

      type: _parseType(json['type']),

      isRead: json['is_read'] ?? false,

      originalLanguage: json['original_language']?.toString(),
      translatedContent: json['translated_content']?.toString(),

      editedAt: _parseDateNullable(json['edited_at']),

      isDeleted: json['is_deleted'] ?? false,

      replyTo: json['reply_to_message_id']?.toString(),
    );
  }

  // =====================================================
  // PROFILE PARSER (Supabase join)
  // =====================================================

  static Map<String, dynamic>? _extractProfile(
      Map<String, dynamic> json) {
    final raw = json['profiles'];

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is List && raw.isNotEmpty) {
      return raw.first as Map<String, dynamic>;
    }

    return null;
  }

  // =====================================================
  // DATE PARSER
  // =====================================================

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is DateTime) return value.toLocal();

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toLocal() ?? DateTime.now();
    }

    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value.toLocal();

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toLocal();
    }

    return null;
  }

  // =====================================================
  // TYPE PARSER
  // =====================================================

  static MessageType _parseType(dynamic value) {
    switch (value) {
      case 'image':
        return MessageType.image;

      case 'file':
        return MessageType.file;

      case 'text':
      default:
        return MessageType.text;
    }
  }

  // =====================================================
  // DISPLAY CONTENT
  // =====================================================

  String get displayContent {
    if (isDeleted) {
      return 'Message deleted';
    }

    return content;
  }

  // =====================================================
  // PREVIEW TEXT (ProjectCard)
  // =====================================================

  String get previewText {
    if (isDeleted) return 'Message deleted';

    switch (type) {
      case MessageType.image:
        return '📷 Photo';

      case MessageType.file:
        return '📎 File';

      case MessageType.text:
        if (content.length > 40) {
          return '${content.substring(0, 40)}...';
        }
        return content;
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  bool get isEdited => editedAt != null;

  bool get hasTranslation =>
      translatedContent != null &&
          translatedContent!.isNotEmpty;

  bool get isImage => type == MessageType.image;

  bool get isFile => type == MessageType.file;

  bool get isText => type == MessageType.text;

  // =====================================================
  // TO JSON (for insert)
  // =====================================================

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'type': type.name,
      'is_read': isRead,
      'original_language': originalLanguage,
      'translated_content': translatedContent,
      'edited_at': editedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'reply_to_message_id': replyTo,
    };
  }

  // =====================================================
  // COPY WITH
  // =====================================================

  MessageModel copyWith({
    String? content,
    String? translatedContent,
    bool? isRead,
    DateTime? editedAt,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id,
      projectId: projectId,
      senderId: senderId,
      senderName: senderName,
      content: content ?? this.content,
      createdAt: createdAt,
      type: type,
      isRead: isRead ?? this.isRead,
      originalLanguage: originalLanguage,
      translatedContent:
      translatedContent ?? this.translatedContent,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      replyTo: replyTo,
    );
  }

  // =====================================================
  // DEBUG
  // =====================================================

  @override
  String toString() {
    return 'Message('
        'id: $id, '
        'sender: $senderName, '
        'type: $type, '
        'deleted: $isDeleted'
        ')';
  }
}