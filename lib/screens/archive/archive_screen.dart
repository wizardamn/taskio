import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../utils/error_mapper.dart';
import '../../utils/snackbar_manager.dart';
import '../../widgets/project_card.dart';

import '../home/project_chat_screen.dart';
import '../home/project_form_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({
    super.key,
  });

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  bool _isRefreshing = false;

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

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    final provider = context.read<ProjectProvider>();

    try {
      setState(() {
        _isRefreshing = true;
      });

      await provider.fetchProjects();
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
  // OPEN PROJECT
  // =========================================================

  Future<void> _openProject(ProjectModel project) async {
    final provider = context.read<ProjectProvider>();

    if (!provider.canOpenProject(project)) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    provider.setCurrentProject(project.id);

    final freshProject = await provider.refreshProject(
      project.id,
      makeCurrent: true,
    );

    if (!mounted) {
      return;
    }

    final projectToOpen = freshProject ?? project;

    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(
          project: projectToOpen,
          isNew: false,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await provider.refreshProject(
      project.id,
      makeCurrent: true,
    );

    if (updated == true) {
      SnackbarManager.showSuccess(
        'common.updated'.tr(),
      );
    }
  }

  // =========================================================
  // OPEN CHAT
  // =========================================================

  void _openChat(ProjectModel project) {
    final provider = context.read<ProjectProvider>();

    if (!provider.canOpenProject(project)) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    provider.setCurrentProject(project.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectChatScreen(
          projectId: project.id,
          projectTitle: project.title,
          participants: project.participantsData,
        ),
      ),
    );
  }

  // =========================================================
  // RESTORE PROJECT
  // =========================================================

  Future<bool> _confirmRestore(ProjectModel project) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _text(
              ru: 'Восстановить проект?',
              en: 'Restore project?',
            ),
          ),
          content: Text(
            _text(
              ru: 'Проект «${project.title}» будет снова перенесён в активные проекты.',
              en: 'Project “${project.title}” will be moved back to active projects.',
            ),
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
                Icons.restore_outlined,
              ),
              label: Text(
                _text(
                  ru: 'Восстановить',
                  en: 'Restore',
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _restoreProject(ProjectModel project) async {
    final provider = context.read<ProjectProvider>();

    if (!provider.canRestoreProject(project)) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    final confirmed = await _confirmRestore(project);

    if (!mounted || !confirmed) {
      return;
    }

    try {
      await provider.restoreProject(project);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        _text(
          ru: 'Проект восстановлен',
          en: 'Project restored',
        ),
      );

      await provider.fetchProjects();
    } catch (e) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // DELETE PROJECT
  // =========================================================

  Future<bool> _confirmDeleteProject(ProjectModel project) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'common.delete'.tr(),
          ),
          content: Text(
            _text(
              ru: 'Удалить проект «${project.title}»? Это действие нельзя отменить.',
              en: 'Delete project “${project.title}”? This action cannot be undone.',
            ),
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

  Future<void> _deleteProject(ProjectModel project) async {
    final provider = context.read<ProjectProvider>();

    if (!provider.isOwner(project)) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    final confirmed = await _confirmDeleteProject(project);

    if (!mounted || !confirmed) {
      return;
    }

    try {
      await provider.deleteProject(project.id);

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'projects.deleted_success'.tr(),
      );

      await provider.fetchProjects();
    } catch (e) {
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final projects = provider.archivedProjects;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'navigation.archive'.tr(),
        ),
        actions: [
          IconButton(
            tooltip: 'projects.refresh'.tr(),
            onPressed: _isRefreshing ? null : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: projects.isEmpty
            ? _buildEmptyState()
            : _buildArchiveList(projects),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _text(
                      ru: 'Архив пуст',
                      en: 'Archive is empty',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      ru: 'Завершённые проекты будут отображаться здесь.',
                      en: 'Completed projects will appear here.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveList(List<ProjectModel> projects) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: 24,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];

        return _ArchivedProjectTile(
          project: project,
          index: index,
          onOpen: () {
            _openProject(project);
          },
          onChat: () {
            _openChat(project);
          },
          onRestore: () {
            _restoreProject(project);
          },
          onDelete: () {
            _deleteProject(project);
          },
        );
      },
    );
  }
}

// =========================================================
// ARCHIVED PROJECT TILE
// =========================================================

class _ArchivedProjectTile extends StatelessWidget {
  final ProjectModel project;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onChat;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchivedProjectTile({
    required this.project,
    required this.index,
    required this.onOpen,
    required this.onChat,
    required this.onRestore,
    required this.onDelete,
  });

  String _statusText(BuildContext context) {
    if (project.statusEnum == ProjectStatus.archived) {
      return context.locale.languageCode == 'ru'
          ? 'В архиве'
          : 'Archived';
    }

    return context.locale.languageCode == 'ru'
        ? 'Завершён'
        : 'Completed';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProjectProvider>();
    final theme = Theme.of(context);

    final canEdit = provider.canEditProject(project);
    final isOwner = provider.isOwner(project);
    final canRestore = provider.canRestoreProject(project);

    return Stack(
      children: [
        Opacity(
          opacity: 0.58,
          child: ProjectCard(
            project: project,
            unreadCount: project.unreadCount,
            canEdit: canEdit,
            isOwner: isOwner,
            searchQuery: provider.searchQuery,
            onEdit: (_) => onOpen(),
            onDelete: (_) => onDelete(),
            onChat: onChat,
          ),
        ),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: _StatusBadge(
                text: _statusText(context),
              ),
            ),
          ),
        ),
        if (canRestore)
          Positioned(
            right: 22,
            bottom: 16,
            child: FilledButton.tonalIcon(
              onPressed: onRestore,
              icon: const Icon(
                Icons.restore_outlined,
                size: 18,
              ),
              label: Text(
                context.locale.languageCode == 'ru'
                    ? 'Восстановить'
                    : 'Restore',
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelMedium,
              ),
            ),
          ),
      ],
    )
        .animate()
        .fadeIn(
      delay: (45 * index).ms,
    )
        .slideX(begin: 0.08);
  }
}

// =========================================================
// STATUS BADGE
// =========================================================

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.92,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}