import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/message_model.dart';
import '../../models/project_model.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/snackbar_manager.dart';

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
  MessageModel? _replyMessage;

  @override
  void initState() {
    super.initState();

    _messagesStream =
        _chatService.subscribeMessages(widget.projectId);

    _chatService.markProjectMessagesAsRead(widget.projectId);

    _chatService.startPresenceHeartbeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // SEND MESSAGE

  Future<void> _sendMessage() async {

    final text = _controller.text.trim();

    if (text.isEmpty) return;

    _controller.clear();

    try {

      await _chatService.sendMessage(
        widget.projectId,
        text,
        replyTo: _replyMessage?.id,
      );

      setState(() => _replyMessage = null);

      _scrollToBottom();

    } catch (_) {
      SnackbarManager.showError('chat.send_error'.tr());
    }
  }

  // FILE UPLOAD

  Future<void> _pickAndSendFile() async {

    try {

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );

      if (result == null) return;

      final file = result.files.single;

      if (kIsWeb && file.bytes == null) return;
      if (!kIsWeb && file.path == null) return;

      setState(() => _isUploading = true);

      final ext = file.extension?.toLowerCase() ?? '';

      final isImage =
      ['jpg','jpeg','png','webp'].contains(ext);

      final type =
      isImage ? MessageType.image : MessageType.file;

      if (kIsWeb) {

        await _chatService.sendFileMessage(
          projectId: widget.projectId,
          fileBytes: file.bytes!,
          fileName: file.name,
          type: type,
        );

      } else {

        await _chatService.sendFileMessage(
          projectId: widget.projectId,
          file: File(file.path!),
          fileName: file.name,
          type: type,
        );
      }

      _scrollToBottom();

    } catch (_) {

      SnackbarManager.showError(
          'chat.file_send_error'.tr());

    } finally {

      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _scrollToBottom() {

    Future.delayed(
      const Duration(milliseconds: 100),
          () {

        if (!_scrollController.hasClients) return;

        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // USER NAME

  String _findName(String userId) {

    final currentUser =
        SupabaseService.client.auth.currentUser;

    if (userId == currentUser?.id) {
      return 'chat.you'.tr();
    }

    final participant =
    widget.participants.firstWhere(
          (p) => p.id == userId,
      orElse: () => ProjectParticipant(
        id: '',
        fullName: 'Unknown',
      ),
    );

    return participant.fullName;
  }

  @override
  Widget build(BuildContext context) {

    final currentUserId =
        SupabaseService.client.auth.currentUser?.id;

    return Scaffold(

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(widget.projectTitle),

            StreamBuilder<List<String>>(

              stream: _chatService.getOnlineUsers(),

              builder: (context, snapshot) {

                final online = snapshot.data ?? [];

                final onlineCount = widget.participants
                    .where((p) => online.contains(p.id))
                    .length;

                return Text(
                  "$onlineCount online",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                );
              },
            )
          ],
        ),
      ),

      body: Column(
        children: [

          Expanded(
            child: StreamBuilder<List<MessageModel>>(

              stream: _messagesStream,

              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                return ListView.builder(

                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,

                  itemBuilder: (context, index) {

                    final msg = messages[index];

                    final isMe =
                        msg.senderId == currentUserId;

                    final sender =
                    _findName(msg.senderId);

                    return Dismissible(

                      key: Key(msg.id),

                      direction: isMe
                          ? DismissDirection.endToStart
                          : DismissDirection.startToEnd,

                      background: Container(
                        color: Colors.green,
                        padding: const EdgeInsets.only(left: 20),
                        alignment: Alignment.centerLeft,
                        child: const Icon(Icons.reply,color: Colors.white),
                      ),

                      secondaryBackground: Container(
                        color: Colors.red,
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete,color: Colors.white),
                      ),

                      confirmDismiss: (direction) async {

                        if(direction == DismissDirection.startToEnd){

                          setState(() {
                            _replyMessage = msg;
                          });

                          return false;
                        }

                        if(direction == DismissDirection.endToStart){

                          await _chatService.deleteMessage(msg.id);

                          return true;
                        }

                        return false;
                      },

                      child: _ChatBubble(
                        message: msg,
                        isMe: isMe,
                        senderName: sender,
                      )
                          .animate()
                          .fade()
                          .slideY(begin: 0.1,end: 0),
                    );
                  },
                );
              },
            ),
          ),

          if (_replyMessage != null)
            _ReplyPreview(
              message: _replyMessage!,
              onCancel: () {
                setState(() {
                  _replyMessage = null;
                });
              },
            ),

          StreamBuilder<List<String>>(

            stream: _chatService.getTypingUsers(widget.projectId),

            builder: (context, snapshot) {

              final typing = snapshot.data ?? [];

              if (typing.isEmpty) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  "Someone is typing...",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              );
            },
          ),

          if (_isUploading)
            const LinearProgressIndicator(),

          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {

    return Padding(
      padding: const EdgeInsets.all(8),

      child: Row(

        children: [

          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed:
            _isUploading ? null : _pickAndSendFile,
          ),

          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (_) {
                _chatService.setTyping(widget.projectId, true);
              },
              decoration: InputDecoration(
                hintText: 'chat.hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {

  final MessageModel message;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.message,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(8),

      color: Colors.grey.shade200,

      child: Row(

        children: [

          const Icon(Icons.reply),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          )
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {

  final MessageModel message;
  final bool isMe;
  final String senderName;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
  });

  Future<void> _openFile(String url) async {

    final uri = Uri.parse(url);

    if(await canLaunchUrl(uri)){
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {

    final color =
    isMe ? Colors.blue : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),

      child: Row(

        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,

        children: [

          Flexible(
            child: Container(

              padding: const EdgeInsets.all(10),

              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,

                children: [

                  if (!isMe)
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 4),

                  if(message.isDeleted)

                    const Text(
                      "Message deleted",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    )

                  else if(message.type == MessageType.image)

                    GestureDetector(
                      onTap: ()=>_openFile(message.content),
                      child: Image.network(
                        message.content,
                        height:150,
                        fit: BoxFit.cover,
                      ),
                    )

                  else if(message.type == MessageType.file)

                      GestureDetector(
                        onTap: ()=>_openFile(message.content),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.insert_drive_file),
                            SizedBox(width:6),
                            Text("Open file")
                          ],
                        ),
                      )

                    else

                      Text(message.content),

                  if (message.isEdited)
                    const Text(
                      "(edited)",
                      style: TextStyle(fontSize: 10),
                    ),

                  if(isMe)
                    Icon(
                      message.isRead
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: message.isRead
                          ? Colors.lightBlue
                          : Colors.grey,
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