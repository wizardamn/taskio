import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../models/message_model.dart';

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

    if (name.isEmpty || name.toLowerCase() == 'unknown') {
      return 'common.user'.tr();
    }

    return name;
  }

  String _textPreview() {
    final text = message.displayContent.trim();

    if (text.isNotEmpty) {
      return text;
    }

    final preview = message.previewText.trim();

    if (preview.isNotEmpty) {
      return preview;
    }

    return '...';
  }

  String _fileName() {
    final name = message.fileName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final preview = message.previewText.trim();

    if (preview.isNotEmpty) {
      return preview;
    }

    return 'chat.file'.tr();
  }

  String? _safeUrl(String? value) {
    final raw = value?.trim();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);

    if (uri == null || !uri.hasScheme || !uri.isAbsolute) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    return raw;
  }

  String? _safeImageUrl() {
    if (!message.isImage) {
      return null;
    }

    final previewUrl = _safeUrl(message.previewUrl);
    final contentUrl = _safeUrl(message.content);

    return previewUrl ?? contentUrl;
  }

  IconData _fileIcon() {
    final fileName = _fileName().toLowerCase();

    if (fileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }

    if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
      return Icons.description_outlined;
    }

    if (fileName.endsWith('.xls') ||
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }

    if (fileName.endsWith('.ppt') || fileName.endsWith('.pptx')) {
      return Icons.slideshow_outlined;
    }

    if (fileName.endsWith('.zip') ||
        fileName.endsWith('.rar') ||
        fileName.endsWith('.7z')) {
      return Icons.folder_zip_outlined;
    }

    if (fileName.endsWith('.txt') ||
        fileName.endsWith('.md') ||
        fileName.endsWith('.json') ||
        fileName.endsWith('.xml')) {
      return Icons.article_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.65),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'chat.reply'.tr()}: ${_senderName()}',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 5),

                  _buildPreviewContent(context),
                ],
              ),
            ),

            const SizedBox(width: 6),

            IconButton(
              tooltip: 'common.cancel'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 34,
              ),
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CONTENT
  // =========================================================

  Widget _buildPreviewContent(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedPreview(context);
    }

    /// ВАЖНО:
    /// Файл проверяем раньше изображения.
    /// Иначе файл со ссылкой может ошибочно отображаться как фото.
    if (message.isFile) {
      return _buildFilePreview(context);
    }

    if (message.isImage) {
      return _buildImagePreview(context);
    }

    return _buildTextPreview(context);
  }

  Widget _buildDeletedPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Text(
      'chat.deleted'.tr(),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final imageUrl = _safeImageUrl();

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl == null
              ? _buildImageFallback(context)
              : CachedNetworkImage(
            imageUrl: imageUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (_, __) {
              return _buildImageFallback(context);
            },
            errorWidget: (_, __, ___) {
              return _buildImageFallback(context);
            },
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            'chat.photo'.tr(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(
          _fileIcon(),
          size: 18,
          color: colorScheme.primary,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            _fileName(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Text(
      _textPreview(),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}