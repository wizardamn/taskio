import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../utils/project_ui_utils.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final Function(ProjectModel) onEdit;
  final Function(ProjectModel) onDelete;
  final bool canEdit;
  final bool isOwner;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = project.progress;
    final allParticipants = project.participantsData.map((p) => p.fullName).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: canEdit ? () => onEdit(project) : null,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: project.colorObj,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      onSelected: (val) => val == 'edit' ? onEdit(project) : onDelete(project),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Открыть')),
                        if (isOwner)
                          const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
                      ],
                      child: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurface),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (project.totalTasks > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? Colors.green : project.colorObj),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text('Срок: ${DateFormat('dd.MM.yyyy').format(project.deadline)}', style: const TextStyle(fontSize: 13)),
              Text('Статус: ${project.statusEnum.text}', style: const TextStyle(fontSize: 13)),
              if (allParticipants.isNotEmpty)
                Text('Участники: $allParticipants',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              if (project.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: project.attachments.map((att) {
                      final url = Supabase.instance.client.storage.from(SupabaseService.bucket).getPublicUrl(att.filePath);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: att.mimeType.contains('image')
                                ? Image.network(url, fit: BoxFit.cover)
                                : Icon(ProjectUIUtils.getFileIcon(att.mimeType),
                                color: ProjectUIUtils.getFileColor(att.mimeType), size: 20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}