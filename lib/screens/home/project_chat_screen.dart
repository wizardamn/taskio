import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/message_model.dart';
import '../../models/project_model.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';

class ProjectChatScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final List<ProjectParticipant> participants;

  const ProjectChatScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.participants,
  });

  @override
  State<ProjectChatScreen> createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Stream<List<MessageModel>> _messagesStream;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getMessagesStream(widget.projectId);
    // Помечаем сообщения как прочитанные при входе
    _chatService.markAsRead(widget.projectId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    try {
      await _chatService.sendMessage(widget.projectId, text);
    } catch (e) {
      if (mounted) _showError('Ошибка отправки: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'mp3'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploading = true);

        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase() ?? '';
        final isImage = ['jpg', 'jpeg', 'png'].contains(extension);

        await _chatService.sendFileMessage(
            widget.projectId,
            file,
            isImage ? MessageType.image : MessageType.file
        );
      }
    } catch (e) {
      if (mounted) _showError('Не удалось отправить файл: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _findName(String userId) {
    final currentUser = SupabaseService.client.auth.currentUser;
    if (userId == currentUser?.id) return 'Вы';

    final participant = widget.participants.firstWhere(
          (p) => p.id == userId,
      orElse: () => ProjectParticipant(id: '', fullName: 'Неизвестный'),
    );
    return participant.fullName;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool _shouldShowDateHeader(MessageModel current, MessageModel? older) {
    if (older == null) return true;
    final cDate = current.createdAt;
    final oDate = older.createdAt;
    return cDate.year != oDate.year || cDate.month != oDate.month || cDate.day != oDate.day;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Чат команды', style: TextStyle(fontSize: 16)),
            Text(widget.projectTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text('Сообщений пока нет.\nНачните общение!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final olderMsg = (index + 1 < messages.length) ? messages[index + 1] : null;
                    final isMe = msg.senderId == currentUserId;
                    final senderName = _findName(msg.senderId);
                    final initials = _getInitials(senderName);
                    final showDate = _shouldShowDateHeader(msg, olderMsg);

                    return Column(
                      children: [
                        if (showDate) _DateHeader(date: msg.createdAt),
                        _ChatBubble(
                          message: msg,
                          isMe: isMe,
                          senderName: senderName,
                          initials: initials,
                        ).animate().fade().slideY(begin: 0.1, end: 0),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          if (_isUploading)
            const LinearProgressIndicator(minHeight: 2),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploading ? null : _pickAndSendFile,
                    icon: const Icon(Icons.attach_file),
                    color: Colors.grey.shade600,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Написать сообщение...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    mini: true,
                    elevation: 0,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    String text;
    if (dateToCheck == today) {
      text = 'Сегодня';
    } else if (dateToCheck == yesterday) {
      text = 'Вчера';
    } else {
      text = DateFormat('d MMMM', 'ru').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String senderName;
  final String initials;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.initials,
  });

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                initials,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                      child: Text(
                        senderName,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Theme.of(context).primaryColor : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        )
                      ],
                      border: !isMe ? Border.all(color: Colors.grey.shade200) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Контент сообщения
                        _buildContent(context),

                        const SizedBox(height: 4),

                        // Время и галочки
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isRead ? Icons.done_all : Icons.check,
                                size: 14,
                                color: message.isRead
                                    ? Colors.blue.shade100 // Голубые галочки (если фон синий)
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.type == MessageType.image) {
      return GestureDetector(
        onTap: () => _openFile(message.content),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.content,
            fit: BoxFit.cover,
            height: 150,
            width: 200,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 150,
                width: 200,
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      );
    } else if (message.type == MessageType.file) {
      // Извлекаем имя файла из URL (декодируем URL encoded символы)
      final fileName = Uri.decodeFull(message.content.split('/').last.split('?').first);
      return GestureDetector(
        onTap: () => _openFile(message.content),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Text(
        message.content,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }
  }
}