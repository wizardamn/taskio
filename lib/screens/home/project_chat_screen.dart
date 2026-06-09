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

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  MessageModel? _replyMessage;

  late final ChatProvider _chat;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _chat = context.read<ChatProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) {
        return;
      }

      _chat.init(widget.projectId);
    });
  }

  // =========================================================
  // REPLY
  // =========================================================

  void _setReply(MessageModel message) {
    if (_disposed || !mounted) {
      return;
    }

    setState(() {
      _replyMessage = message;
    });
  }

  void _clearReply() {
    if (_disposed || !mounted || _replyMessage == null) {
      return;
    }

    setState(() {
      _replyMessage = null;
    });
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _disposed = true;

    _chat.disposeProject(widget.projectId);

    super.dispose();
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _cleanProjectTitle() {
    final title = widget.projectTitle.trim();

    if (title.isEmpty) {
      return 'projects.project'.tr();
    }

    return title;
  }

  String _participantsText() {
    final count = widget.participants.length;

    if (count <= 0) {
      return 'members.no_participants'.tr();
    }

    final isRu = context.locale.languageCode == 'ru';

    if (!isRu) {
      return count == 1 ? '1 member' : '$count members';
    }

    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) {
      return '$count участник';
    }

    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 12 || mod100 > 14)) {
      return '$count участника';
    }

    return '$count участников';
  }

  String _typingText(String typingUser) {
    final cleanName = typingUser.trim();

    if (cleanName.isEmpty) {
      return '';
    }

    return '$cleanName ${'chat.typing'.tr()}';
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final typingUser = context.select<ChatProvider, String?>(
          (provider) => provider.typingUser,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 0,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(
            right: 12,
          ),
          child: _buildTitle(
            typingUser,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          top: false,
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

  Widget _buildTitle(String? typingUser) {
    final hasTyping =
        typingUser != null && typingUser.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _cleanProjectTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 160,
          ),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Text(
            hasTyping
                ? _typingText(typingUser)
                : _participantsText(),
            key: ValueKey(
              hasTyping ? 'typing_$typingUser' : 'participants',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}