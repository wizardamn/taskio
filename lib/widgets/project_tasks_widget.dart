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
  bool _isAdding = false;

  void _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await _taskService.addTask(widget.projectId, title);
      _taskController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Задачи", style: Theme.of(context).textTheme.titleMedium),
            if (widget.canEdit)
              Text(
                "Свайп влево для удаления",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Поле добавления
        if (widget.canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: 'Новая задача...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isAdding ? null : _addTask,
                  icon: _isAdding
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

        // Список задач
        StreamBuilder<List<TaskModel>>(
          stream: _taskService.getTasksStream(widget.projectId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Ошибка загрузки задач');
            if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());

            final tasks = snapshot.data!;

            if (tasks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Нет задач", style: TextStyle(color: Colors.grey.shade400)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return widget.canEdit
                    ? Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red.shade100,
                    child: Icon(Icons.delete, color: Colors.red.shade700),
                  ),
                  onDismissed: (_) => _taskService.deleteTask(task.id),
                  child: _buildTaskTile(task),
                )
                    : _buildTaskTile(task);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskTile(TaskModel task) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        onChanged: widget.canEdit
            ? (v) => _taskService.toggleTask(task.id, task.isCompleted)
            : null,
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : Colors.black87,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        activeColor: Theme.of(context).primaryColor,
      ),
    ).animate().fadeIn().slideX(begin: -0.05, end: 0);
  }
}