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
import '../../widgets/user_profile_drawer.dart';

import 'project_chat_screen.dart';
import 'project_form_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() =>
      _ProjectListScreenState();
}

class _ProjectListScreenState
    extends State<ProjectListScreen> {
  Stream<Map<String, int>>? _unreadStream;

  bool _isSearching = false;

  final TextEditingController _searchController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    final authProv =
    context.read<AuthProvider>();

    final chatProv =
    context.read<ChatProvider>();

    if (authProv.isGuest) {
      return;
    }

    try {
      final userId = authProv.userId;

      if (userId != null) {
        setState(() {
          _unreadStream =
              chatProv.getAllUnreadCounts(
                userId,
              );
        });
      }
    } catch (e, st) {
      AppLogger.error(
        'ProjectListScreen init error',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // CHAT
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
    final authProv =
    context.read<AuthProvider>();

    if (authProv.isGuest) {
      SnackbarManager.showWarning(
        'projects.guest_cannot_create'
            .tr(),
      );
      return;
    }

    final prov =
    context.read<ProjectProvider>();

    try {
      final newProject =
      prov.createEmptyProject();

      final created =
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectFormScreen(
            project: newProject,
            isNew: true,
          ),
        ),
      );

      if (!mounted) return;

      if (created == true) {
        SnackbarManager.showSuccess(
          'projects.created_success'
              .tr(),
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Add project error',
        error: e,
        stackTrace: st,
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
              builder: (context, setState) {
                return SingleChildScrollView(
                  controller: controller,
                  padding:
                  const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // =====================================
                      // FILTERS
                      // =====================================

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
                                ProjectFilter
                                    .all,
                            onSelected: (_) {
                              prov.setFilter(
                                ProjectFilter.all,
                              );

                              setState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'filter.in_progress'
                                  .tr(),
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

                              setState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'filter.completed'
                                  .tr(),
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

                              setState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // =====================================
                      // DEADLINE
                      // =====================================

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
                              'deadline_filter.all'
                                  .tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter
                                    .all,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter.all,
                              );

                              setState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'deadline_filter.today'
                                  .tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter
                                    .today,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter
                                    .today,
                              );

                              setState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'deadline_filter.week'
                                  .tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter
                                    .week,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter
                                    .week,
                              );

                              setState(() {});
                            },
                          ),

                          ChoiceChip(
                            label: Text(
                              'deadline_filter.overdue'
                                  .tr(),
                            ),
                            selected:
                            prov.deadlineFilter ==
                                DeadlineFilter
                                    .overdue,
                            onSelected: (_) {
                              prov.setDeadlineFilter(
                                DeadlineFilter
                                    .overdue,
                              );

                              setState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // =====================================
                      // SORTING
                      // =====================================

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
                                'sorting.nearest'
                                    .tr(),
                              ),
                              trailing:
                              prov.sortBy ==
                                  SortBy
                                      .deadlineAsc
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy
                                      .deadlineAsc,
                                );

                                Navigator.pop(
                                  context,
                                );
                              },
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.schedule_send,
                              ),
                              title: Text(
                                'sorting.farthest'
                                    .tr(),
                              ),
                              trailing:
                              prov.sortBy ==
                                  SortBy
                                      .deadlineDesc
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy
                                      .deadlineDesc,
                                );

                                Navigator.pop(
                                  context,
                                );
                              },
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.sort_by_alpha,
                              ),
                              title: Text(
                                'sorting.by_title'
                                    .tr(),
                              ),
                              trailing:
                              prov.sortBy ==
                                  SortBy
                                      .title
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy.title,
                                );

                                Navigator.pop(
                                  context,
                                );
                              },
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.flag,
                              ),
                              title: Text(
                                'sorting.by_status'
                                    .tr(),
                              ),
                              trailing:
                              prov.sortBy ==
                                  SortBy
                                      .status
                                  ? const Icon(
                                Icons.check,
                              )
                                  : null,
                              onTap: () {
                                prov.setSort(
                                  SortBy.status,
                                );

                                Navigator.pop(
                                  context,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // =====================================
                      // RESET
                      // =====================================

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            prov.resetFilters();

                            Navigator.pop(
                              context,
                            );
                          },
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label: Text(
                            'common.reset'
                                .tr(),
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
    final prov =
    context.watch<ProjectProvider>();

    final authProv =
    context.watch<AuthProvider>();

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
                Scaffold.of(context)
                    .openDrawer();
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
            key: const ValueKey(
              'search',
            ),
            controller:
            _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
              'search.hint'.tr(),
              border:
              InputBorder.none,
            ),
            onChanged: prov.search,
          )
              : Text(
            'navigation.my_projects'
                .tr(),
            key: const ValueKey(
              'title',
            ),
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

      body: prov.isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
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
            'projects.no_projects'
                .tr(),
          ),
        )
            : (_unreadStream == null
            ? _buildList(
          projects,
          authProv,
        )
            : StreamBuilder<
            Map<String, int>>(
          stream:
          _unreadStream,
          builder: (
              context,
              snapshot,
              ) {
            final unreadMap =
                snapshot.data ??
                    {};

            final totalUnread =
            unreadMap.values
                .fold(
              0,
                  (a, b) => a + b,
            );

            BadgeService.update(
              totalUnread,
            );

            return _buildList(
              projects,
              authProv,
            );
          },
        )),
      ),

      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
        onPressed: _addProject,
        child:
        const Icon(Icons.add),
      ),
    );
  }

  // =========================================================
  // LIST
  // =========================================================

  Widget _buildList(
      List<ProjectModel> projects,
      AuthProvider authProv,
      ) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        bottom: 80,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];

        final isOwner =
            project.ownerId ==
                authProv.userId;

        final canEdit = context
            .read<ProjectProvider>()
            .canEditProject(project);

        return ProjectCard(
          project: project,
          canEdit: canEdit,
          isOwner: isOwner,
          searchQuery: context
              .read<ProjectProvider>()
              .searchQuery,

          onEdit: (p) async {
            final updated =
            await Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (_) =>
                    ProjectFormScreen(
                      project: p,
                      isNew: false,
                    ),
              ),
            );

            if (!context.mounted) {
              return;
            }

            if (updated == true) {
              SnackbarManager.showSuccess(
                'common.updated'.tr(),
              );
            }
          },

          onDelete: (p) async {
            final prov = context
                .read<ProjectProvider>();

            await prov.deleteProject(
              p.id,
            );

            SnackbarManager.showSuccess(
              'projects.deleted_success'
                  .tr(),
            );
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