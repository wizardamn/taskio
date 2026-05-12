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

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd(
      context.locale.toLanguageTag(),
    ).format(initialDate);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onChanged == null
          ? null
          : () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: context.locale,
        );

        if (picked != null && onChanged != null) {
          onChanged!(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(
            Icons.calendar_month,
          ),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          formattedDate,
          style: Theme.of(context)
              .textTheme
              .bodyLarge,
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

  bool _isImage(String name) {
    if (!name.contains('.')) {
      return false;
    }

    final ext = name.split('.').last.toLowerCase();

    return const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
    }.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    const double size = 100;

    final colorScheme =
        Theme.of(context).colorScheme;

    final isImage =
    _isImage(attachment.fileName);

    final publicUrl = SupabaseService
        .client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(
      attachment.filePath,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(
            milliseconds: 200,
          ),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOpening
                ? colorScheme.primaryContainer
                : colorScheme
                .surfaceContainerHighest,
            borderRadius:
            BorderRadius.circular(16),
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
              borderRadius:
              BorderRadius.circular(16),
              onTap: isOpening ? null : onTap,
              child: isOpening
                  ? Center(
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  colorScheme.primary,
                ),
              )
                  : ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
                child: isImage
                    ? Image.network(
                  publicUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (
                      context,
                      child,
                      progress,
                      ) {
                    if (progress ==
                        null) {
                      return child;
                    }

                    return Center(
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress
                            .expectedTotalBytes !=
                            null
                            ? progress
                            .cumulativeBytesLoaded /
                            progress
                                .expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (
                      _,
                      __,
                      ___,
                      ) =>
                      _buildFileIcon(
                        context,
                      ),
                )
                    : _buildFileIcon(
                  context,
                ),
              ),
            ),
          ),
        ),

        /// DELETE BUTTON
        if (canEdit &&
            onDelete != null &&
            !isOpening)
          Positioned(
            top: -6,
            right: -6,
            child: Tooltip(
              message:
              'common.delete'.tr(),
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding:
                  const EdgeInsets.all(5),
                  decoration:
                  BoxDecoration(
                    color:
                    colorScheme.error,
                    shape:
                    BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color:
                    colorScheme.onError,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileIcon(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file,
              size: 32,
              color:
              colorScheme.outline,
            ),
            const SizedBox(height: 6),
            Text(
              attachment.fileName,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}