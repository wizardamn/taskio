import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/message_model.dart';
import '../../services/supabase_service.dart';

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

  String? _normalizeAvatarUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();

    const oldAvatarBucketMarker = '/storage/v1/object/public/avatars/';

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
        path = path.substring('avatars/'.length);
      }

      if (path.startsWith('${SupabaseService.bucket}/')) {
        path = path.substring('${SupabaseService.bucket}/'.length);
      }

      return SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  String? _safeImageUrl() {
    if (!message.isImage) {
      return null;
    }

    final previewUrl = _safeUrl(message.previewUrl);
    final contentUrl = _safeUrl(message.content);

    return previewUrl ?? contentUrl;
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

  String _textPreview() {
    final content = message.displayContent.trim();

    if (content.isNotEmpty) {
      return content;
    }

    final preview = message.previewText.trim();

    if (preview.isNotEmpty) {
      return preview;
    }

    return '...';
  }

  String _extension() {
    final name = _fileName();

    if (!name.contains('.')) {
      return '';
    }

    return name.split('.').last.toLowerCase().trim();
  }

  IconData _fileIcon() {
    final ext = _extension();

    if (ext == 'pdf') {
      return Icons.picture_as_pdf_outlined;
    }

    if (ext == 'doc' || ext == 'docx') {
      return Icons.description_outlined;
    }

    if (ext == 'xls' || ext == 'xlsx' || ext == 'csv') {
      return Icons.table_chart_outlined;
    }

    if (ext == 'ppt' || ext == 'pptx') {
      return Icons.slideshow_outlined;
    }

    if (ext == 'zip' || ext == 'rar' || ext == '7z') {
      return Icons.folder_zip_outlined;
    }

    if (ext == 'txt' || ext == 'md' || ext == 'json' || ext == 'xml') {
      return Icons.article_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  // =========================================================
  // AVATAR
  // =========================================================

  Widget _buildSenderAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final senderName = _senderName();

    final avatarUrl = _normalizeAvatarUrl(
      message.senderAvatarUrl,
    );

    final fallback = Center(
      child: Text(
        _initials(senderName),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );

    return Tooltip(
      message: senderName,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.surface,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl == null
            ? fallback
            : CachedNetworkImage(
          imageUrl: avatarUrl,
          key: ValueKey(avatarUrl),
          fit: BoxFit.cover,
          placeholder: (_, __) {
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
          errorWidget: (_, __, ___) {
            return fallback;
          },
        ),
      ),
    );
  }

  // =========================================================
  // PREVIEW CONTENT
  // =========================================================

  Widget _buildPreviewContent(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedPreview(context);
    }

    /// ВАЖНО:
    /// Файл проверяем раньше изображения.
    /// Иначе файл с previewUrl может ошибочно отображаться как фото.
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
              ? _imageFallback(context)
              : CachedNetworkImage(
            imageUrl: imageUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (_, __) {
              return _imageFallback(context);
            },
            errorWidget: (_, __, ___) {
              return _imageFallback(context);
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

  Widget _imageFallback(BuildContext context) {
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
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            const SizedBox(width: 10),

            _buildSenderAvatar(context),

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

                  const SizedBox(height: 4),

                  _buildPreviewContent(context),
                ],
              ),
            ),

            const SizedBox(width: 4),

            IconButton(
              tooltip: 'common.cancel'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
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
}