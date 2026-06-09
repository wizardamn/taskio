import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../utils/snackbar_manager.dart';

class ChatInput extends StatefulWidget {
  final String projectId;
  final String? replyId;
  final VoidCallback onMessageSent;

  const ChatInput({
    super.key,
    required this.projectId,
    required this.replyId,
    required this.onMessageSent,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ChatProvider? _chatProvider;

  bool _isSending = false;
  bool _isDisposed = false;
  bool _hasText = false;

  static const int _maxMessageLength = 1000;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _chatProvider ??= context.read<ChatProvider>();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _stopTyping();

    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  // =========================================================
  // HELPERS
  // =========================================================

  void _handleFocusChanged() {
    if (_isDisposed || !mounted) {
      return;
    }

    setState(() {});
  }

  void _setSending(bool value) {
    if (_isDisposed || !mounted || _isSending == value) {
      return;
    }

    setState(() {
      _isSending = value;
    });
  }

  void _setHasText(bool value) {
    if (_isDisposed || !mounted || _hasText == value) {
      return;
    }

    setState(() {
      _hasText = value;
    });
  }

  void _stopTyping() {
    final chatProvider = _chatProvider;

    if (chatProvider == null) {
      return;
    }

    chatProvider.setTyping(
      widget.projectId,
      false,
    );
  }

  bool _isImageFile(String extension) {
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
    }.contains(extension.toLowerCase());
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> _sendMessage() async {
    if (_isSending || _isDisposed) {
      return;
    }

    final text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (text.length > _maxMessageLength) {
      SnackbarManager.showError(
        'chat.message_too_long',
      );
      return;
    }

    final chatProvider = _chatProvider;

    if (chatProvider == null) {
      SnackbarManager.showError(
        'chat.send_error',
      );
      return;
    }

    _setSending(true);

    try {
      await chatProvider.sendMessage(
        widget.projectId,
        text,
        widget.replyId,
      );

      if (_isDisposed || !mounted) {
        return;
      }

      _controller.clear();
      _setHasText(false);
      _stopTyping();

      widget.onMessageSent();

      FocusScope.of(context).unfocus();
    } catch (_) {
      if (!_isDisposed && mounted) {
        SnackbarManager.showError(
          'chat.send_error',
        );
      }
    } finally {
      _setSending(false);
    }
  }

  // =========================================================
  // PICK FILE
  // =========================================================

  Future<void> _pickFile() async {
    if (_isSending || _isDisposed) {
      return;
    }

    final chatProvider = _chatProvider;

    if (chatProvider == null) {
      SnackbarManager.showError(
        'chat.file_send_error',
      );
      return;
    }

    _setSending(true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
        allowMultiple: false,
      );

      if (_isDisposed || !mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;

      if (pickedFile.name.trim().isEmpty) {
        SnackbarManager.showError(
          'chat.file_send_error',
        );
        return;
      }

      if (kIsWeb && pickedFile.bytes == null) {
        SnackbarManager.showError(
          'chat.file_send_error',
        );
        return;
      }

      if (!kIsWeb && pickedFile.path == null) {
        SnackbarManager.showError(
          'chat.file_send_error',
        );
        return;
      }

      final extension =
          pickedFile.extension?.toLowerCase() ?? '';

      final type = _isImageFile(extension)
          ? MessageType.image
          : MessageType.file;

      await chatProvider.sendFile(
        projectId: widget.projectId,
        bytes: pickedFile.bytes,
        file: !kIsWeb && pickedFile.path != null
            ? File(pickedFile.path!)
            : null,
        fileName: pickedFile.name,
        type: type,
      );

      if (_isDisposed || !mounted) {
        return;
      }

      _stopTyping();

      widget.onMessageSent();
    } catch (_) {
      if (!_isDisposed && mounted) {
        SnackbarManager.showError(
          'chat.file_send_error',
        );
      }
    } finally {
      _setSending(false);
    }
  }

  // =========================================================
  // TYPING
  // =========================================================

  void _handleTyping(String value) {
    if (_isSending || _isDisposed) {
      return;
    }

    final hasText = value.trim().isNotEmpty;

    _setHasText(hasText);

    final chatProvider = _chatProvider;

    if (chatProvider == null) {
      return;
    }

    chatProvider.setTyping(
      widget.projectId,
      hasText,
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final canSend = _hasText && !_isSending;

    final panelColor = isDark
        ? colorScheme.surface
        : colorScheme.surface;

    final inputColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : colorScheme.surface;

    final buttonColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
        : colorScheme.surface;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          8,
          6,
          8,
          6,
        ),
        decoration: BoxDecoration(
          color: panelColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildCircleButton(
              tooltip: 'attachments.file'.tr(),
              icon: Icons.add_rounded,
              onPressed: _isSending ? null : _pickFile,
              backgroundColor: buttonColor,
              iconColor: colorScheme.onSurfaceVariant,
              borderColor: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 124,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: inputColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? colorScheme.primary.withValues(alpha: 0.45)
                        : colorScheme.outlineVariant.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  focusNode: _focusNode,
                  controller: _controller,
                  enabled: !_isSending,
                  onChanged: _handleTyping,
                  onSubmitted: (_) {
                    if (!kIsWeb) {
                      _sendMessage();
                    }
                  },
                  textInputAction: kIsWeb
                      ? TextInputAction.newline
                      : TextInputAction.send,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: _maxMessageLength,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.2,
                  ),
                  cursorColor: colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: 'chat.hint'.tr(),
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.68,
                      ),
                      height: 1.2,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            _buildCircleButton(
              tooltip: 'chat.title'.tr(),
              icon: Icons.send_rounded,
              onPressed: canSend ? _sendMessage : null,
              backgroundColor: canSend
                  ? colorScheme.primary
                  : buttonColor,
              iconColor: canSend
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
              borderColor: canSend
                  ? Colors.transparent
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
              isLoading: _isSending,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color iconColor,
    required Color borderColor,
    bool isLoading = false,
  }) {
    final isDisabled = onPressed == null && !isLoading;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: CircleBorder(
          side: BorderSide(
            color: borderColor,
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: isLoading
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
                  : Icon(
                icon,
                size: 22,
                color: isDisabled
                    ? iconColor.withValues(alpha: 0.42)
                    : iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}