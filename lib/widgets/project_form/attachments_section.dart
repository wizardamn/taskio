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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, colorScheme),
        const SizedBox(height: 12),
        _buildContent(context, colorScheme),
      ],
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.attachment_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'attachments.title'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    attachments.length.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (canEditContent)
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: Text('common.add'.tr()),
            onPressed: isUploading ? null : onPick,
          ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  // =========================================================
  // CONTENT
  // =========================================================

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    if (attachments.isEmpty && !isUploading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: colorScheme.outline.withValues(alpha: 0.6),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'attachments.empty'.tr(),
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...attachments.map(
              (att) => _AttachmentThumb(
            key: ValueKey('${att.filePath}_${att.fileName}'),
            attachment: att,
            canEdit: canEditContent && isOwner,
            isOpening: currentlyOpeningFile == att.filePath,
            onTap: () => onOpen(att),
            onDelete: () => onDelete(att),
          )
              .animate()
              .scale(duration: 200.ms, curve: Curves.easeOut)
              .fadeIn(),
        ),
        if (isUploading) _buildUploadingThumb(colorScheme),
      ],
    );
  }

  Widget _buildUploadingThumb(ColorScheme colorScheme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary
              .withValues(alpha: 0.3),
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
      duration: 1500.ms,
      color: Colors.white.withValues(alpha: 0.3),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isOpening ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isOpening)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.insert_drive_file_outlined),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit && !isOpening)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: colorScheme.onError,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}