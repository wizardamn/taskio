enum MessageType { text, image, file }

class MessageModel {
  final String id;
  final String projectId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final MessageType type; // <-- НОВОЕ
  final bool isRead;      // <-- НОВОЕ

  MessageModel({
    required this.id,
    required this.projectId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.type = MessageType.text,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Неизвестный';

    // Парсинг типа
    MessageType msgType = MessageType.text;
    final typeString = json['type'] as String? ?? 'text';
    if (typeString == 'image') msgType = MessageType.image;
    if (typeString == 'file') msgType = MessageType.file;

    return MessageModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: name,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      type: msgType,
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}