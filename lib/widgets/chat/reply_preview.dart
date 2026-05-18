import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/message_model.dart';

class ReplyPreview extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onCancel;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.onCancel,
  });

  // =========================================================
  // HELPERS
  // =========================================================

  String _senderName() {
    final name = message.senderName.trim();

    if (name.isEmpty || name == 'Unknown') {
      return 'User';
    }

    return name;
  }

  String _imageUrl() {
    final preview = message.previewUrl?.trim();

    if (preview != null && preview.isNotEmpty) {
      return preview;
    }

    return message.content.trim();
  }

  bool _isNetworkUrl(String value) {
    final lower = value.toLowerCase();

    return lower.startsWith('http://') ||
        lower.startsWith('https://');
  }

  String _fileName() {
    final name = message.fileName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final text = message.previewText.trim();

    if (text.isNotEmpty) {
      return text;
    }

    return 'chat.file'.tr();
  }

  String _textPreview() {
    final text = message.previewText.trim();

    if (text.isEmpty) {
      return '...';
    }

    return text;
  }

  // =========================================================
  // PREVIEW CONTENT
  // =========================================================

  Widget _buildPreviewContent(
      BuildContext context,
      ) {
    if (message.isImage) {
      return _buildImagePreview(context);
    }

    if (message.isFile) {
      return _buildFilePreview(context);
    }

    return _buildTextPreview(context);
  }

  Widget _buildImagePreview(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final url = _imageUrl();

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _isNetworkUrl(url)
              ? Image.network(
            url,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return _imageFallback(theme);
            },
          )
              : _imageFallback(theme),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            'chat.photo'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageFallback(
      ThemeData theme,
      ) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFilePreview(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.attach_file,
          size: 18,
          color: theme.colorScheme.primary,
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            _fileName(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    return Text(
      _textPreview(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _senderName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    _buildPreviewContent(context),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'common.cancel'.tr(),
                splashRadius: 18,
                icon: const Icon(
                  Icons.close,
                  size: 20,
                ),
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}