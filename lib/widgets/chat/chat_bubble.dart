import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
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

  static const double _maxBubbleWidthFactor = 0.75;
  static const double _swipeTrigger = 60;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isRead,
    required this.onReply,
    required this.aiService,
    this.onScrollTo,
    this.isHighlighted = false,
  });

  // =========================================================
  // IMAGE VIEWER
  // =========================================================

  void _openImage(
      BuildContext context,
      String url,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(
          url: url,
        ),
      ),
    );
  }

  // =========================================================
  // TRANSLATE
  // =========================================================

  Future<void> _translate(
      BuildContext context,
      ) async {
    if (!message.isText ||
        message.isDeleted ||
        message.content.trim().isEmpty) {
      return;
    }

    try {
      final currentLang =
          context.locale.languageCode;

      final detectedLang =
      await aiService.detectLanguage(
        message.content,
      );

      final sourceLang =
      detectedLang == 'unknown'
          ? 'auto'
          : detectedLang;

      final targetLang =
      detectedLang == currentLang
          ? currentLang == 'ru'
          ? 'en'
          : 'ru'
          : currentLang;

      final translated =
      await aiService.translate(
        text: message.content,
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      if (!context.mounted) {
        return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            'chat.translate'.tr(),
          ),
          content: SelectableText(
            translated,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'common.ok'.tr(),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'chat.translate_error'.tr(),
        );
      }
    }
  }

  // =========================================================
  // EDIT
  // =========================================================

  Future<void> _editMessage(
      BuildContext context,
      ) async {
    final provider =
    context.read<ChatProvider>();

    final controller =
    TextEditingController(
      text: message.content,
    );

    try {
      final newText =
      await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              'common.edit'.tr(),
            ),
            content: TextField(
              controller: controller,
              maxLines: null,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: Text(
                  'common.cancel'.tr(),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    controller.text.trim(),
                  );
                },
                child: Text(
                  'common.save'.tr(),
                ),
              ),
            ],
          );
        },
      );

      if (newText == null ||
          newText.isEmpty ||
          newText == message.content) {
        return;
      }

      await provider.editMessage(
        message.id,
        newText,
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

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteMessage(
      BuildContext context,
      ) async {
    final provider =
    context.read<ChatProvider>();

    try {
      await provider.deleteMessage(
        message.id,
      );
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'errors.unknown'.tr(),
        );
      }
    }
  }

  // =========================================================
  // MENU
  // =========================================================

  void _showMessageMenu(
      BuildContext context,
      ) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              if (!message.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.reply,
                  ),
                  title: Text(
                    'chat.reply'.tr(),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onReply();
                  },
                ),

              if (message.isText &&
                  !message.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.translate,
                  ),
                  title: Text(
                    'chat.translate'.tr(),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _translate(context);
                  },
                ),

              if (isMe &&
                  message.isText &&
                  !message.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                  ),
                  title: Text(
                    'common.edit'.tr(),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _editMessage(context);
                  },
                ),

              if (isMe && !message.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                  ),
                  title: Text(
                    'common.delete'.tr(),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteMessage(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // REPLY PREVIEW INSIDE BUBBLE
  // =========================================================

  Widget _buildReplyPreview(
      BuildContext context,
      Color textColor,
      ) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        final replyId =
            message.replyToMessageId;

        if (replyId != null) {
          onScrollTo?.call(replyId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(
          top: 4,
          bottom: 6,
        ),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary
              .withValues(alpha: 0.08),
          borderRadius:
          BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              width: 3,
              color:
              theme.colorScheme.primary,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            if (message.replySenderName != null &&
                message.replySenderName!
                    .trim()
                    .isNotEmpty)
              Text(
                message.replySenderName!,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                  theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),

            if (message.replySenderName != null &&
                message.replySenderName!
                    .trim()
                    .isNotEmpty)
              const SizedBox(height: 4),

            if (message.isReplyImage)
              _buildReplyImage(context)
            else if (message.isReplyFile)
              _buildReplyFile(context)
            else
              _buildReplyText(
                context,
                textColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyImage(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final imageUrl =
    message.replyImageUrl.trim();

    if (imageUrl.isEmpty) {
      return Text(
        'chat.photo'.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:
          theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius:
          BorderRadius.circular(6),
          child: Image.network(
            imageUrl,
            height: 52,
            width: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                height: 52,
                width: 52,
                alignment: Alignment.center,
                color: theme.colorScheme
                    .surfaceContainerHighest,
                child: const Icon(
                  Icons.image_not_supported,
                  size: 20,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'chat.photo'.tr(),
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyFile(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          size: 18,
          color:
          theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            message.replyText.isEmpty
                ? 'chat.file'.tr()
                : message.replyText,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyText(
      BuildContext context,
      Color textColor,
      ) {
    final theme = Theme.of(context);

    final text = message.replyText.trim();

    return Text(
      text.isEmpty ? '...' : text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isMe
            ? textColor.withValues(alpha: 0.82)
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    final isOnline =
    context.select<ChatProvider, bool>(
          (p) =>
      p.onlineUsers[message.senderId] ==
          true,
    );

    final bubbleColor = message.isDeleted
        ? theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.5)
        : isMe
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme
        .surfaceContainerHighest;

    final textColor = isMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final senderName =
    message.senderName.trim().isNotEmpty
        ? message.senderName
        : 'common.user'.tr();

    final senderInitial =
    senderName.isNotEmpty
        ? senderName[0].toUpperCase()
        : '?';

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 200,
      ),
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
          crossAxisAlignment:
          CrossAxisAlignment.end,
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
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration:
                          BoxDecoration(
                            color: Colors.green,
                            shape:
                            BoxShape.circle,
                            border: Border.all(
                              color: theme
                                  .colorScheme
                                  .surface,
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
              onLongPress: () =>
                  _showMessageMenu(context),
              child: Container(
                margin: const EdgeInsets
                    .symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                padding: const EdgeInsets
                    .symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                constraints: BoxConstraints(
                  maxWidth:
                  MediaQuery.of(context)
                      .size
                      .width *
                      _maxBubbleWidthFactor,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius:
                  BorderRadius.only(
                    topLeft:
                    const Radius.circular(18),
                    topRight:
                    const Radius.circular(18),
                    bottomLeft: Radius.circular(
                      isMe ? 18 : 6,
                    ),
                    bottomRight:
                    Radius.circular(
                      isMe ? 6 : 18,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        senderName,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                          FontWeight.bold,
                          color: textColor,
                        ),
                      ),

                    if (message.hasReply)
                      _buildReplyPreview(
                        context,
                        textColor,
                      ),

                    BubbleContent(
                      message: message,
                      textColor: textColor,
                      onOpenImage: (url) =>
                          _openImage(
                            context,
                            url,
                          ),
                    ),

                    const SizedBox(height: 4),

                    MessageFooter(
                      time: message.createdAt,
                      isMe: isMe,
                      isRead: isRead,
                      isEdited:
                      message.isEdited,
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

// =========================================================
// SWIPE REPLY
// =========================================================

class _SwipeReplyWrapper
    extends StatefulWidget {
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
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (widget.isMe &&
            details.delta.dx < 0) {
          return;
        }

        if (!widget.isMe &&
            details.delta.dx > 0) {
          return;
        }

        setState(() {
          _offset += details.delta.dx;
          _offset =
              _offset.clamp(-80.0, 80.0);
        });
      },
      onHorizontalDragEnd: (_) {
        if (_offset.abs() >
            ChatBubble._swipeTrigger) {
          widget.onReply();
        }

        setState(() {
          _offset = 0;
        });
      },
      child: Transform.translate(
        offset: Offset(
          _offset,
          0,
        ),
        child: widget.child,
      ),
    );
  }
}

// =========================================================
// IMAGE VIEWER
// =========================================================

class _ImageViewer extends StatelessWidget {
  final String url;

  const _ImageViewer({
    required this.url,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
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
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 48,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}