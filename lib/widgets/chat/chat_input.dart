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
  final TextEditingController _controller =
  TextEditingController();

  bool _isSending = false;

  static const int _maxMessageLength = 1000;

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (text.length > _maxMessageLength) {
      SnackbarManager.showError(
        'Message too long',
      );
      return;
    }

    final chatProv =
    context.read<ChatProvider>();

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      await chatProv.sendMessage(
        widget.projectId,
        text,
        widget.replyId,
      );

      if (!mounted) {
        return;
      }

      FocusScope.of(context).unfocus();

      _controller.clear();

      widget.onMessageSent();

      chatProv.setTyping(
        widget.projectId,
        false,
      );
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          'chat.send_error'.tr(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // =========================================================
  // PICK FILE
  // =========================================================

  Future<void> _pickFile() async {
    if (_isSending) {
      return;
    }

    final chatProv =
    context.read<ChatProvider>();

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      final result =
      await FilePicker.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );

      if (!mounted) {
        return;
      }

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final file =
          result.files.single;

      if (!kIsWeb &&
          file.path == null) {
        SnackbarManager.showError(
          'chat.file_send_error'.tr(),
        );
        return;
      }

      final ext =
          file.extension?.toLowerCase() ?? '';

      final isImage = [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
      ].contains(ext);

      await chatProv.sendFile(
        projectId: widget.projectId,
        bytes: file.bytes,
        file: !kIsWeb &&
            file.path != null
            ? File(file.path!)
            : null,
        fileName: file.name,
        type: isImage
            ? MessageType.image
            : MessageType.file,
      );

      chatProv.setTyping(
        widget.projectId,
        false,
      );
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          'chat.file_send_error'.tr(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // =========================================================
  // TYPING
  // =========================================================

  void _handleTyping(String value) {
    if (_isSending) {
      return;
    }

    context
        .read<ChatProvider>()
        .setTyping(
      widget.projectId,
      value.trim().isNotEmpty,
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surface,
          border: const Border(
            top: BorderSide(
              color: Colors.grey,
              width: 0.2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(
                Icons.attach_file,
              ),
              onPressed:
              _isSending ? null : _pickFile,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _handleTyping,
                onSubmitted: (_) =>
                    _sendMessage(),
                textInputAction:
                TextInputAction.send,
                minLines: 1,
                maxLines: 5,
                maxLength:
                _maxMessageLength,
                decoration:
                InputDecoration(
                  hintText:
                  'chat.hint'.tr(),
                  border:
                  InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              onPressed:
              _isSending
                  ? null
                  : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}