import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project_model.dart'; // Путь к вашей модели Attachment
import '../services/supabase_service.dart';

// --- Компонент выбора даты ---
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
    return InkWell(
      onTap: onChanged != null
          ? () async {
        final initialDateTime =
        DateTime(initialDate.year, initialDate.month, initialDate.day);
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDateTime,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged!(picked);
        }
      }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_month),
        ),
        child: Text(
          DateFormat('dd.MM.yyyy').format(initialDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// --- Компонент превью вложения ---
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

  bool _isImage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImage(attachment.fileName);
    const size = 100.0;

    final String fullPublicUrl = SupabaseService.client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(attachment.filePath);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: isOpening ? null : onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isOpening ? Colors.blue.shade50 : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.grey.shade300, width: isOpening ? 2.5 : 1),
            ),
            child: isOpening
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(height: 8),
                  Text('Загрузка...',
                      style: TextStyle(
                          fontSize: 10, color: Colors.blue.shade800))
                ],
              ),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage
                  ? Image.network(
                fullPublicUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFileIcon(),
              )
                  : _buildFileIcon(),
            ),
          ),
        ),
        if (onDelete != null && !isOpening && canEdit)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.blueGrey, size: 32),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
// Мы удалили расширение extension ListExtensions отсюда, чтобы избежать конфликта.