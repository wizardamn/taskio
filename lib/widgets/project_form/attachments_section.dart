import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/project_model.dart';
import '../project_form_widgets.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Важно для корректного отображения внутри списков
      children: [
        // Заголовок секции
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attachment_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Вложения",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${attachments.length}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (canEditContent)
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text("Добавить"),
                onPressed: isUploading ? null : onPick,
              ),
          ],
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 12),

        // Контентная область с использованием AnimatedSwitcher для надежного переключения состояний
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    // Если файлов нет и загрузка не идет - показываем "Пусто"
    if (attachments.isEmpty && !isUploading) {
      return Container(
        key: const ValueKey('empty_state'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Colors.grey.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              "Нет прикрепленных файлов",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Если есть файлы или идет загрузка - отрисовываем сетку
    return SizedBox(
      key: const ValueKey('grid_state'),
      width: double.infinity,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.start,
        children: [
          // Список уже загруженных файлов
          ...attachments.map((att) => AttachmentThumb(
            key: ValueKey('att_${att.filePath}'), // Уникальный ключ для каждого элемента
            attachment: att,
            canEdit: canEditContent && isOwner,
            isOpening: currentlyOpeningFile == att.filePath,
            onTap: () => onOpen(att),
            onDelete: () => onDelete(att),
          ).animate().scale(duration: 200.ms, curve: Curves.easeOut).fadeIn()),

          // Индикатор загрузки нового файла (внутри сетки)
          if (isUploading)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
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
                .shimmer(duration: 1500.ms, color: Colors.white30),
        ],
      ),
    );
  }
}