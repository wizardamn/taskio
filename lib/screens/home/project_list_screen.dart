import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import 'project_form_screen.dart';
import '../../widgets/user_profile_drawer.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  // Для анимации FloatingActionButton
  double _fabScale = 1.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<ProjectProvider>();
      // ✅ Загружаем/обновляем проекты при инициализации
      await prov.fetchProjects();
    });
  }

  // =====================================================
  //                 ГЛАВНЫЙ BUILD МЕТОД
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final projects = prov.view;

    return Scaffold(
      appBar: AppBar(
        title: Text('my_projects'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('no_new_notifications'.tr())),
              );
            },
          ),

          // Фильтр и Сортировка
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_alt),
            onSelected: (value) => _onSortFilter(value, prov),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'dAsc', child: Text('sort_deadline_asc'.tr())),
              PopupMenuItem(value: 'dDesc', child: Text('sort_deadline_desc'.tr())),
              PopupMenuItem(value: 'status', child: Text('sort_status'.tr())),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'all', child: Text('filter_all'.tr())),
              PopupMenuItem(value: 'inProgress', child: Text('filter_in_progress'.tr())),
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
            prov.isGuest
                ? "Войдите в аккаунт, чтобы увидеть проекты"
                : "Нет проектов",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        )
            : _buildProjectList(projects),
      ),

      // Кнопка «добавить» показывается ТОЛЬКО когда пользователь авторизован
      floatingActionButton: prov.isGuest
          ? null
          : AnimatedScale(
        scale: _fabScale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
        child: FloatingActionButton(
          onPressed: _addProject,
          tooltip: 'create_project'.tr(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // =====================================================
  //                 ОБРАБОТЧИКИ ДЕЙСТВИЙ
  // =====================================================

  /// Обработчик нажатия на FAB
  Future<void> _addProject() async {
    if (!context.mounted) return;

    // Анимация нажатия
    setState(() => _fabScale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _fabScale = 1.0);

    final prov = context.read<ProjectProvider>();
    final newProject = prov.createEmptyProject();

    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(project: newProject, isNew: true),
      ),
    );

    if (context.mounted && created != null) {
      // Обновляем список после создания
      await prov.fetchProjects();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('project_created'.tr())),
        );
      }
    }
  }

  // Фильтрация и сортировка
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

  // Подтверждение удаления
  Future<void> _confirmDelete(
      BuildContext context, ProjectProvider prov, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_project_title'.tr()),
        content: Text('delete_project_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (context.mounted && confirmed == true) {
      await prov.deleteProject(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('project_deleted'.tr())),
        );
      }
    }
  }

  // =====================================================
  //                 СПИСОК И КАРТОЧКА
  // =====================================================
  Widget _buildProjectList(List<ProjectModel> projects) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final p = projects[index];

        return _ProjectCard(
            project: p,
            onEdit: (project) async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectFormScreen(project: project, isNew: false),
                ),
              );
              if (context.mounted && updated != null) {
                await context.read<ProjectProvider>().fetchProjects();
              }
            },
            onDelete: (id) => _confirmDelete(context, context.read<ProjectProvider>(), id)
        );
      },
    );
  }
}

// =====================================================
//                 ОТДЕЛЬНАЯ КАРТОЧКА ПРОЕКТА
// =====================================================
class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final Function(ProjectModel) onEdit;
  final Function(String) onDelete;

  const _ProjectCard({required this.project, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: () => onEdit(project),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

        leading: Container(
          width: 10,
          decoration: BoxDecoration(
            // Используем цвет из расширения
            color: project.statusEnum.color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),

        title: Text(
          project.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('deadline'.tr(args: [DateFormat('dd.MM.yyyy').format(project.deadline)])),

            // ✅ ИСПРАВЛЕНО: Используем геттер text из расширения
            // Убедитесь, что файл project_model.dart импортирован
            Text('status'.tr(args: [project.statusEnum.text])),

            if (project.participants.isNotEmpty)
              Text('participants'.tr(args: [project.participants.join(', ')])),

            if (project.grade != null)
              Text('grade'.tr(args: [project.grade!.toStringAsFixed(1)])),
          ],
        ),

        // Меню: редактировать/удалить
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit(project);
            } else if (value == 'delete') {
              onDelete(project.id);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('edit'.tr())),
            PopupMenuItem(value: 'delete', child: Text('delete'.tr())),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}