import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../utils/snackbar_manager.dart';
import '../utils/error_mapper.dart';

class ProjectTasksWidget extends StatefulWidget {
  final String projectId;
  final bool canEdit;

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

  late Stream<List<TaskModel>> _tasksStream;

  bool _isAdding = false;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    _tasksStream = _taskService.getTasksStream(widget.projectId);
  }

  // =========================================================
  // ADD TASK
  // =========================================================

  Future<void> _addTask() async {
    final title = _taskController.text.trim();

    if (title.isEmpty) {
      SnackbarManager.showWarning('validation.empty_field'.tr());
      return;
    }

    setState(() => _isAdding = true);

    try {
      await _taskService.addTask(widget.projectId, title);

      _taskController.clear();
      _taskFocusNode.requestFocus();
    } catch (e) {
      SnackbarManager.showError(ErrorMapper.map(e));
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  // =========================================================
  // DELETE CONFIRM
  // =========================================================

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('common.delete'.tr()),
        content: Text('tasks.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(textTheme, colorScheme),
        const SizedBox(height: 12),

        if (widget.canEdit) _buildInput(colorScheme),

        StreamBuilder<List<TaskModel>>(
          stream: _tasksStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'common.error_loading'.tr(),
                  style: TextStyle(color: colorScheme.error),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final tasks = snapshot.data!;

            if (tasks.isEmpty) {
              return _buildEmpty(colorScheme);
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
                  key: ValueKey(task.id),
                  direction: DismissDirection.endToStart,

                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),

                  confirmDismiss: (_) => _confirmDelete(),

                  onDismissed: (_) async {
                    try {
                      await _taskService.deleteTask(task.id);
                    } catch (e) {
                      SnackbarManager.showError(ErrorMapper.map(e));
                    }
                  },

                  child: _buildTaskTile(task, colorScheme),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // =========================================================
  // UI
  // =========================================================

  Widget _buildHeader(TextTheme textTheme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'tasks.title'.tr(),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (widget.canEdit)
          Text(
            'tasks.swipe_to_delete'.tr(),
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.outline,
            ),
          ),
      ],
    );
  }

  Widget _buildInput(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _taskController,
              focusNode: _taskFocusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'tasks.hint'.tr(),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 40,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'tasks.no_tasks'.tr(),
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(TaskModel task, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: task.isCompleted
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        onChanged: widget.canEdit
            ? (_) => _taskService.toggleTask(
          task.id,
          task.isCompleted,
        )
            : null,
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
            task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideX(begin: 0.02);
  }
}