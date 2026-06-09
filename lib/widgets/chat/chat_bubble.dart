import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/ai_service.dart';
import '../../services/supabase_service.dart';
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

  static const double _maxBubbleWidthFactor = 0.68;
  static const double _maxBubbleWidth = 420;
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
    if (url.trim().isEmpty) {
      return;
    }

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
  // HELPERS
  // =========================================================

  String _senderName() {
    final name = message.senderName.trim();

    if (name.isNotEmpty && name.toLowerCase() != 'unknown') {
      return name;
    }

    return 'common.user'.tr();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return '${parts[0].characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  String? _normalizeAvatarUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();

    const oldAvatarBucketMarker =
        '/storage/v1/object/public/avatars/';

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      if (raw.contains(oldAvatarBucketMarker)) {
        return raw.replaceFirst(
          oldAvatarBucketMarker,
          '/storage/v1/object/public/${SupabaseService.bucket}/',
        );
      }

      return raw;
    }

    try {
      var path = raw.replaceAll('\\', '/');

      while (path.startsWith('/')) {
        path = path.substring(1);
      }

      if (path.startsWith('avatars/')) {
        path = path.substring(
          'avatars/'.length,
        );
      }

      if (path.startsWith('${SupabaseService.bucket}/')) {
        path = path.substring(
          '${SupabaseService.bucket}/'.length,
        );
      }

      return SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeImageName(String value) {
    final lower = value.trim().toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _shouldShowReplyAsImage() {
    if (message.isReplyFile) {
      return false;
    }

    if (!message.isReplyImage) {
      return false;
    }

    final replyText = message.replyText.trim();
    final replyImageUrl = message.replyImageUrl.trim();

    if (replyImageUrl.isEmpty) {
      return false;
    }

    if (replyText.isNotEmpty && !_looksLikeImageName(replyText)) {
      return false;
    }

    return true;
  }

  // =========================================================
  // AVATAR
  // =========================================================

  Widget _buildMessageAvatar(
      BuildContext context, {
        required bool isOnline,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final senderName = _senderName();
    final initials = _initials(senderName);

    final avatarUrl = _normalizeAvatarUrl(
      message.senderAvatarUrl,
    );

    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );

    return Tooltip(
      message: senderName,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.surface,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl == null
                ? fallback
                : Image.network(
              avatarUrl,
              key: ValueKey(avatarUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return fallback;
              },
              loadingBuilder: (
                  context,
                  child,
                  progress,
                  ) {
                if (progress == null) {
                  return child;
                }

                return Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // TRANSLATE
  // =========================================================

  Future<void> _translate(BuildContext context) async {
    if (!message.isText ||
        message.isDeleted ||
        message.content.trim().isEmpty) {
      return;
    }

    try {
      final currentLang = context.locale.languageCode;

      final detectedLang = await aiService.detectLanguage(
        message.content,
      );

      final sourceLang =
      detectedLang == 'unknown' ? 'auto' : detectedLang;

      final targetLang = detectedLang == currentLang
          ? currentLang == 'ru'
          ? 'en'
          : 'ru'
          : currentLang;

      final translated = await aiService.translate(
        text: message.content,
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      if (!context.mounted) {
        return;
      }

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
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
          );
        },
      );
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'chat.translate_error',
        );
      }
    }
  }

  // =========================================================
  // EDIT
  // =========================================================

  Future<void> _editMessage(BuildContext context) async {
    final provider = context.read<ChatProvider>();

    final controller = TextEditingController(
      text: message.content,
    );

    try {
      final newText = await showDialog<String>(
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
              FilledButton(
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
          'errors.unknown',
        );
      }
    } finally {
      controller.dispose();
    }
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteMessage(BuildContext context) async {
    final provider = context.read<ChatProvider>();

    try {
      await provider.deleteMessage(
        message.id,
      );
    } catch (_) {
      if (context.mounted) {
        SnackbarManager.showError(
          'errors.unknown',
        );
      }
    }
  }

  // =========================================================
  // MENU
  // =========================================================

  void _showMessageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              if (message.isText && !message.isDeleted)
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
              if (isMe && message.isText && !message.isDeleted)
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
                    Icons.delete_outline,
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
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        final replyId = message.replyToMessageId;

        if (replyId != null && replyId.trim().isNotEmpty) {
          onScrollTo?.call(replyId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(
          top: 4,
          bottom: 6,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.onPrimaryContainer.withValues(alpha: 0.08)
              : colorScheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              width: 3,
              color: colorScheme.primary,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.replySenderName != null &&
                message.replySenderName!.trim().isNotEmpty) ...[
              Text(
                message.replySenderName!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (_shouldShowReplyAsImage())
              _buildReplyImage(context)
            else if (message.isReplyFile || message.replyImageUrl.isNotEmpty)
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

  Widget _buildReplyImage(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final imageUrl = message.replyImageUrl.trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: imageUrl.isEmpty
              ? _replyImageFallback(context)
              : Image.network(
            imageUrl,
            height: 34,
            width: 34,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return _replyImageFallback(context);
            },
            loadingBuilder: (
                context,
                child,
                progress,
                ) {
              if (progress == null) {
                return child;
              }

              return _replyImageFallback(context);
            },
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'chat.photo'.tr(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMe
                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.82)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _replyImageFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 34,
      width: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 17,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildReplyFile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fileName = message.replyText.trim().isEmpty
        ? 'chat.file'.tr()
        : message.replyText.trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file_rounded,
          size: 16,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            fileName,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMe
                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.82)
                  : colorScheme.onSurfaceVariant,
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
    final colorScheme = theme.colorScheme;

    final text = message.replyText.trim();

    return Text(
      text.isEmpty ? '...' : text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: isMe
            ? textColor.withValues(alpha: 0.82)
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screenWidth = MediaQuery.sizeOf(context).width;

    final bubbleMaxWidth = math.min(
      screenWidth * _maxBubbleWidthFactor,
      _maxBubbleWidth,
    );

    final isOnline = !isMe &&
        context.select<ChatProvider, bool>(
              (provider) => provider.onlineUsers[message.senderId] == true,
        );

    final bubbleColor = message.isDeleted
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : isMe
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    final textColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    final senderName = _senderName();

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 180,
      ),
      color: isHighlighted
          ? colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      child: _SwipeReplyWrapper(
        isMe: isMe,
        onReply: onReply,
        child: Padding(
          padding: EdgeInsets.only(
            left: isMe ? 64 : 6,
            right: isMe ? 10 : 48,
            top: 1,
            bottom: 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 2,
                    right: 4,
                    bottom: 6,
                  ),
                  child: _buildMessageAvatar(
                    context,
                    isOnline: isOnline,
                  ),
                ),

              Flexible(
                fit: FlexFit.loose,
                child: GestureDetector(
                  onDoubleTap: () => _showMessageMenu(context),
                  onLongPress: () => _showMessageMenu(context),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: bubbleMaxWidth,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 3,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(
                            isMe ? 18 : 6,
                          ),
                          bottomRight: Radius.circular(
                            isMe ? 6 : 18,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.025),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isMe) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  senderName,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],

                            if (message.hasReply)
                              _buildReplyPreview(
                                context,
                                textColor,
                              ),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: BubbleContent(
                                message: message,
                                textColor: textColor,
                                onOpenImage: (url) => _openImage(
                                  context,
                                  url,
                                ),
                              ),
                            ),

                            const SizedBox(height: 3),

                            Align(
                              alignment: Alignment.centerRight,
                              child: MessageFooter(
                                time: message.createdAt,
                                isMe: isMe,
                                isRead: isRead,
                                isEdited: message.isEdited,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// SWIPE REPLY
// =========================================================

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

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper> {
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
  Widget build(BuildContext context) {
    final cleanUrl = url.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: cleanUrl.isEmpty
              ? const Icon(
            Icons.broken_image,
            color: Colors.white,
            size: 48,
          )
              : InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              cleanUrl,
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