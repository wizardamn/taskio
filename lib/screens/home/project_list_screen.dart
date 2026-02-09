import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/auth_provider.dart';
import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import 'project_form_screen.dart';
import '../../widgets/user_profile_drawer.dart';
import '../../widgets/project_card.dart';

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

  void _onSortFilter(String value, ProjectProvider prov) {
    switch (value) {
      case 'dAsc': prov.setSort(SortBy.deadlineAsc); break;
      case 'dDesc': prov.setSort(SortBy.deadlineDesc); break;
      case 'status': prov.setSort(SortBy.status); break;
      case 'all': prov.setFilter(ProjectFilter.all); break;
      case 'inProgress': prov.setFilter(ProjectFilter.inProgressOnly); break;
    }
  }

  Future<void> _addProject() async {
    final prov = context.read<ProjectProvider>();
    final authProv = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (authProv.isGuest || prov.isGuest) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Гости не могут создавать проекты.')),
      );
      return;
    }

    setState(() => _fabScale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _fabScale = 1.0);

    try {
      final newProject = prov.createEmptyProject();

      final created = await navigator.push(
        MaterialPageRoute(
          builder: (_) => ProjectFormScreen(project: newProject, isNew: true),
        ),
      );

      if (created == true && mounted) {
        await prov.fetchProjects();
        messenger.showSnackBar(
          const SnackBar(content: Text('Проект успешно создан')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmDelete(ProjectProvider prov, ProjectModel project) async {
    final authProv = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (project.ownerId != authProv.userId) {
      messenger.showSnackBar(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await prov.deleteProject(project.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Проект успешно удален')),
      );
    }
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Нет новых уведомлений')),
                );
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_alt),
            onSelected: (val) => _onSortFilter(val, prov),
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
            ? Center(child: Text(isActuallyGuest ? "Войдите, чтобы увидеть проекты" : "Нет проектов"))
            : ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: projects.length,
          itemBuilder: (itemContext, index) {
            final p = projects[index];
            return ProjectCard(
              project: p,
              canEdit: prov.canEditProject(p),
              isOwner: p.ownerId == authProv.userId,
              onEdit: (project) async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final updated = await navigator.push(
                  MaterialPageRoute(builder: (_) => ProjectFormScreen(project: project, isNew: false)),
                );

                if (updated == true && mounted) {
                  await prov.fetchProjects();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Обновлено')),
                  );
                }
              },
              onDelete: (project) => _confirmDelete(prov, project),
            ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.1, end: 0);
          },
        ),
      ),
      floatingActionButton: isActuallyGuest
          ? null
          : AnimatedScale(
        scale: _fabScale,
        duration: const Duration(milliseconds: 100),
        child: FloatingActionButton(
          onPressed: _addProject,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}