import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../models/message_model.dart';

class BubbleContent extends StatelessWidget {
  final MessageModel message;
  final Color textColor;
  final Function(String url) onOpenImage;

  const BubbleContent({
    super.key,
    required this.message,
    required this.textColor,
    required this.onOpenImage,
  });

  // =========================================================
  // URL HELPERS
  // =========================================================

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
    final previewUrl = _safeUrl(message.previewUrl);
    final contentUrl = _safeUrl(message.content);

    return previewUrl ?? contentUrl;
  }

  String? _safeFileUrl() {
    final contentUrl = _safeUrl(message.content);
    final previewUrl = _safeUrl(message.previewUrl);

    return contentUrl ?? previewUrl;
  }

  Future<void> _openFile(BuildContext context) async {
    final url = _safeFileUrl();

    if (url == null) {
      _showOpenError(context);
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showOpenError(context);
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showOpenError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenError(context);
      }
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'chat.file_open_error'.tr(),
        ),
      ),
    );
  }

  // =========================================================
  // FILE HELPERS
  // =========================================================

  String _fileName() {
    final name = message.fileName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final previewText = message.previewText.trim();

    if (previewText.isNotEmpty) {
      return previewText;
    }

    return 'chat.file'.tr();
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

    if (const {'pdf'}.contains(ext)) {
      return Icons.picture_as_pdf_outlined;
    }

    if (const {'doc', 'docx'}.contains(ext)) {
      return Icons.description_outlined;
    }

    if (const {'xls', 'xlsx', 'csv'}.contains(ext)) {
      return Icons.table_chart_outlined;
    }

    if (const {'ppt', 'pptx'}.contains(ext)) {
      return Icons.slideshow_outlined;
    }

    if (const {'zip', 'rar', '7z'}.contains(ext)) {
      return Icons.folder_zip_outlined;
    }

    if (const {'txt', 'md', 'json', 'xml'}.contains(ext)) {
      return Icons.article_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  double _maxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return screenWidth * 0.68;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeleted(context);
    }

    /// ВАЖНО:
    /// Файл проверяем раньше изображения.
    /// Иначе файл с previewUrl может ошибочно отображаться как фотография.
    if (message.isFile) {
      return _buildFile(context);
    }

    if (message.isImage) {
      return _buildImage(context);
    }

    return _buildText(context);
  }

  // =========================================================
  // DELETED
  // =========================================================

  Widget _buildDeleted(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _maxContentWidth(context),
      ),
      child: Text(
        'chat.deleted'.tr(),
        softWrap: true,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // =========================================================
  // IMAGE
  // =========================================================

  Widget _buildImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = _safeImageUrl();

    if (url == null) {
      return _buildBrokenImage(context);
    }

    final imageSize = MediaQuery.sizeOf(context).width * 0.46;
    final safeImageSize = imageSize.clamp(150.0, 210.0);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        onOpenImage(url);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          height: safeImageSize,
          width: safeImageSize,
          fit: BoxFit.cover,
          placeholder: (_, __) {
            return Container(
              height: safeImageSize,
              width: safeImageSize,
              alignment: Alignment.center,
              color: colorScheme.surfaceContainerHighest,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            );
          },
          errorWidget: (_, __, ___) {
            return _buildBrokenImage(context);
          },
        ),
      ),
    );
  }

  Widget _buildBrokenImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 170,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // =========================================================
  // FILE
  // =========================================================

  Widget _buildFile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fileName = _fileName();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _openFile(context);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 170,
            maxWidth: _maxContentWidth(context),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                width: 0.7,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.75,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _fileIcon(),
                    size: 21,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 10),

                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'chat.file'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TEXT
  // =========================================================

  Widget _buildText(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _maxContentWidth(context),
      ),
      child: Text(
        message.displayContent,
        softWrap: true,
        textWidthBasis: TextWidthBasis.longestLine,
        style: TextStyle(
          color: textColor,
          height: 1.25,
        ),
      ),
    );
  }
}