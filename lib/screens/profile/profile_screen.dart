import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/profile_model.dart';
import '../../models/project_model.dart';

import '../../providers/project_provider.dart';

import '../../services/auth_service.dart';

import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';
import '../../utils/loading_overlay.dart';
import '../../utils/snackbar_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final AuthService _authService =
  AuthService();

  final _formKey = GlobalKey<FormState>();

  final _firstNameController =
  TextEditingController();

  final _lastNameController =
  TextEditingController();

  final _usernameController =
  TextEditingController();

  final _bioController =
  TextEditingController();

  ProfileModel? _profile;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  // =========================================================
  // LOAD PROFILE
  // =========================================================

  Future<void> _loadProfile() async {
    try {
      AppLogger.info('Loading profile');

      final profile =
      await _authService.getProfile();

      if (!mounted) return;

      if (profile == null) {
        throw Exception('Profile not found');
      }

      _firstNameController.text =
          profile.firstName;

      _lastNameController.text =
          profile.lastName;

      _usernameController.text =
          profile.username;

      _bioController.text =
          profile.bio ?? '';

      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error(
        'Profile load error',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // SAVE PROFILE
  // =========================================================

  Future<void> _saveProfile() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_profile == null) {
      return;
    }

    final firstName =
    _firstNameController.text.trim();

    final lastName =
    _lastNameController.text.trim();

    final username =
    _usernameController.text.trim();

    final bio =
    _bioController.text.trim();

    final fullName =
    '$firstName $lastName'.trim();

    try {
      setState(() {
        _saving = true;
      });

      LoadingOverlay.show();

      await _authService.updateProfile(
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
        username: username,
        bio: bio,
        avatarUrl: _profile!.avatarUrl,
      );

      if (!mounted) return;

      await context
          .read<ProjectProvider>()
          .setUser(
        _profile!.id,
        fullName,
      );

      setState(() {
        _profile = _profile!.copyWith(
          firstName: firstName,
          lastName: lastName,
          fullName: fullName,
          username: username,
          bio: bio,
          updatedAt: DateTime.now(),
        );
      });

      SnackbarManager.showSuccess(
        'profile.updated_success'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Save profile error',
        error: e,
        stackTrace: st,
      );

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      LoadingOverlay.hide();

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // =========================================================
  // STATISTICS
  // =========================================================

  Widget _buildStatistics() {
    final projects =
        context.watch<ProjectProvider>().projects;

    final totalProjects =
        projects.length;

    final completedProjects = projects
        .where(
          (p) =>
      p.statusEnum ==
          ProjectStatus.completed,
    )
        .length;

    final inProgressProjects = projects
        .where(
          (p) =>
      p.statusEnum ==
          ProjectStatus.inProgress,
    )
        .length;

    int totalTasks = 0;
    int completedTasks = 0;

    for (final project in projects) {
      totalTasks += project.totalTasks;
      completedTasks +=
          project.completedTasks;
    }

    final progress = totalTasks == 0
        ? 0.0
        : completedTasks / totalTasks;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'profile.statistics'.tr(),
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                title:
                'profile.total'.tr(),
                value:
                '$totalProjects',
                icon: Icons.folder,
                color:
                Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _StatCard(
                title: 'profile.in_progress'
                    .tr(),
                value:
                '$inProgressProjects',
                icon:
                Icons.timelapse,
                color: Colors.orange,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _StatCard(
                title:
                'profile.completed'
                    .tr(),
                value:
                '$completedProjects',
                icon:
                Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        ClipRRect(
          borderRadius:
          BorderRadius.circular(16),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'profile.tasks_summary'.tr(
            namedArgs: {
              'completed':
              completedTasks
                  .toString(),
              'total':
              totalTasks.toString(),
            },
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ROLE TEXT
  // =========================================================

  String _roleText(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'roles.student'.tr();

      case UserRole.teacher:
        return 'roles.teacher'.tr();

      case UserRole.general:
        return 'roles.general'.tr();
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'navigation.profile'.tr(),
          ),
        ),
        body: Center(
          child: Text(
            'profile.load_failed'.tr(),
          ),
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      appBar: AppBar(
        title:
        Text('navigation.profile'.tr()),
      ),
      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // =====================================================
              // HEADER
              // =====================================================

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    24,
                  ),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor:
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      backgroundImage:
                      profile.avatarUrl !=
                          null
                          ? NetworkImage(
                        profile
                            .avatarUrl!,
                      )
                          : null,
                      child: profile
                          .avatarUrl ==
                          null
                          ? const Icon(
                        Icons.person,
                        size: 52,
                      )
                          : null,
                    )
                        .animate()
                        .fadeIn()
                        .scale(),

                    const SizedBox(height: 16),

                    Text(
                      profile.fullName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                      textAlign:
                      TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '@${profile.username}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color:
                        Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Chip(
                      avatar: const Icon(
                        Icons.verified_user,
                        size: 18,
                      ),
                      label: Text(
                        _roleText(
                          profile.role,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      profile.email,
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.2),

              const SizedBox(height: 28),

              // =====================================================
              // STATISTICS
              // =====================================================

              _buildStatistics(),

              const SizedBox(height: 32),

              // =====================================================
              // FORM
              // =====================================================

              TextFormField(
                controller:
                _firstNameController,
                decoration:
                InputDecoration(
                  labelText:
                  'profile.first_name'
                      .tr(),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                  ),
                ),
                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty) {
                    return 'validation.empty_name'
                        .tr();
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller:
                _lastNameController,
                decoration:
                InputDecoration(
                  labelText:
                  'profile.last_name'
                      .tr(),
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller:
                _usernameController,
                decoration:
                InputDecoration(
                  labelText:
                  'profile.username'
                      .tr(),
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                  ),
                ),
                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty) {
                    return 'validation.empty_username'
                        .tr();
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                enabled: false,
                initialValue:
                profile.email,
                decoration:
                InputDecoration(
                  labelText:
                  'auth.email_label'
                      .tr(),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller:
                _bioController,
                maxLines: 4,
                decoration:
                InputDecoration(
                  labelText:
                  'profile.bio'.tr(),
                  alignLabelWithHint:
                  true,
                  prefixIcon: const Padding(
                    padding:
                    EdgeInsets.only(
                      bottom: 64,
                    ),
                    child: Icon(
                      Icons.description,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving
                      ? null
                      : _saveProfile,
                  icon: const Icon(
                    Icons.save,
                  ),
                  label: Text(
                    _saving
                        ? 'common.saving'
                        .tr()
                        : 'profile.save_changes'
                        .tr(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// STAT CARD
// =========================================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(20),
        color: color.withValues(
          alpha: 0.12,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
          ),

          const SizedBox(height: 10),

          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
              FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            title,
            textAlign:
            TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}