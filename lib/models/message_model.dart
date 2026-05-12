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

  /// comes from message_reads
  final bool isRead;

  final String? originalLanguage;
  final String? translatedContent;

  /// reply
  final String? replyToMessageId;
  final String? replyPreview;
  final String? replySenderName;

  /// ui
  final bool isHighlighted;

  /// edit/delete
  final DateTime? editedAt;
  final bool isDeleted;

  /// file meta
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? previewUrl;

  /// delivery status
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
        return content.length > 40
            ? '${content.substring(0, 40)}...'
            : content;
    }
  }

  String get replyText {
    if (replyPreview == null || replyPreview!.isEmpty) {
      return '';
    }

    return replyPreview!.length > 40
        ? '${replyPreview!.substring(0, 40)}...'
        : replyPreview!;
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

      originalLanguage:
      json['original_language']?.toString(),

      translatedContent:
      json['translated_content']?.toString(),

      editedAt: _parseDateNullable(
        json['edited_at'],
      ),

      isDeleted:
      json['is_deleted'] == true,

      replyToMessageId:
      json['reply_to_message_id']?.toString(),

      replyPreview: _extractReplyPreview(json),

      replySenderName:
      _extractReplySender(json),

      fileName:
      json['file_name']?.toString(),

      fileSize:
      _parseInt(json['file_size']),

      mimeType:
      json['mime_type']?.toString(),

      previewUrl:
      json['preview_url']?.toString(),

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
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview ?? this.replyPreview,
      replySenderName:
      replySenderName ?? this.replySenderName,
      isHighlighted:
      isHighlighted ?? this.isHighlighted,
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

  static String? _extractReplyPreview(
      Map<String, dynamic> json,
      ) {
    final reply = json['reply'];

    if (reply is Map<String, dynamic>) {
      return reply['content']?.toString();
    }

    if (reply is List && reply.isNotEmpty) {
      final first = reply.first;

      if (first is Map<String, dynamic>) {
        return first['content']?.toString();
      }
    }

    return null;
  }

  static String? _extractReplySender(
      Map<String, dynamic> json,
      ) {
    final reply = json['reply'];

    Map<String, dynamic>? replyData;

    if (reply is Map<String, dynamic>) {
      replyData = reply;
    } else if (reply is List && reply.isNotEmpty) {
      final first = reply.first;

      if (first is Map<String, dynamic>) {
        replyData = first;
      }
    }

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
      default:
        return MessageType.text;
    }
  }
}