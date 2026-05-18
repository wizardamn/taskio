import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../utils/error_mapper.dart';
import '../utils/snackbar_manager.dart';

class ProjectTasksWidget extends StatefulWidget {
  final String projectId;
  final bool canEdit;

  const ProjectTasksWidget({
    super.key,
    required this.projectId,
    required this.canEdit,
  });

  @override
  State<ProjectTasksWidget> createState() =>
      _ProjectTasksWidgetState();
}

class _ProjectTasksWidgetState extends State<ProjectTasksWidget> {
  final TaskService _taskService = TaskService();

  final TextEditingController _taskController =
  TextEditingController();

  final FocusNode _taskFocusNode = FocusNode();

  Stream<List<TaskModel>>? _tasksStream;

  bool _isAdding = false;
  bool _isRefreshing = false;

  final Set<String> _processingTaskIds = {};

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(
      covariant ProjectTasksWidget oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      unawaited(
        _taskService.disposeProject(oldWidget.projectId),
      );

      _initStream();

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _initStream() {
    final projectId = widget.projectId.trim();

    if (projectId.isEmpty) {
      _tasksStream = const Stream.empty();
      return;
    }

    _tasksStream = _taskService.getTasksStream(projectId);
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> _refreshTasks() async {
    if (_isRefreshing) {
      return;
    }

    final projectId = widget.projectId.trim();

    if (projectId.isEmpty) {
      return;
    }

    try {
      setState(() {
        _isRefreshing = true;
      });

      await _taskService.refreshTasks(projectId);
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // =========================================================
  // ADD TASK
  // =========================================================

  Future<void> _addTask() async {
    if (_isAdding || !widget.canEdit) {
      return;
    }

    final projectId = widget.projectId.trim();
    final title = _taskController.text.trim();

    if (projectId.isEmpty) {
      return;
    }

    if (title.isEmpty) {
      SnackbarManager.showWarning(
        'validation.empty_field'.tr(),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      await _taskService.addTask(
        projectId,
        title,
      );

      if (!mounted) {
        return;
      }

      _taskController.clear();
      _taskFocusNode.requestFocus();

      await _taskService.refreshTasks(projectId);

      SnackbarManager.showSuccess(
        'tasks.added'.tr(),
      );
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  // =========================================================
  // DELETE CONFIRM
  // =========================================================

  Future<bool> _confirmDelete() async {
    if (!mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            'tasks.delete_title'.tr(),
          ),
          content: Text(
            'tasks.delete_confirm'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                'common.cancel'.tr(),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text(
                'common.delete'.tr(),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // =========================================================
  // DELETE TASK
  // =========================================================

  Future<void> _deleteTask(TaskModel task) async {
    if (!widget.canEdit) {
      return;
    }

    if (_processingTaskIds.contains(task.id)) {
      return;
    }

    final confirmed = await _confirmDelete();

    if (!confirmed) {
      return;
    }

    try {
      setState(() {
        _processingTaskIds.add(task.id);
      });

      await _taskService.deleteTask(task.id);

      await _taskService.refreshTasks(widget.projectId);

      if (mounted) {
        SnackbarManager.showSuccess(
          'tasks.deleted'.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingTaskIds.remove(task.id);
        });
      }
    }
  }

  // =========================================================
  // TOGGLE TASK
  // =========================================================

  Future<void> _toggleTask(TaskModel task) async {
    if (!widget.canEdit) {
      return;
    }

    if (_processingTaskIds.contains(task.id)) {
      return;
    }

    try {
      setState(() {
        _processingTaskIds.add(task.id);
      });

      await _taskService.toggleTask(
        task.id,
        task.isCompleted,
      );

      await _taskService.refreshTasks(widget.projectId);
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingTaskIds.remove(task.id);
        });
      }
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    unawaited(
      _taskService
          .disposeProject(widget.projectId)
          .catchError((_) {}),
    );

    _taskController.dispose();
    _taskFocusNode.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              textTheme,
              colorScheme,
            ),

            const SizedBox(height: 12),

            if (widget.canEdit) ...[
              _buildInput(colorScheme),
              const SizedBox(height: 4),
            ],

            StreamBuilder<List<TaskModel>>(
              stream: _tasksStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildError(colorScheme);
                }

                if (!snapshot.hasData &&
                    snapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final tasks = snapshot.data ?? const <TaskModel>[];

                if (tasks.isEmpty) {
                  return _buildEmpty(colorScheme);
                }

                return _buildTaskList(
                  tasks,
                  colorScheme,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(
      TextTheme textTheme,
      ColorScheme colorScheme,
      ) {
    return Row(
      children: [
        Icon(
          Icons.checklist,
          color: colorScheme.primary,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            'tasks.title'.tr(),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (_isRefreshing)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
        else
          IconButton(
            tooltip: 'common.refresh'.tr(),
            onPressed: _refreshTasks,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
      ],
    );
  }

  // =========================================================
  // INPUT
  // =========================================================

  Widget _buildInput(
      ColorScheme colorScheme,
      ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _taskController,
            focusNode: _taskFocusNode,
            enabled: !_isAdding,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTask(),
            decoration: InputDecoration(
              hintText: 'tasks.hint'.tr(),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        IconButton.filled(
          tooltip: 'common.add'.tr(),
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
    );
  }

  // =========================================================
  // TASK LIST
  // =========================================================

  Widget _buildTaskList(
      List<TaskModel> tasks,
      ColorScheme colorScheme,
      ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        final task = tasks[index];

        if (!widget.canEdit) {
          return _buildTaskTile(
            task,
            colorScheme,
          );
        }

        return Dismissible(
          key: ValueKey(task.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _deleteTask(task);

            // Возвращаем false, потому что список сам обновится через stream.
            // Так Dismissible не удаляет элемент раньше базы данных.
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(
              right: 20,
            ),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete,
              color: colorScheme.onErrorContainer,
            ),
          ),
          child: _buildTaskTile(
            task,
            colorScheme,
          ),
        );
      },
    );
  }

  // =========================================================
  // EMPTY / ERROR
  // =========================================================

  Widget _buildEmpty(
      ColorScheme colorScheme,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 32,
      ),
      child: Center(
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
              style: TextStyle(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(
      ColorScheme colorScheme,
      ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        'common.error_loading'.tr(),
        style: TextStyle(
          color: colorScheme.error,
        ),
      ),
    );
  }

  // =========================================================
  // TASK TILE
  // =========================================================

  Widget _buildTaskTile(
      TaskModel task,
      ColorScheme colorScheme,
      ) {
    final isProcessing = _processingTaskIds.contains(task.id);

    return Container(
      decoration: BoxDecoration(
        color: task.isCompleted
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: widget.canEdit && !isProcessing
            ? (_) => _toggleTask(task)
            : null,
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        secondary: isProcessing
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        )
            : widget.canEdit
            ? IconButton(
          tooltip: 'common.delete'.tr(),
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteTask(task),
        )
            : null,
      ),
    ).animate().fadeIn(
      duration: 150.ms,
    );
  }
}