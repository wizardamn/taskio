import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// --- ИМПОРТЫ ---
import '../../providers/auth_provider.dart'; // <-- Импорт AuthProvider
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
      final authProv = context.read<AuthProvider>(); // <-- Получаем AuthProvider

      // --- ОБНОВЛЕНО: Проверка гостевого режима ---
      if (authProv.isGuest) { // <-- Используем isGuest из AuthProvider
        prov.setGuestUser(); // <-- Устанавливаем гостевой режим в ProjectProvider
      } else {
        await prov.fetchProjects(); // <-- Загружаем проекты для авторизованного пользователя
      }
    });
  }

  // =====================================================
  //               ГЛАВНЫЙ BUILD МЕТОД
  // =====================================================
  @override
  Widget build(BuildContext context) {
    // Используем context.watch для подписки на изменения в ProjectProvider
    final prov = context.watch<ProjectProvider>();
    // --- ИСПРАВЛЕНО: Следим за AuthProvider ---
    final authProv = context.watch<AuthProvider>();
    final projects = prov.view;

    // --- ОБНОВЛЕНО: Проверка гостя ---
    final isActuallyGuest = authProv.isGuest || prov.isGuest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои проекты'), // Русификация
        actions: [
          // --- ИКОНКА КОЛОКОЛЬЧИКА: ПОКАЗЫВАЕТСЯ НЕ ВСЕГДА ---
          if (!isActuallyGuest) // <-- Скрываем колокольчик для гостя
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
              const PopupMenuItem(value: 'dAsc', child: Text('Cначала новые')), // Русификация
              const PopupMenuItem(value: 'dDesc', child: Text('Сначала старые')), // Русификация
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
            // --- ИСПРАВЛЕНО: Используем объединённый флаг ---
            isActuallyGuest
                ? "Войдите в аккаунт, чтобы увидеть проекты"
                : "Нет проектов",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        )
            : _buildProjectList(projects, prov), // Передаем провайдер
      ),

      // Кнопка «добавить» показывается ТОЛЬКО когда пользователь авторизован и НЕ гость
      floatingActionButton: isActuallyGuest // <-- Проверяем объединённый флаг
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

    // --- ПРОВЕРКА: Убедимся, что пользователь не гость ---
    if (prov.isGuest) {
      if (!mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед setState
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Гости не могут создавать проекты.')),
      );
      return;
    }

    // Анимация нажатия
    setState(() => _fabScale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    // setState safe, так как вызывается в том же виджете, что и находится
    if (!mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед setState
    setState(() => _fabScale = 1.0);

    ProjectModel newProject;
    try {
      newProject = prov.createEmptyProject();
    } catch (e) {
      if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }


    // 2. Асинхронный gap
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(project: newProject, isNew: true),
      ),
    );

    // 3. Проверка mounted после gap
    if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context

    if (created == true) { // Проверяем на true, как указано в ProjectFormScreen
      // Нет необходимости в await, так как ProjectListScreen и так подписан
      // на провайдера через context.watch, но для немедленного обновления вызываем fetchProjects.
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
      BuildContext context, ProjectProvider prov, ProjectModel project) async {
    // --- ПРОВЕРКА: Убедимся, что пользователь не гость ---
    if (prov.isGuest) {
      if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Гости не могут удалять проекты.')),
      );
      return;
    }

    // Проверка прав перед вызовом диалога
    if (!prov.canEditProject(project)) {
      if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет прав на удаление этого проекта')), // Русификация
      );
      return;
    }


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
    if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context

    if (confirmed == true) {
      await prov.deleteProject(project.id);

      // Проверяем mounted перед использованием ScaffoldMessenger
      if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект успешно удален')), // Русификация
      );
    }
  }

  // =====================================================
  //               СПИСОК И КАРТОЧКА
  // =====================================================
  // Принимаем провайдер как аргумент
  Widget _buildProjectList(List<ProjectModel> projects, ProjectProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final p = projects[index];
        // Определяем права на редактирование, используя переданный провайдер
        final canEdit = provider.canEditProject(p); // <-- Убедимся, что canEditProject проверяет isGuest


        return _ProjectCard(
            project: p,
            canEdit: canEdit, // Передаем права в карточку
            onEdit: (project) async {
              // Если нет прав, просто выходим
              // Тут не нужна дополнительная проверка canEdit, т.к. она есть в _ProjectCard.onTap
              // но оставляем ее на всякий случай, если функция onEdit вызывается напрямую
              if (!canEdit) return;

              // Здесь не используем context.read, а просто обращаемся к Navigation
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectFormScreen(project: project, isNew: false),
                ),
              );

              // Проверка mounted после await
              if (!context.mounted) return; // <-- ИСПРАВЛЕНО: Проверка mounted перед использованием context

              if (updated == true) {
                // Используем переданный провайдер для обновления данных
                await provider.fetchProjects();

                // Дополнительное уведомление об успехе
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Проект успешно обновлен')),
                );
              }
            },
            // Используем переданный провайдер
            onDelete: (project) => _confirmDelete(context, provider, project)
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
  final Function(ProjectModel) onDelete;
  final bool canEdit; // Новое поле для прав

  const _ProjectCard({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit, // Требуем права
  });

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
        // Разрешаем переход на форму, только если есть права на редактирование
        // ЭТОТ МЕТОД РАБОТАЕТ КОРРЕКТНО:
        onTap: canEdit ? () => onEdit(project) : null, // <-- onTap вызывает onEdit
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

            // ✅ УЧАСТНИКИ: Теперь этот список должен быть заполнен, если RLS позволяет
            if (participantCount > 0)
              Text(
                // Теперь отображаются все участники, разделенные запятыми
                'Участники: ${allParticipants.join(', ')} (Всего $participantCount чел.)',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              )
            else
              const Text(
                'Участники: Нет данных',
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

            // --- ДОБАВЛЕНО ДЛЯ ОТЛАДКИ ПРАВ ---
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Нет прав на редактирование/удаление.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // ------------------------------------
          ],
        ),

        // Меню: редактировать/удалить показывается только если есть права
        trailing: canEdit
            ? PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit(project);
            } else if (value == 'delete') {
              onDelete(project); // Передаем весь проект
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Изменить')),
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
          ],
          icon: const Icon(Icons.more_vert),
        )
            : null, // Если нет прав, кнопка не показывается
      ),
    );
  }
}