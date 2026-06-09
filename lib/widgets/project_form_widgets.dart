import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart';

/// ==========================================================
/// DATE PICKER FIELD
/// ==========================================================

class DatePickerField extends StatelessWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime>? onChanged;
  final String label;

  const DatePickerField({
    super.key,
    required this.initialDate,
    required this.onChanged,
    required this.label,
  });

  bool get _isEnabled {
    return onChanged != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final formattedDate = DateFormat.yMMMd(
      context.locale.toLanguageTag(),
    ).format(initialDate);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: !_isEnabled
          ? null
          : () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: context.locale,
        );

        if (picked == null) {
          return;
        }

        onChanged?.call(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            Icons.calendar_month_outlined,
            color: _isEnabled
                ? theme.colorScheme.onSurfaceVariant
                : theme.disabledColor,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabled: _isEnabled,
        ),
        child: Text(
          formattedDate,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: _isEnabled
                ? theme.colorScheme.onSurface
                : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}

/// ==========================================================
/// ATTACHMENT PREVIEW
/// ==========================================================

class AttachmentThumb extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool isOpening;
  final bool canEdit;

  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.onTap,
    this.onDelete,
    this.isOpening = false,
    required this.canEdit,
  });

  bool _isImageAttachment() {
    final fileName = attachment.fileName.trim().toLowerCase();
    final mimeType = attachment.mimeType.trim().toLowerCase();

    final isImageMime = mimeType.startsWith('image/');

    if (isImageMime) {
      return true;
    }

    if (!fileName.contains('.')) {
      return false;
    }

    final extension = fileName.split('.').last;

    return const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
    }.contains(extension);
  }

  String? _publicUrl() {
    final filePath = attachment.filePath.trim();

    if (filePath.isEmpty) {
      return null;
    }

    try {
      return SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(filePath);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double size = 100;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isImage = _isImageAttachment();
    final publicUrl = _publicUrl();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOpening
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOpening
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isOpening ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isOpening ? null : onTap,
              child: isOpening
                  ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isImage && publicUrl != null
                    ? Image.network(
                  publicUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (
                      context,
                      child,
                      progress,
                      ) {
                    if (progress == null) {
                      return child;
                    }

                    final expectedTotalBytes =
                        progress.expectedTotalBytes;

                    final value = expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                        expectedTotalBytes
                        : null;

                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: value,
                        color: colorScheme.primary,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return _buildFileIcon(context);
                  },
                )
                    : _buildFileIcon(context),
              ),
            ),
          ),
        ),

        if (canEdit && onDelete != null && !isOpening)
          Positioned(
            top: -6,
            right: -6,
            child: Tooltip(
              message: 'common.delete'.tr(),
              child: Material(
                color: colorScheme.error,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: colorScheme.onError,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileIcon(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 32,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 6),
            Text(
              attachment.fileName.isEmpty
                  ? 'attachments.file'.tr()
                  : attachment.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}