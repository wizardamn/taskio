import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/auth_service.dart';
import '../../providers/project_provider.dart';
import '../../models/profile_model.dart';
import '../../models/project_model.dart';

import '../../utils/snackbar_manager.dart';
import '../../utils/loading_overlay.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';

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
  final _nameController =
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
    _nameController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOAD PROFILE
  // =========================================================

  Future<void> _loadProfile() async {
    try {
      AppLogger.info(
          'Loading profile');

      final profile =
      await _authService.getProfile();

      if (!mounted) return;

      if (profile == null) {
        throw Exception(
            'Profile not found');
      }

      setState(() {
        _profile = profile;
        _nameController.text =
            profile.fullName;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error(
          'Profile load error',
          e);
      AppLogger.error(
          'StackTrace', st);

      if (mounted) {
        setState(
                () => _loading = false);
        SnackbarManager.showError(
            ErrorMapper.map(e));
      }
    }
  }

  // =========================================================
  // SAVE PROFILE
  // =========================================================

  Future<void> _saveProfile() async {
    if (_saving ||
        !_formKey.currentState!.validate() ||
        _profile == null) {
      return;
    }

    final newName =
    _nameController.text.trim();

    if (newName ==
        _profile!.fullName) {
      SnackbarManager.showInfo(
          'profile.no_changes'.tr());
      return;
    }

    try {
      setState(() => _saving = true);
      LoadingOverlay.show();

      await _authService
          .updateFullName(newName);

      if (!mounted) return;

      await context
          .read<ProjectProvider>()
          .setUser(
          _profile!.id,
          newName);

      SnackbarManager.showSuccess(
          'profile.updated_success'
              .tr());

      setState(() {
        _profile = _profile!
            .copyWith(
            fullName: newName);
      });
    } catch (e, st) {
      AppLogger.error(
          'Profile save error',
          e);
      AppLogger.error(
          'StackTrace', st);

      SnackbarManager.showError(
          ErrorMapper.map(e));
    } finally {
      if (mounted) {
        setState(
                () => _saving = false);
      }
      LoadingOverlay.hide();
    }
  }

  // =========================================================
  // STATISTICS
  // =========================================================

  Widget _buildStatistics() {
    final projects =
        context.watch<ProjectProvider>().view;

    final total =
        projects.length;

    final completed = projects
        .where((p) =>
    p.statusEnum ==
        ProjectStatus.completed)
        .length;

    final inProgress = projects
        .where((p) =>
    p.statusEnum ==
        ProjectStatus.inProgress)
        .length;

    int totalTasks = 0;
    int completedTasks = 0;

    for (final p in projects) {
      totalTasks += p.totalTasks;
      completedTasks +=
          p.completedTasks;
    }

    final progress =
    totalTasks == 0
        ? 0.0
        : completedTasks /
        totalTasks;

    final colorScheme =
        Theme.of(context).colorScheme;

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
                value: '$total',
                color:
                colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title:
                'profile.in_progress'.tr(),
                value: '$inProgress',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title:
                'profile.completed'
                    .tr(),
                value: '$completed',
                color: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
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
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms)
        .slideY(begin: 0.2);
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
            CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(
                'navigation.profile'
                    .tr())),
        body: Center(
          child: Text(
              'profile.load_failed'
                  .tr()),
        ),
      );
    }

    final roleDisplay =
    'roles.${_profile!.role}'.tr();

    return Scaffold(
      appBar: AppBar(
        title:
        Text('navigation.profile'.tr()),
      ),
      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 12),

              CircleAvatar(
                radius: 45,
                child: const Icon(
                    Icons.person,
                    size: 50),
              ).animate().slideY(),

              const SizedBox(height: 30),

              _buildStatistics(),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              TextFormField(
                controller:
                _nameController,
                decoration:
                InputDecoration(
                  labelText:
                  'profile.full_name'
                      .tr(),
                ),
                validator: (v) =>
                v == null ||
                    v.isEmpty
                    ? 'validation.empty_name'
                    .tr()
                    : null,
              ),

              const SizedBox(height: 12),

              TextFormField(
                enabled: false,
                initialValue:
                _profile!.email,
                decoration:
                InputDecoration(
                  labelText:
                  'auth.email_label'
                      .tr(),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                enabled: false,
                initialValue:
                roleDisplay,
                decoration:
                InputDecoration(
                  labelText:
                  'profile.role'
                      .tr(),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : _saveProfile,
                icon:
                const Icon(Icons.save),
                label: Text(
                    'profile.save_changes'
                        .tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
        color.withValues(alpha: 0.1),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style:
            const TextStyle(fontSize: 12),
            textAlign:
            TextAlign.center,
          ),
        ],
      ),
    );
  }
}