import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project_model.dart';
import '../../models/message_model.dart';

import '../../providers/chat_provider.dart';

import '../../widgets/chat/chat_list.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/reply_preview.dart';

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
  State<ProjectChatScreen> createState() =>
      _ProjectChatScreenState();
}

class _ProjectChatScreenState
    extends State<ProjectChatScreen> {
  MessageModel? _replyMessage;

  late final ChatProvider _chat;

  @override
  void initState() {
    super.initState();

    _chat = context.read<ChatProvider>();

    _chat.init(widget.projectId);
  }

  // =========================================================
  // REPLY
  // =========================================================

  void _setReply(MessageModel msg) {
    if (!mounted) return;

    setState(() {
      _replyMessage = msg;
    });
  }

  void _clearReply() {
    if (!mounted || _replyMessage == null) return;

    setState(() {
      _replyMessage = null;
    });
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _chat.disposeProject(widget.projectId);
    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final typingUser =
    context.select<ChatProvider, String?>(
          (c) => c.typingUser,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.projectTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (typingUser != null)
              Text(
                '$typingUser ${'chat.typing'.tr()}',
                style: const TextStyle(
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ChatList(
                  projectId: widget.projectId,
                  onReply: _setReply,
                ),
              ),
              if (_replyMessage != null)
                ReplyPreview(
                  message: _replyMessage!,
                  onCancel: _clearReply,
                ),
              ChatInput(
                projectId: widget.projectId,
                replyId: _replyMessage?.id,
                onMessageSent: _clearReply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}