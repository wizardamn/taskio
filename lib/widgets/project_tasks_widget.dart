import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';

class ProjectTasksWidget extends StatefulWidget {
  final String projectId;
  final bool canEdit; // Если false - только просмотр

  const ProjectTasksWidget({
    super.key,
    required this.projectId,
    required this.canEdit,
  });

  @override
  State<ProjectTasksWidget> createState() => _ProjectTasksWidgetState();
}

class _ProjectTasksWidgetState extends State<ProjectTasksWidget> {
  final TaskService _taskService = TaskService();
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();
  bool _isAdding = false;

  /// Добавление новой задачи
  void _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await _taskService.addTask(widget.projectId, title);
      _taskController.clear();
      // Возвращаем фокус после добавления для быстрого ввода нескольких задач
      _taskFocusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при добавлении: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Задачи проекта", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (widget.canEdit)
              Text(
                "Свайп для удаления",
                style: TextStyle(fontSize: 10, color: colorScheme.outline),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Поле ввода для создания задачи
        if (widget.canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    focusNode: _taskFocusNode,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Что нужно сделать?',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isAdding ? null : _addTask,
                  icon: _isAdding
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

        // Стрим со списком задач
        StreamBuilder<List<TaskModel>>(
          stream: _taskService.getTasksStream(widget.projectId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Ошибка загрузки задач', style: TextStyle(color: colorScheme.error)),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }

            final tasks = snapshot.data!;

            if (tasks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 40, color: colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      Text("Список задач пуст", style: TextStyle(color: colorScheme.outline)),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];

                if (!widget.canEdit) {
                  return _buildTaskTile(task, colorScheme);
                }

                return Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    // Можно добавить диалог подтверждения, если задача важная
                    return true;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_sweep_outlined, color: colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => _taskService.deleteTask(task.id),
                  child: _buildTaskTile(task, colorScheme),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Визуальный элемент задачи
  Widget _buildTaskTile(TaskModel task, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: task.isCompleted
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isCompleted
              ? colorScheme.outlineVariant.withOpacity(0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        onChanged: widget.canEdit
            ? (v) => _taskService.toggleTask(task.id, task.isCompleted)
            : null,
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 14,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? colorScheme.outline : colorScheme.onSurface,
            fontWeight: task.isCompleted ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.only(left: 4, right: 8),
        activeColor: colorScheme.primary,
        checkColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.02, end: 0);
  }
}