import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
      // Использование context.read безопасно, так как нет async gap до него
      final prov = context.read<ProjectProvider>();
      // ✅ Загружаем/обновляем проекты при инициализации
      await prov.fetchProjects();
    });
  }

  // =====================================================
  //               ГЛАВНЫЙ BUILD МЕТОД
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final projects = prov.view;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои проекты'), // Русификация
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Нет новых уведомлений')), // Русификация
              );
            },
          ),

          // Фильтр и Сортировка
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_alt),
            onSelected: (value) => _onSortFilter(value, prov),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dAsc', child: Text('Срок: сначала ранние')), // Русификация
              const PopupMenuItem(value: 'dDesc', child: Text('Срок: сначала поздние')), // Русификация
              const PopupMenuItem(value: 'status', child: Text('По статусу')), // Русификация
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'all', child: Text('Все проекты')), // Русификация
              const PopupMenuItem(value: 'inProgress', child: Text('В работе')), // Русификация
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
          tooltip: 'Создать проект', // Русификация
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // =====================================================
  //               ОБРАБОТЧИКИ ДЕЙСТВИЙ
  // =====================================================

  /// Обработчик нажатия на FAB
  Future<void> _addProject() async {
    // 1. Читаем провайдер до первого await
    final prov = context.read<ProjectProvider>();

    // Анимация нажатия
    setState(() => _fabScale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    // setState safe, так как вызывается в том же виджете, что и находится
    setState(() => _fabScale = 1.0);

    final newProject = prov.createEmptyProject();

    // 2. Асинхронный gap
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(project: newProject, isNew: true),
      ),
    );

    // 3. Проверка mounted после gap
    if (!context.mounted) return;

    if (created != null) {
      await prov.fetchProjects();

      // 4. Используем context безопасно
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект успешно создан')), // Русификация
      );
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
    // showDialog использует переданный context, что безопасно
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление проекта'), // Русификация
        content: const Text('Вы уверены, что хотите удалить этот проект?'), // Русификация
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'), // Русификация
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'), // Русификация
          ),
        ],
      ),
    );

    // Проверяем mounted перед использованием context после await
    if (!context.mounted) return;

    if (confirmed == true) {
      await prov.deleteProject(id);

      // Проверяем mounted перед использованием ScaffoldMessenger
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект успешно удален')), // Русификация
      );
    }
  }

  // =====================================================
  //               СПИСОК И КАРТОЧКА
  // =====================================================
  Widget _buildProjectList(List<ProjectModel> projects) {
    // Читаем провайдер один раз перед циклом/созданием виджетов
    final provider = context.read<ProjectProvider>();

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

              // Проверка mounted после await
              if (!context.mounted) return;

              if (updated == true) {
                // Используем захваченный provider
                await provider.fetchProjects();
              }
            },
            onDelete: (id) => _confirmDelete(context, provider, id)
        );
      },
    );
  }
}

// =====================================================
//               ОТДЕЛЬНАЯ КАРТОЧКА ПРОЕКТА
// =====================================================
class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final Function(ProjectModel) onEdit;
  final Function(String) onDelete;

  const _ProjectCard({required this.project, required this.onEdit, required this.onDelete});

  /// Получает имена ВСЕХ участников
  List<String> _getAllParticipantNames(ProjectModel project) {
    // Включаем всех, так как `participantsData` уже должен содержать
    // всех актуальных участников, включая владельца.
    return project.participantsData
        .map((p) => p.fullName)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allParticipants = _getAllParticipantNames(project);
    final participantCount = project.participantsData.length;

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
            // Срок
            Text('Срок: ${DateFormat('dd.MM.yyyy').format(project.deadline)}'),

            // Статус
            Text('Статус: ${project.statusEnum.text}'),

            // Участники (включая владельца, если их больше 1)
            if (participantCount > 1)
              Text(
                // Теперь отображаются все участники, разделенные запятыми
                'Участники: ${allParticipants.join(', ')} (Всего $participantCount чел.)',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              )
            else if (participantCount == 1)
              const Text(
                'Участники: Только владелец',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),

            // Оценка
            if (project.grade != null && project.statusEnum == ProjectStatus.completed)
              Text('Оценка: ${project.grade!.truncate()}', // Отображаем как целое число
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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
            const PopupMenuItem(value: 'edit', child: Text('Изменить')),
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}