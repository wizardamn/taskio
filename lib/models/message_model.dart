import 'package:easy_localization/easy_localization.dart';

enum MessageType {
  text,
  image,
  file,
}

enum MessageStatus {
  sending,
  sent,
  failed,
}

extension MessageStatusExtension on MessageStatus {
  static MessageStatus fromString(String? value) {
    switch (value) {
      case 'sending':
        return MessageStatus.sending;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }

  String get value => name;
}

class MessageModel {
  final String id;
  final String projectId;
  final String senderId;
  final String senderName;

  final String content;
  final DateTime createdAt;

  final MessageType type;

  /// Comes from message_reads.
  final bool isRead;

  final String? originalLanguage;
  final String? translatedContent;

  /// Reply data.
  final String? replyToMessageId;
  final String? replyPreview;
  final String? replySenderName;
  final MessageType? replyType;
  final String? replyFileName;
  final String? replyPreviewUrl;
  final String? replyMimeType;

  /// UI.
  final bool isHighlighted;

  /// Edit/delete.
  final DateTime? editedAt;
  final bool isDeleted;

  /// File meta.
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? previewUrl;

  /// Delivery status.
  final MessageStatus status;

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
    this.replyToMessageId,
    this.replyPreview,
    this.replySenderName,
    this.replyType,
    this.replyFileName,
    this.replyPreviewUrl,
    this.replyMimeType,
    this.isHighlighted = false,
    this.editedAt,
    this.isDeleted = false,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.previewUrl,
    this.status = MessageStatus.sent,
  });

  // =====================================================
  // GETTERS
  // =====================================================

  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.file;
  bool get isText => type == MessageType.text;
  bool get isEdited => editedAt != null;

  bool get hasReply => replyToMessageId != null;

  bool get isReplyImage {
    if (replyType == MessageType.image) {
      return true;
    }

    final value = replyPreviewUrl ?? replyPreview ?? '';
    return _looksLikeImageUrl(value);
  }

  bool get isReplyFile => replyType == MessageType.file;

  String get displayContent {
    if (isDeleted) {
      return 'chat.message_deleted'.tr();
    }

    return content;
  }

  String get dateKey =>
      '${createdAt.year}-${createdAt.month}-${createdAt.day}';

  String get previewText {
    if (isDeleted) {
      return 'chat.message_deleted'.tr();
    }

    switch (type) {
      case MessageType.image:
        return 'chat.photo'.tr();

      case MessageType.file:
        return fileName != null && fileName!.isNotEmpty
            ? '📎 $fileName'
            : 'chat.file'.tr();

      case MessageType.text:
        return _shorten(content);
    }
  }

  String get replyText {
    if (replyType == MessageType.image) {
      return 'chat.photo'.tr();
    }

    if (replyType == MessageType.file) {
      if (replyFileName != null && replyFileName!.trim().isNotEmpty) {
        return '📎 $replyFileName';
      }

      return 'chat.file'.tr();
    }

    final text = replyPreview?.trim() ?? '';

    if (text.isEmpty) {
      return '';
    }

    return _shorten(text);
  }

  String get replyRawContent => replyPreview?.trim() ?? '';

  String get replyImageUrl {
    final url = replyPreviewUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return url;
    }

    return replyPreview?.trim() ?? '';
  }

  String get replyDisplay {
    if (replyText.isEmpty) {
      return '';
    }

    final name = replySenderName ?? '';

    if (name.isEmpty) {
      return replyText;
    }

    return '$name: $replyText';
  }

  // =====================================================
  // FROM JSON
  // =====================================================

  factory MessageModel.fromJson(
      Map<String, dynamic> json, {
        bool isRead = false,
      }) {
    final profile = _extractProfile(json);
    final replyData = _extractReplyData(json);

    return MessageModel(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: _extractSenderName(
        json,
        profile,
      ),
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      type: _parseType(json['type']),
      isRead: isRead,
      originalLanguage: json['original_language']?.toString(),
      translatedContent: json['translated_content']?.toString(),
      editedAt: _parseDateNullable(
        json['edited_at'],
      ),
      isDeleted: json['is_deleted'] == true,
      replyToMessageId: json['reply_to_message_id']?.toString(),
      replyPreview: _extractReplyPreview(replyData),
      replySenderName: _extractReplySender(replyData),
      replyType: _extractReplyType(replyData),
      replyFileName: _extractReplyFileName(replyData),
      replyPreviewUrl: _extractReplyPreviewUrl(replyData),
      replyMimeType: _extractReplyMimeType(replyData),
      fileName: json['file_name']?.toString(),
      fileSize: _parseInt(json['file_size']),
      mimeType: json['mime_type']?.toString(),
      previewUrl: json['preview_url']?.toString(),
      status: MessageStatusExtension.fromString(
        json['status']?.toString(),
      ),
    );
  }

  // =====================================================
  // TO JSON
  // =====================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'sender_id': senderId,
      'content': content,
      'type': type.name,
      'original_language': originalLanguage,
      'translated_content': translatedContent,
      'edited_at': editedAt?.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      'reply_to_message_id': replyToMessageId,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'preview_url': previewUrl,
      'status': status.value,
    };
  }

  // =====================================================
  // COPY WITH
  // =====================================================

  MessageModel copyWith({
    String? content,
    bool? isRead,
    DateTime? editedAt,
    bool? isDeleted,
    String? translatedContent,
    MessageStatus? status,
    bool? isHighlighted,
    String? replyPreview,
    String? replySenderName,
    MessageType? replyType,
    String? replyFileName,
    String? replyPreviewUrl,
    String? replyMimeType,
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
      translatedContent: translatedContent ?? this.translatedContent,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview ?? this.replyPreview,
      replySenderName: replySenderName ?? this.replySenderName,
      replyType: replyType ?? this.replyType,
      replyFileName: replyFileName ?? this.replyFileName,
      replyPreviewUrl: replyPreviewUrl ?? this.replyPreviewUrl,
      replyMimeType: replyMimeType ?? this.replyMimeType,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      previewUrl: previewUrl,
      status: status ?? this.status,
    );
  }

  // =====================================================
  // HELPERS
  // =====================================================

  static String _extractSenderName(
      Map<String, dynamic> json,
      Map<String, dynamic>? profile,
      ) {
    return profile?['full_name']?.toString() ??
        profile?['username']?.toString() ??
        json['sender_name']?.toString() ??
        'Unknown';
  }

  static Map<String, dynamic>? _extractReplyData(
      Map<String, dynamic> json,
      ) {
    final reply = json['reply'];

    if (reply is Map<String, dynamic>) {
      return reply;
    }

    if (reply is List && reply.isNotEmpty) {
      final first = reply.first;

      if (first is Map<String, dynamic>) {
        return first;
      }
    }

    return null;
  }

  static String? _extractReplyPreview(
      Map<String, dynamic>? replyData,
      ) {
    if (replyData == null) {
      return null;
    }

    final type = _parseType(replyData['type']);

    if (type == MessageType.image) {
      return replyData['preview_url']?.toString() ??
          replyData['content']?.toString();
    }

    if (type == MessageType.file) {
      return replyData['file_name']?.toString() ??
          replyData['content']?.toString();
    }

    return replyData['content']?.toString();
  }

  static String? _extractReplySender(
      Map<String, dynamic>? replyData,
      ) {
    if (replyData == null) {
      return null;
    }

    final profile = replyData['profiles'];

    if (profile is Map<String, dynamic>) {
      return profile['full_name']?.toString() ??
          profile['username']?.toString();
    }

    if (profile is List && profile.isNotEmpty) {
      final first = profile.first;

      if (first is Map<String, dynamic>) {
        return first['full_name']?.toString() ??
            first['username']?.toString();
      }
    }

    return null;
  }

  static MessageType? _extractReplyType(
      Map<String, dynamic>? replyData,
      ) {
    if (replyData == null) {
      return null;
    }

    return _parseType(replyData['type']);
  }

  static String? _extractReplyFileName(
      Map<String, dynamic>? replyData,
      ) {
    if (replyData == null) {
      return null;
    }

    return replyData['file_name']?.toString();
  }

  static String? _extractReplyPreviewUrl(
      Map<String, dynamic>? replyData,
      ) {
    if (replyData == null) {
      return null;
    }

    return replyData['preview_url']?.toString() ??
        replyData['content']?.toString();
  }

  static String? _extractReplyMimeType(
      Map<String, dynamic>? replyData,
      ) {
    if (replyData == null) {
      return null;
    }

    return replyData['mime_type']?.toString();
  }

  static Map<String, dynamic>? _extractProfile(
      Map<String, dynamic> json,
      ) {
    final raw = json['profiles'];

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;

      if (first is Map<String, dynamic>) {
        return first;
      }
    }

    return null;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal() ??
        DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static MessageType _parseType(dynamic value) {
    switch (value?.toString()) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  static String _shorten(String value) {
    final text = value.trim();

    if (text.length <= 40) {
      return text;
    }

    return '${text.substring(0, 40)}...';
  }

  static bool _looksLikeImageUrl(String value) {
    final lower = value.toLowerCase();

    if (lower.isEmpty) {
      return false;
    }

    return lower.startsWith('http') &&
        (lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.png') ||
            lower.contains('.gif') ||
            lower.contains('.webp') ||
            lower.contains('/storage/') ||
            lower.contains('supabase'));
  }
}