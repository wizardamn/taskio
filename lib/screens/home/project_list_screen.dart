import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortBy;

// --- ИМПОРТЫ ---
import '../../providers/auth_provider.dart';
import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../services/supabase_service.dart';
import 'project_form_screen.dart';
import '../../widgets/user_profile_drawer.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  double _fabScale = 1.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final prov = context.read<ProjectProvider>();
      final authProv = context.read<AuthProvider>();

      if (authProv.isGuest) {
        prov.setGuestUser();
      } else {
        await prov.fetchProjects();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final authProv = context.watch<AuthProvider>();

    final projects = prov.view;
    final isActuallyGuest = authProv.isGuest || prov.isGuest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои проекты'),
        actions: [
          if (!isActuallyGuest)
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Нет новых уведомлений')),
                );
              },
            ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_alt),
            onSelected: (value) => _onSortFilter(value, prov),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dAsc', child: Text('Cначала новые')),
              const PopupMenuItem(value: 'dDesc', child: Text('Сначала старые')),
              const PopupMenuItem(value: 'status', child: Text('По статусу')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'all', child: Text('Все проекты')),
              const PopupMenuItem(value: 'inProgress', child: Text('В работе')),
            ],
          ),
        ],
      ),

      drawer: const UserProfileDrawer(),

      body: prov.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: prov.fetchProjects,
        child: projects.isEmpty
            ? Center(
          child: Text(
            isActuallyGuest
                ? "Войдите в аккаунт, чтобы увидеть проекты"
                : "Нет проектов",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        )
            : _buildProjectList(projects, prov, authProv),
      ),

      floatingActionButton: isActuallyGuest
          ? null
          : AnimatedScale(
        scale: _fabScale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
        child: FloatingActionButton(
          onPressed: _addProject,
          tooltip: 'Создать проект',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _addProject() async {
    final prov = context.read<ProjectProvider>();
    final authProv = context.read<AuthProvider>();

    if (authProv.isGuest || prov.isGuest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Гости не могут создавать проекты.')),
      );
      return;
    }

    setState(() => _fabScale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _fabScale = 1.0);

    ProjectModel newProject;
    try {
      newProject = prov.createEmptyProject();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(project: newProject, isNew: true),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      await prov.fetchProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект успешно создан')),
      );
    }
  }

  void _onSortFilter(String value, ProjectProvider prov) {
    switch (value) {
      case 'dAsc':
        prov.setSort(SortBy.deadlineAsc);
        break;
      case 'dDesc':
        prov.setSort(SortBy.deadlineDesc);
        break;
      case 'status':
        prov.setSort(SortBy.status);
        break;
      case 'all':
        prov.setFilter(ProjectFilter.all);
        break;
      case 'inProgress':
        prov.setFilter(ProjectFilter.inProgressOnly);
        break;
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ProjectProvider prov, ProjectModel project) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    if (authProv.isGuest || prov.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Гости не могут удалять проекты.')),
      );
      return;
    }

    // Удаление только для владельца
    if (project.ownerId != authProv.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только владелец может удалить проект.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление проекта'),
        content: const Text('Вы уверены, что хотите удалить этот проект?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await prov.deleteProject(project.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект успешно удален')),
      );
    }
  }

  Widget _buildProjectList(List<ProjectModel> projects, ProjectProvider provider, AuthProvider authProvider) {
    final currentUserId = authProvider.userId;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projects.length,
      itemBuilder: (itemContext, index) {
        final p = projects[index];
        final canEdit = provider.canEditProject(p); // Владелец или Редактор
        final isOwner = p.ownerId == currentUserId;

        return _ProjectCard(
            project: p,
            canEdit: canEdit,
            isOwner: isOwner,
            onEdit: (project) async {
              if (!canEdit) return;

              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectFormScreen(project: project, isNew: false),
                ),
              );

              if (!mounted) return;

              if (updated == true) {
                await provider.fetchProjects();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Проект успешно обновлен')),
                );
              }
            },
            onDelete: (project) => _confirmDelete(context, provider, project)
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final Function(ProjectModel) onEdit;
  final Function(ProjectModel) onDelete;
  final bool canEdit;
  final bool isOwner;

  const _ProjectCard({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.isOwner,
  });

  List<String> _getAllParticipantNames(ProjectModel project) {
    return project.participantsData
        .map((p) => p.fullName)
        .toList();
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('doc') || mimeType.contains('officedocument')) return Icons.description;
    if (mimeType.contains('audio') || mimeType.contains('mp3')) return Icons.audiotrack;
    if (mimeType.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String mimeType) {
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word') || mimeType.contains('doc') || mimeType.contains('officedocument')) return Colors.blue;
    if (mimeType.contains('audio')) return Colors.orange;
    if (mimeType.contains('image')) return Colors.purple;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final allParticipants = _getAllParticipantNames(project);
    final participantCount = project.participantsData.length;
    final attachments = project.attachments;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: canEdit ? () => onEdit(project) : null,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ЗАГОЛОВОК ---
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: project.statusEnum.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit(project);
                        } else if (value == 'delete') {
                          onDelete(project);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Открыть')),
                        // Кнопка удаления только для владельца
                        if (isOwner)
                          const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
                      ],
                      child: const Icon(Icons.more_vert, size: 20),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // --- ИНФОРМАЦИЯ ---
              Text('Срок: ${DateFormat('dd.MM.yyyy').format(project.deadline)}', style: const TextStyle(fontSize: 13)),
              Text('Статус: ${project.statusEnum.text}', style: const TextStyle(fontSize: 13)),

              const SizedBox(height: 4),
              if (participantCount > 0)
                Text(
                  'Участники: ${allParticipants.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                const Text(
                  'Участники: Нет',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),

              if (project.grade != null && project.statusEnum == ProjectStatus.completed)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('Оценка: ${project.grade!.truncate()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

              // --- ОТОБРАЖЕНИЕ ВЛОЖЕНИЙ В КАРТОЧКЕ ---
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final att = attachments[index];
                      final isImage = att.mimeType.contains('image');
                      final publicUrl = Supabase.instance.client.storage
                          .from(SupabaseService.bucket)
                          .getPublicUrl(att.filePath);

                      return Tooltip(
                        message: att.fileName,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isImage
                                ? Image.network(
                              publicUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 20, color: Colors.grey),
                            )
                                : Icon(
                              _getFileIcon(att.mimeType),
                              color: _getFileColor(att.mimeType),
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (!canEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Только просмотр',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}