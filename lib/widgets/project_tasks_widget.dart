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

  /// true только для owner/editor.
  /// Даёт право добавлять и удалять задачи.
  final bool canEdit;

  /// true для owner/editor/viewer.
  /// Даёт право отмечать задачу выполненной/невыполненной.
  final bool canCompleteTasks;

  const ProjectTasksWidget({
    super.key,
    required this.projectId,
    required this.canEdit,
    this.canCompleteTasks = true,
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

  bool get _canManageTasks {
    return widget.canEdit;
  }

  bool get _canCompleteTasks {
    return widget.canCompleteTasks;
  }

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
  // TEXT
  // =========================================================

  String _text({
    required String ru,
    required String en,
  }) {
    return context.locale.languageCode == 'ru' ? ru : en;
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
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
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
    if (_isAdding || !_canManageTasks) {
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

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'tasks.added'.tr(),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
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
      builder: (dialogContext) {
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
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'common.cancel'.tr(),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.delete_outline,
              ),
              label: Text(
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
    if (!_canManageTasks) {
      return;
    }

    if (_processingTaskIds.contains(task.id)) {
      return;
    }

    final confirmed = await _confirmDelete();

    if (!mounted || !confirmed) {
      return;
    }

    try {
      setState(() {
        _processingTaskIds.add(task.id);
      });

      await _taskService.deleteTask(task.id);

      await _taskService.refreshTasks(widget.projectId);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'tasks.deleted'.tr(),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
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
    if (!_canCompleteTasks) {
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
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
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
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              textTheme,
              colorScheme,
            ),

            if (_canManageTasks) ...[
              const SizedBox(height: 14),
              _buildInput(colorScheme),
            ],

            const SizedBox(height: 14),

            StreamBuilder<List<TaskModel>>(
              stream: _tasksStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildError(colorScheme);
                }

                if (!snapshot.hasData &&
                    snapshot.connectionState ==
                        ConnectionState.waiting) {
                  return _buildLoading(colorScheme);
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.checklist_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tasks.title'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _headerSubtitle(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        if (_isRefreshing)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          )
        else
          IconButton(
            tooltip: 'common.refresh'.tr(),
            onPressed: _refreshTasks,
            icon: Icon(
              Icons.refresh,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  String _headerSubtitle() {
    if (_canManageTasks) {
      return _text(
        ru: 'Добавляйте и отмечайте задачи проекта',
        en: 'Add and complete project tasks',
      );
    }

    if (_canCompleteTasks) {
      return _text(
        ru: 'Отмечайте выполнение задач проекта',
        en: 'Complete project tasks',
      );
    }

    return _text(
      ru: 'Просмотр задач проекта',
      en: 'Project tasks view',
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
              prefixIcon: const Icon(
                Icons.task_alt_outlined,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant,
                ),
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

        if (!_canManageTasks) {
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

            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(
              right: 20,
            ),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.delete_outline,
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
  // LOADING / EMPTY / ERROR
  // =========================================================

  Widget _buildLoading(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 20,
      ),
      child: Column(
        children: List.generate(
          3,
              (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == 2 ? 0 : 8,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
              )
                  .animate(
                onPlay: (controller) {
                  controller.repeat(
                    reverse: true,
                  );
                },
              ).fade(
                begin: 0.45,
                end: 0.95,
                duration: 900.ms,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty(
      ColorScheme colorScheme,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 28,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 42,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'common.error_loading'.tr(),
              style: TextStyle(
                color: colorScheme.onErrorContainer,
              ),
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
    final isProcessing = _processingTaskIds.contains(task.id);

    return Container(
      decoration: BoxDecoration(
        color: task.isCompleted
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isCompleted
              ? colorScheme.outlineVariant.withValues(alpha: 0.7)
              : colorScheme.outlineVariant,
        ),
      ),
      child: CheckboxListTile(
        value: task.isCompleted,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.only(
          left: 8,
          right: 4,
        ),
        onChanged: _canCompleteTasks && !isProcessing
            ? (_) => _toggleTask(task)
            : null,
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: task.isCompleted
                ? FontWeight.w400
                : FontWeight.w500,
            color: task.isCompleted
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface,
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        secondary: isProcessing
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        )
            : _canManageTasks
            ? IconButton(
          tooltip: 'common.delete'.tr(),
          icon: Icon(
            Icons.delete_outline,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => _deleteTask(task),
        )
            : null,
      ),
    ).animate().fadeIn(
      duration: 150.ms,
    );
  }
}