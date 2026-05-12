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

class _ProjectTasksWidgetState
    extends State<ProjectTasksWidget> {
  final TaskService _taskService = TaskService();

  final TextEditingController _taskController =
  TextEditingController();

  final FocusNode _taskFocusNode = FocusNode();

  Stream<List<TaskModel>>? _tasksStream;

  bool _isAdding = false;

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
        _taskService.disposeProject(
          oldWidget.projectId,
        ),
      );

      _initStream();
    }
  }

  void _initStream() {
    _tasksStream = _taskService.getTasksStream(
      widget.projectId,
    );
  }

  // =========================================================
  // ADD TASK
  // =========================================================

  Future<void> _addTask() async {
    if (_isAdding) {
      return;
    }

    final title = _taskController.text.trim();

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
        widget.projectId,
        title,
      );

      if (!mounted) {
        return;
      }

      _taskController.clear();
      _taskFocusNode.requestFocus();

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
      builder: (_) => AlertDialog(
        title: Text(
          'common.delete'.tr(),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: Text(
              'common.delete'.tr(),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // =========================================================
  // DELETE TASK
  // =========================================================

  Future<void> _deleteTask(TaskModel task) async {
    try {
      await _taskService.deleteTask(task.id);

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
    }
  }

  // =========================================================
  // TOGGLE TASK
  // =========================================================

  Future<void> _toggleTask(TaskModel task) async {
    try {
      await _taskService.toggleTask(
        task.id,
        task.isCompleted,
      );
    } catch (e) {
      if (mounted) {
        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
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

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildHeader(
          textTheme,
          colorScheme,
        ),

        const SizedBox(height: 12),

        if (widget.canEdit)
          _buildInput(colorScheme),

        StreamBuilder<List<TaskModel>>(
          stream: _tasksStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding:
                const EdgeInsets.all(8),
                child: Text(
                  'common.error_loading'.tr(),
                  style: TextStyle(
                    color: colorScheme.error,
                  ),
                ),
              );
            }

            if (!snapshot.hasData &&
                snapshot.connectionState ==
                    ConnectionState.waiting) {
              return const Padding(
                padding:
                EdgeInsets.all(24),
                child: Center(
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            final tasks =
                snapshot.data ?? const [];

            if (tasks.isEmpty) {
              return _buildEmpty(
                colorScheme,
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder:
                  (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (
                  context,
                  index,
                  ) {
                final task = tasks[index];

                if (!widget.canEdit) {
                  return _buildTaskTile(
                    task,
                    colorScheme,
                  );
                }

                return Dismissible(
                  key: ValueKey(task.id),
                  direction:
                  DismissDirection.endToStart,
                  confirmDismiss: (_) =>
                      _confirmDelete(),
                  onDismissed: (_) =>
                      _deleteTask(task),
                  background: Container(
                    alignment:
                    Alignment.centerRight,
                    padding:
                    const EdgeInsets.only(
                      right: 20,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme
                          .errorContainer,
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      Icons.delete,
                      color: colorScheme
                          .onErrorContainer,
                    ),
                  ),
                  child: _buildTaskTile(
                    task,
                    colorScheme,
                  ),
                );
              },
            );
          },
        ),
      ],
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
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'tasks.title'.tr(),
          style:
          textTheme.titleMedium?.copyWith(
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

  // =========================================================
  // INPUT
  // =========================================================

  Widget _buildInput(
      ColorScheme colorScheme,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _taskController,
              focusNode: _taskFocusNode,
              textCapitalization:
              TextCapitalization.sentences,
              onSubmitted: (_) => _addTask(),
              decoration: InputDecoration(
                hintText:
                'tasks.hint'.tr(),
                isDense: true,
                filled: true,
                fillColor: colorScheme
                    .surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed:
            _isAdding ? null : _addTask,
            icon: _isAdding
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
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

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _buildEmpty(
      ColorScheme colorScheme,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 32,
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 40,
            color:
            colorScheme.outlineVariant,
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
    );
  }

  // =========================================================
  // TASK TILE
  // =========================================================

  Widget _buildTaskTile(
      TaskModel task,
      ColorScheme colorScheme,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: task.isCompleted
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        controlAffinity:
        ListTileControlAffinity.leading,
        onChanged: widget.canEdit
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
      ),
    ).animate().fadeIn(
      duration: 150.ms,
    );
  }
}