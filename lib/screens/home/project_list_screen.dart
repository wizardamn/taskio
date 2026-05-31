import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/project_provider.dart';

import '../../services/badge_service.dart';

import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';
import '../../utils/snackbar_manager.dart';

import '../../widgets/project_card.dart';
import '../../widgets/project_list_skeleton.dart';
import '../../widgets/user_profile_drawer.dart';

import 'project_chat_screen.dart';
import 'project_form_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({
    super.key,
  });

  @override
  State<ProjectListScreen> createState() =>
      _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  Stream<Map<String, int>>? _unreadStream;

  String? _unreadUserId;
  bool _isUnreadSyncScheduled = false;
  bool _isSearching = false;

  final TextEditingController _searchController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final authProv = context.read<AuthProvider>();
      _syncUnreadStream(authProv);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // UNREAD
  // =========================================================

  void _syncUnreadStream(AuthProvider authProv) {
    final requestedUserId = authProv.isGuest
        ? null
        : authProv.userId;

    if (_unreadUserId == requestedUserId) {
      return;
    }

    if (_isUnreadSyncScheduled) {
      return;
    }

    _isUnreadSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUnreadSyncScheduled = false;

      if (!mounted) {
        return;
      }

      final currentAuth = context.read<AuthProvider>();

      final currentUserId = currentAuth.isGuest
          ? null
          : currentAuth.userId;

      if (_unreadUserId == currentUserId) {
        return;
      }

      if (currentUserId == null || currentUserId.isEmpty) {
        setState(() {
          _unreadUserId = null;
          _unreadStream = null;
        });

        BadgeService.update(0);
        return;
      }

      try {
        final chatProv = context.read<ChatProvider>();

        final stream = chatProv.getAllUnreadCounts(
          currentUserId,
        );

        setState(() {
          _unreadUserId = currentUserId;
          _unreadStream = stream;
        });
      } catch (e, st) {
        AppLogger.error(
          'Unread stream init error',
          error: e,
          stackTrace: st,
          tag: 'ProjectListScreen',
        );
      }
    });
  }

  void _updateBadgeSafely(int totalUnread) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      BadgeService.update(totalUnread);
    });
  }

  // =========================================================
  // NAVIGATION
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

    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(
          project: project,
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

      if (!mounted) {
        return;
      }

      if (created == true) {
        await prov.fetchProjects();

        final currentProject = prov.currentProject;

        if (currentProject != null) {
          prov.setCurrentProject(currentProject.id);
        }

        SnackbarManager.showSuccess(
          'projects.created_success'.tr(),
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Add project error',
        error: e,
        stackTrace: st,
        tag: 'ProjectListScreen',
      );

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // FILTER MENU
  // =========================================================

  Future<void> _openFilterMenu(
      BuildContext context,
      ProjectProvider prov,
      ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'filter.title'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),

                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(
                              'filter.all'.tr(),
                            ),
                            selected:
                            prov.filter ==
                                ProjectFilter.all,
                            onSelected: (_) {
                              prov.setFilter(
                                ProjectFilter.all,
                              );

                              setModalState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'filter.in_progress'.tr(),
                            ),
                            selected:
                            prov.filter ==
                                ProjectFilter
                                    .inProgressOnly,
                            onSelected: (_) {
                              prov.setFilter(
                                ProjectFilter
                                    .inProgressOnly,
                              );

                              setModalState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'filter.completed'.tr(),
                            ),
                            selected:
                            prov.filter ==
                                ProjectFilter
                                    .completedOnly,
                            onSelected: (_) {
                              prov.setFilter(
                                ProjectFilter
                                    .completedOnly,
                              );

                              setModalState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'projects.deadline'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(
                              'deadline_filter.all'.tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter.all,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter.all,
                              );

                              setModalState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'deadline_filter.today'.tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter.today,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter.today,
                              );

                              setModalState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'deadline_filter.week'.tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter.week,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter.week,
                              );

                              setModalState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'deadline_filter.overdue'.tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter.overdue,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter.overdue,
                              );

                              setModalState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'sorting.title'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),

                      const SizedBox(height: 12),

                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.schedule,
                              ),
                              title: Text(
                                'sorting.nearest'.tr(),
                              ),
                              trailing:
                              prov.sortBy ==
                                  SortBy.deadlineAsc
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy.deadlineAsc,
                                );

                                Navigator.pop(context);
                              },
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.schedule_send,
                              ),
                              title: Text(
                                'sorting.farthest'.tr(),
                              ),
                              trailing:
                              prov.sortBy ==
                                  SortBy.deadlineDesc
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy.deadlineDesc,
                                );

                                Navigator.pop(context);
                              },
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.sort_by_alpha,
                              ),
                              title: Text(
                                'sorting.by_title'.tr(),
                              ),
                              trailing:
                              prov.sortBy == SortBy.title
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy.title,
                                );

                                Navigator.pop(context);
                              },
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.flag,
                              ),
                              title: Text(
                                'sorting.by_status'.tr(),
                              ),
                              trailing:
                              prov.sortBy == SortBy.status
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy.status,
                                );

                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            prov.resetFilters();
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label: Text(
                            'common.reset'.tr(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final authProv = context.watch<AuthProvider>();

    _syncUnreadStream(authProv);

    final projects = prov.projects;
    final isGuest = authProv.isGuest;

    return Scaffold(
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            setState(() {
              _isSearching = false;
            });

            _searchController.clear();
            prov.search('');
          },
        )
            : Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),

        title: AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 250,
          ),
          child: _isSearching
              ? TextField(
            key: const ValueKey('search'),
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'search.hint'.tr(),
              border: InputBorder.none,
            ),
            onChanged: prov.search,
          )
              : Text(
            'navigation.my_projects'.tr(),
            key: const ValueKey('title'),
          ),
        ),

        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(
                Icons.search,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),

          if (!_isSearching)
            IconButton(
              icon: const Icon(
                Icons.filter_alt,
              ),
              onPressed: () {
                _openFilterMenu(
                  context,
                  prov,
                );
              },
            ),
        ],
      ),

      drawer: const UserProfileDrawer(),

      body: prov.isLoading && projects.isEmpty
          ? const ProjectListSkeleton()
          : RefreshIndicator(
        onRefresh: () async {
          if (!isGuest) {
            await prov.fetchProjects();
          }
        },
        child: projects.isEmpty
            ? _buildEmptyState()
            : _buildProjectsBody(
          projects,
          authProv,
        ),
      ),

      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
        tooltip: 'projects.create'.tr(),
        onPressed: _addProject,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Text(
              'projects.no_projects'.tr(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectsBody(
      List<ProjectModel> projects,
      AuthProvider authProv,
      ) {
    if (_unreadStream == null) {
      _updateBadgeSafely(0);

      return _buildList(
        projects,
        authProv,
        const {},
      );
    }

    return StreamBuilder<Map<String, int>>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final unreadMap =
            snapshot.data ?? const <String, int>{};

        final totalUnread = unreadMap.values.fold<int>(
          0,
              (sum, value) => sum + value,
        );

        _updateBadgeSafely(totalUnread);

        return _buildList(
          projects,
          authProv,
          unreadMap,
        );
      },
    );
  }

  // =========================================================
  // LIST
  // =========================================================

  Widget _buildList(
      List<ProjectModel> projects,
      AuthProvider authProv,
      Map<String, int> unreadMap,
      ) {
    final provider = context.read<ProjectProvider>();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: 80,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];

        final isOwner =
            project.ownerId == authProv.userId;

        final canOpen =
        provider.canOpenProject(project);

        final canEdit =
        provider.canEditProject(project);

        final unreadCount =
            unreadMap[project.id] ?? 0;

        if (!canOpen) {
          return const SizedBox.shrink();
        }

        return ProjectCard(
          project: project,
          unreadCount: unreadCount,
          canEdit: canEdit,
          isOwner: isOwner,
          searchQuery: provider.searchQuery,
          onEdit: _openProject,
          onDelete: (p) async {
            provider.setCurrentProject(p.id);

            if (!provider.isOwner(p)) {
              SnackbarManager.showError(
                'errors.no_permission'.tr(),
              );
              return;
            }

            try {
              await provider.deleteProject(p.id);

              if (!context.mounted) {
                return;
              }

              SnackbarManager.showSuccess(
                'projects.deleted_success'.tr(),
              );
            } catch (e) {
              if (!context.mounted) {
                return;
              }

              SnackbarManager.showError(
                ErrorMapper.map(e),
              );
            }
          },
          onChat: () => _openChat(project),
        )
            .animate()
            .fadeIn(
          delay: (40 * index).ms,
        )
            .slideX(begin: 0.1);
      },
    );
  }
}