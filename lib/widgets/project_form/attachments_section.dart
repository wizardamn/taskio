import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project_model.dart';

class AttachmentsSection extends StatelessWidget {
  final List<Attachment> attachments;
  final bool isUploading;
  final String? currentlyOpeningFile;
  final bool canEditContent;
  final bool isOwner;
  final VoidCallback onPick;
  final Function(Attachment) onOpen;
  final Function(Attachment) onDelete;

  const AttachmentsSection({
    super.key,
    required this.attachments,
    required this.isUploading,
    required this.currentlyOpeningFile,
    required this.canEditContent,
    required this.isOwner,
    required this.onPick,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: 0.7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              colorScheme,
            ),
            const SizedBox(height: 14),
            _buildContent(
              context,
              colorScheme,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 180.ms)
        .slideX(begin: 0.04, end: 0);
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.attachment_rounded,
            size: 22,
            color: colorScheme.primary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'attachments.title'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _attachmentsCountText(context),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        if (canEditContent)
          FilledButton.tonalIcon(
            icon: isUploading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
                : const Icon(
              Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              'common.add'.tr(),
            ),
            onPressed: isUploading ? null : onPick,
          ),
      ],
    );
  }

  String _attachmentsCountText(BuildContext context) {
    final count = attachments.length;

    if (count == 0) {
      return 'attachments.empty'.tr();
    }

    if (context.locale.languageCode != 'ru') {
      return count == 1 ? '1 file' : '$count files';
    }

    if (count == 1) {
      return '1 файл';
    }

    if (count >= 2 && count <= 4) {
      return '$count файла';
    }

    return '$count файлов';
  }

  // =========================================================
  // CONTENT
  // =========================================================

  Widget _buildContent(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    if (attachments.isEmpty && !isUploading) {
      return _buildEmptyState(
        context,
        colorScheme,
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...attachments.map(
              (attachment) => _AttachmentThumb(
            key: ValueKey(
              '${attachment.id}_${attachment.filePath}_${attachment.fileName}',
            ),
            attachment: attachment,
            canEdit: canEditContent,
            isOpening: currentlyOpeningFile == attachment.filePath,
            onTap: () {
              if (currentlyOpeningFile == attachment.filePath) {
                return;
              }

              onOpen(attachment);
            },
            onDelete: () async {
              final confirmed = await _confirmDelete(
                context,
                attachment,
              );

              if (confirmed == true) {
                onDelete(attachment);
              }
            },
          )
              .animate()
              .scale(
            duration: 180.ms,
            curve: Curves.easeOut,
          )
              .fadeIn(),
        ),
        if (isUploading)
          _buildUploadingThumb(
            colorScheme,
          ),
      ],
    );
  }

  Widget _buildEmptyState(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'attachments.empty'.tr(),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canEditContent) ...[
            const SizedBox(height: 4),
            Text(
              'attachments.file'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildUploadingThumb(ColorScheme colorScheme) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: colorScheme.primary,
          ),
        ),
      ),
    )
        .animate(
      onPlay: (controller) => controller.repeat(),
    )
        .shimmer(
      duration: 1500.ms,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }

  Future<bool?> _confirmDelete(
      BuildContext context,
      Attachment attachment,
      ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'common.delete'.tr(),
          ),
          content: Text(
            context.locale.languageCode == 'ru'
                ? 'Удалить файл «${attachment.fileName}»?'
                : 'Delete file “${attachment.fileName}”?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
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
                  true,
                );
              },
              child: Text(
                'common.delete'.tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =========================================================
// THUMB
// =========================================================

class _AttachmentThumb extends StatelessWidget {
  final Attachment attachment;
  final bool canEdit;
  final bool isOpening;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AttachmentThumb({
    super.key,
    required this.attachment,
    required this.canEdit,
    required this.isOpening,
    required this.onTap,
    required this.onDelete,
  });

  String get _extension {
    final name = attachment.fileName.trim();

    if (!name.contains('.')) {
      return '';
    }

    return name.split('.').last.toLowerCase().trim();
  }

  bool get _isImage {
    return const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    }.contains(_extension);
  }

  bool get _isPdf => _extension == 'pdf';

  bool get _isWord {
    return const {
      'doc',
      'docx',
    }.contains(_extension);
  }

  bool get _isExcel {
    return const {
      'xls',
      'xlsx',
      'csv',
    }.contains(_extension);
  }

  bool get _isArchive {
    return const {
      'zip',
      'rar',
      '7z',
    }.contains(_extension);
  }

  IconData get _fileIcon {
    if (_isImage) {
      return Icons.image_outlined;
    }

    if (_isPdf) {
      return Icons.picture_as_pdf_outlined;
    }

    if (_isWord) {
      return Icons.description_outlined;
    }

    if (_isExcel) {
      return Icons.table_chart_outlined;
    }

    if (_isArchive) {
      return Icons.folder_zip_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Tooltip(
      message: attachment.fileName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOpening ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOpening
                      ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOpening
                        ? colorScheme.primary.withValues(alpha: 0.55)
                        : colorScheme.outlineVariant,
                    width: isOpening ? 1.1 : 0.7,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isOpening)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    else
                      Icon(
                        _fileIcon,
                        size: 28,
                        color: colorScheme.primary,
                      ),

                    const SizedBox(height: 8),

                    Text(
                      attachment.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              if (canEdit && !isOpening)
                Positioned(
                  top: -7,
                  right: -7,
                  child: Tooltip(
                    message: 'common.delete'.tr(),
                    child: Material(
                      color: colorScheme.error,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onDelete,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: colorScheme.onError,
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