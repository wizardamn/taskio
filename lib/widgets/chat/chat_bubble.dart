import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_service.dart';
import '../../services/ai_service.dart';
import '../../utils/snackbar_manager.dart';

import 'ChatBubble/bubble_content.dart';
import 'ChatBubble/message_footer.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isRead;
  final bool isHighlighted;
  final VoidCallback onReply;
  final AIService aiService;
  final Function(String)? onScrollTo;

  final ChatService _chatService = ChatService();

  static const double _maxBubbleWidthFactor = 0.75;
  static const double _swipeTrigger = 60;

  ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isRead,
    required this.onReply,
    required this.aiService,
    this.onScrollTo,
    this.isHighlighted = false,
  });

  void _openImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(url: url),
      ),
    );
  }

  bool _isReplyImage(String? preview) {
    if (preview == null || preview.isEmpty) {
      return false;
    }

    return preview.startsWith('http://') ||
        preview.startsWith('https://');
  }

  Future<void> _translate(BuildContext context) async {
    if (!message.isText ||
        message.isDeleted ||
        message.content.trim().isEmpty) {
      return;
    }

    try {
      final lang =
      await aiService.detectLanguage(message.content);

      final translated = await aiService.translate(
        text: message.content,
        targetLanguage: lang == 'ru' ? 'en' : 'ru',
      );

      if (context.mounted) {
        SnackbarManager.showSuccess(translated);
      }
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'chat.translate_error'.tr(),
        );
      }
    }
  }

  Future<void> _editMessage(BuildContext context) async {
    final controller = TextEditingController(
      text: message.content,
    );

    try {
      final newText = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('common.edit'.tr()),
          content: TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text,
                );
              },
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      );

      if (newText == null || newText.trim().isEmpty) {
        return;
      }

      await _chatService.editMessage(
        message.id,
        newText.trim(),
      );
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'errors.unknown'.tr(),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteMessage(
      BuildContext context,
      ) async {
    try {
      await _chatService.deleteMessage(message.id);
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'errors.unknown'.tr(),
        );
      }
    }
  }

  void _showMessageMenu(BuildContext context) {
    if (!isMe) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isText && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text('common.edit'.tr()),
                onTap: () async {
                  Navigator.pop(context);
                  await _editMessage(context);
                },
              ),
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text('common.delete'.tr()),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteMessage(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isOnline = context.select<ChatProvider, bool>(
          (p) => p.onlineUsers[message.senderId] == true,
    );

    final bubbleColor = message.isDeleted
        ? theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.5)
        : isMe
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    final textColor = isMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final senderName = message.senderName.trim().isNotEmpty
        ? message.senderName
        : 'common.user'.tr();

    final senderInitial = senderName.isNotEmpty
        ? senderName[0].toUpperCase()
        : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isHighlighted
          ? theme.colorScheme.primary
          .withValues(alpha: 0.12)
          : Colors.transparent,
      child: _SwipeReplyWrapper(
        isMe: isMe,
        onReply: onReply,
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 4,
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      child: Text(
                        senderInitial,
                        style:
                        const TextStyle(fontSize: 10),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                              theme.colorScheme.surface,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            GestureDetector(
              onDoubleTap: () =>
                  _showMessageMenu(context),
              onLongPress: () => _translate(context),
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                constraints: BoxConstraints(
                  maxWidth:
                  MediaQuery.of(context).size.width *
                      _maxBubbleWidthFactor,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft:
                    Radius.circular(isMe ? 18 : 6),
                    bottomRight:
                    Radius.circular(isMe ? 6 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    if (message.replyToMessageId != null)
                      GestureDetector(
                        onTap: () => onScrollTo?.call(
                          message.replyToMessageId!,
                        ),
                        child: Container(
                          margin:
                          const EdgeInsets.only(
                            top: 4,
                            bottom: 6,
                          ),
                          padding:
                          const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme
                                .colorScheme.primary
                                .withValues(alpha: 0.08),
                            borderRadius:
                            BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                width: 3,
                                color: theme
                                    .colorScheme.primary,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              if (message
                                  .replySenderName !=
                                  null)
                                Text(
                                  message.replySenderName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: theme
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              if (_isReplyImage(
                                  message.replyPreview))
                                ClipRRect(
                                  borderRadius:
                                  BorderRadius
                                      .circular(6),
                                  child: Image.network(
                                    message.replyPreview!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                    const Icon(
                                      Icons.broken_image,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  message.replyText,
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    BubbleContent(
                      message: message,
                      textColor: textColor,
                      onOpenImage: (url) =>
                          _openImage(context, url),
                    ),
                    const SizedBox(height: 4),
                    MessageFooter(
                      time: message.createdAt,
                      isMe: isMe,
                      isRead: isRead,
                      isEdited: message.isEdited,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const _SwipeReplyWrapper({
    required this.child,
    required this.onReply,
    required this.isMe,
  });

  @override
  State<_SwipeReplyWrapper> createState() =>
      _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState
    extends State<_SwipeReplyWrapper> {
  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (widget.isMe && details.delta.dx < 0) {
          return;
        }

        if (!widget.isMe && details.delta.dx > 0) {
          return;
        }

        setState(() {
          _offset += details.delta.dx;
          _offset = _offset.clamp(-80.0, 80.0);
        });
      },
      onHorizontalDragEnd: (_) {
        if (_offset.abs() > ChatBubble._swipeTrigger) {
          widget.onReply();
        }

        setState(() {
          _offset = 0;
        });
      },
      child: Transform.translate(
        offset: Offset(_offset, 0),
        child: widget.child,
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;

  const _ImageViewer({
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) =>
              const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}