import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/project_model.dart';

import '../../utils/snackbar_manager.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';

import 'project_form_screen.dart';
import 'project_chat_screen.dart';

import '../../widgets/user_profile_drawer.dart';
import '../../widgets/project_card.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProv = context.read<AuthProvider>();

      if (!authProv.isGuest) {
        await context.read<ProjectProvider>().fetchProjects();
      }
    });
  }

  // =========================================================
  // OPEN CHAT
  // =========================================================

  void _openChat(ProjectModel project) {
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
  // ADD PROJECT
  // =========================================================

  Future<void> _addProject() async {
    final authProv = context.read<AuthProvider>();

    if (authProv.isGuest) {
      SnackbarManager.showWarning(
        'projects.guest_cannot_create'.tr(),
      );
      return;
    }

    final prov = context.read<ProjectProvider>();

    try {
      final newProject = prov.createEmptyProject();

      final created = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectFormScreen(
            project: newProject,
            isNew: true,
          ),
        ),
      );

      if (created == true && mounted) {
        await prov.fetchProjects();

        SnackbarManager.showSuccess(
          'projects.created_success'.tr(),
        );
      }
    } catch (e, st) {
      AppLogger.error('Add project error', e);
      AppLogger.error('StackTrace', st);

      SnackbarManager.showError(
        ErrorMapper.map(e).tr(),
      );
    }
  }

  // =========================================================
  // DELETE PROJECT
  // =========================================================

  Future<void> _confirmDelete(
      ProjectProvider prov,
      ProjectModel project,
      ) async {
    final authProv = context.read<AuthProvider>();

    if (project.ownerId != authProv.userId) {
      SnackbarManager.showWarning(
        'projects.operation_denied_guest'.tr(),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('projects.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await prov.deleteProject(project.id);

        SnackbarManager.showSuccess(
          'projects.deleted_success'.tr(),
        );
      } catch (e) {
        SnackbarManager.showError(
          ErrorMapper.map(e).tr(),
        );
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final authProv = context.watch<AuthProvider>();

    final projects = prov.view;
    final isGuest = authProv.isGuest;

    return Scaffold(
      appBar: AppBar(
        title: Text('navigation.my_projects'.tr()),
      ),
      drawer: const UserProfileDrawer(),

      body: prov.isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: () async {
          if (!isGuest) {
            await prov.fetchProjects();
          }
        },
        child: projects.isEmpty
            ? Center(
          child: Text(
            isGuest
                ? 'projects.login_to_view'.tr()
                : 'projects.no_projects'.tr(),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];

            return ProjectCard(
              project: project,

              canEdit: prov.canEditProject(project),
              isOwner: project.ownerId == authProv.userId,

              /// EDIT
              onEdit: (project) async {
                final updated =
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectFormScreen(
                      project: project,
                      isNew: false,
                    ),
                  ),
                );

                if (updated == true && mounted) {
                  await prov.fetchProjects();

                  SnackbarManager.showSuccess(
                    'common.updated'.tr(),
                  );
                }
              },

              /// DELETE
              onDelete: (project) =>
                  _confirmDelete(prov, project),

              /// 🔥 CHAT
              onChat: () => _openChat(project),
            )
                .animate()
                .fadeIn(
              duration: 250.ms,
              delay: (40 * index).ms,
            )
                .slideX(begin: 0.1);
          },
        ),
      ),

      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
        onPressed: _addProject,
        child: const Icon(Icons.add),
      ),
    );
  }
}