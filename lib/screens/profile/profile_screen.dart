import 'dart:io' show File;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile_model.dart';
import '../../models/project_model.dart';

import '../../providers/project_provider.dart';

import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';
import '../../utils/loading_overlay.dart';
import '../../utils/snackbar_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _avatarFolder = 'profiles';

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = SupabaseService.client;

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _firstNameController =
  TextEditingController();

  final TextEditingController _lastNameController =
  TextEditingController();

  final TextEditingController _usernameController =
  TextEditingController();

  final TextEditingController _bioController =
  TextEditingController();

  ProfileModel? _profile;
  UserRole? _selectedRole;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

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
      AppLogger.info(
        'Loading profile',
        tag: 'ProfileScreen',
      );

      final profile = await _authService.getProfile();

      if (!mounted) {
        return;
      }

      if (profile == null) {
        throw Exception('profile.load_error');
      }

      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _usernameController.text = profile.username;
      _bioController.text = profile.bio ?? '';

      setState(() {
        _profile = profile;
        _selectedRole = profile.role;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error(
        'Profile load error',
        error: e,
        stackTrace: st,
        tag: 'ProfileScreen',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // AVATAR
  // =========================================================

  Future<void> _pickAndUploadAvatar() async {
    if (_profile == null || _uploadingAvatar || _saving) {
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;

      setState(() {
        _uploadingAvatar = true;
      });

      final avatarUrl = await _uploadAvatarFile(file);

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = _profile!.copyWith(
          avatarUrl: avatarUrl,
          updatedAt: DateTime.now(),
        );
      });

      try {
        await context.read<ProjectProvider>().fetchProjects();
      } catch (e, st) {
        AppLogger.error(
          'Projects refresh after avatar upload failed',
          error: e,
          stackTrace: st,
          tag: 'ProfileScreen',
        );
      }

      SnackbarManager.showSuccess(
        'profile.avatar_updated'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Avatar upload error',
        error: e,
        stackTrace: st,
        tag: 'ProfileScreen',
      );

      if (mounted) {
        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  Future<String> _uploadAvatarFile(
      PlatformFile file,
      ) async {
    final profile = _profile;

    if (profile == null) {
      throw Exception('profile.load_error');
    }

    final userId = profile.id;
    final extension = _safeExtension(file.name);

    final path =
        '$_avatarFolder/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final contentType = _mimeTypeFromExtension(extension);

    await _uploadAvatarToStorage(
      path: path,
      file: file,
      contentType: contentType,
    );

    final avatarUrl = _supabase.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(path);

    await _authService.updateProfile(
      fullName: profile.fullName,
      firstName: profile.firstName,
      lastName: profile.lastName,
      username: profile.username,
      bio: profile.bio,
      avatarUrl: avatarUrl,
      role: _selectedRole ?? profile.role,
      language: profile.language,
    );

    try {
      await _supabase.from('profiles').update({
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e, st) {
      AppLogger.error(
        'Direct avatar_url update skipped',
        error: e,
        stackTrace: st,
        tag: 'ProfileScreen',
      );
    }

    return avatarUrl;
  }

  Future<void> _uploadAvatarToStorage({
    required String path,
    required PlatformFile file,
    required String contentType,
  }) async {
    if (kIsWeb) {
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('errors.invalid_files_bytes');
      }

      await _supabase.storage
          .from(SupabaseService.bucket)
          .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
        ),
      );

      return;
    }

    final filePath = file.path;

    if (filePath == null || filePath.isEmpty) {
      throw Exception('errors.invalid_files');
    }

    await _supabase.storage
        .from(SupabaseService.bucket)
        .upload(
      path,
      File(filePath),
      fileOptions: FileOptions(
        upsert: true,
        contentType: contentType,
      ),
    );
  }

  String? _normalizeAvatarUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();

    final oldAvatarBucketMarker =
        '/storage/v1/object/public/avatars/';

    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      if (raw.contains(oldAvatarBucketMarker)) {
        return raw.replaceFirst(
          oldAvatarBucketMarker,
          '/storage/v1/object/public/${SupabaseService.bucket}/',
        );
      }

      return raw;
    }

    var path = raw.replaceAll('\\', '/');

    while (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (path.startsWith('avatars/')) {
      path = path.substring('avatars/'.length);
    }

    if (path.startsWith('${SupabaseService.bucket}/')) {
      path = path.substring(
        '${SupabaseService.bucket}/'.length,
      );
    }

    return _supabase.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(path);
  }

  String _safeExtension(String fileName) {
    final clean = fileName.trim();

    if (!clean.contains('.')) {
      return 'jpg';
    }

    final ext = clean.split('.').last.toLowerCase();

    final safe = ext.replaceAll(
      RegExp(r'[^a-zA-Z0-9]+'),
      '',
    );

    if (safe.isEmpty) {
      return 'jpg';
    }

    return safe;
  }

  String _mimeTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'gif':
        return 'image/gif';

      case 'webp':
        return 'image/webp';

      default:
        return 'image/jpeg';
    }
  }

  // =========================================================
  // SAVE PROFILE
  // =========================================================

  Future<void> _saveProfile() async {
    if (_saving) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    final profile = _profile;

    if (profile == null) {
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    final username = _normalizeUsername(
      _usernameController.text,
    );

    final bio = _bioController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final role = _selectedRole ?? profile.role;

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
        avatarUrl: profile.avatarUrl,
        role: role,
        language: profile.language,
      );

      if (!mounted) {
        return;
      }

      await context.read<ProjectProvider>().setUser(
        profile.id,
        fullName.isNotEmpty ? fullName : username,
      );

      setState(() {
        _profile = profile.copyWith(
          firstName: firstName,
          lastName: lastName,
          fullName: fullName,
          username: username,
          bio: bio,
          role: role,
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
        tag: 'ProfileScreen',
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

  String _normalizeUsername(String value) {
    final username = value.trim();

    if (username.startsWith('@')) {
      return username.substring(1);
    }

    return username;
  }

  // =========================================================
  // STATISTICS
  // =========================================================

  Widget _buildStatistics() {
    final projects =
        context.watch<ProjectProvider>().projects;

    final totalProjects = projects.length;

    final completedProjects = projects
        .where(
          (project) =>
      project.statusEnum == ProjectStatus.completed,
    )
        .length;

    final inProgressProjects = projects
        .where(
          (project) =>
      project.statusEnum == ProjectStatus.inProgress,
    )
        .length;

    int totalTasks = 0;
    int completedTasks = 0;

    for (final project in projects) {
      totalTasks += project.totalTasks;
      completedTasks += project.completedTasks;
    }

    final progress = totalTasks == 0
        ? 0.0
        : completedTasks / totalTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'profile.statistics'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'profile.total'.tr(),
                value: '$totalProjects',
                icon: Icons.folder,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _StatCard(
                title: 'profile.in_progress'.tr(),
                value: '$inProgressProjects',
                icon: Icons.timelapse,
                color: Colors.orange,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _StatCard(
                title: 'profile.completed'.tr(),
                value: '$completedProjects',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '${'profile.tasks_summary'.tr()}: '
              '$completedTasks / $totalTasks',
        ),
      ],
    );
  }

  // =========================================================
  // ROLE
  // =========================================================

  String _roleText(UserRole role) {
    return role.localizedText();
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<UserRole>(
      initialValue: _selectedRole,
      decoration: InputDecoration(
        labelText: 'profile.role'.tr(),
        prefixIcon: const Icon(
          Icons.verified_user_outlined,
        ),
        border: const OutlineInputBorder(),
      ),
      items: UserRole.values.map((role) {
        return DropdownMenuItem<UserRole>(
          value: role,
          child: Text(
            _roleText(role),
          ),
        );
      }).toList(),
      onChanged: _saving || _uploadingAvatar
          ? null
          : (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedRole = value;
        });
      },
    );
  }

  // =========================================================
  // AVATAR UI
  // =========================================================

  Widget _buildAvatar(ProfileModel profile) {
    final theme = Theme.of(context);
    final avatarUrl = _normalizeAvatarUrl(profile.avatarUrl);

    final fallbackIcon = Icon(
      Icons.person,
      size: 52,
      color: theme.colorScheme.onPrimaryContainer,
    );

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl == null
              ? Center(
            child: fallbackIcon,
          )
              : Image.network(
            avatarUrl,
            key: ValueKey(avatarUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Center(
                child: fallbackIcon,
              );
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }

              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        )
            .animate()
            .fadeIn()
            .scale(),

        Positioned(
          right: 0,
          bottom: 0,
          child: Tooltip(
            message: 'profile.change_avatar'.tr(),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _uploadingAvatar || _saving
                  ? null
                  : _pickAndUploadAvatar,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary,
                child: _uploadingAvatar
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
                    : Icon(
                  Icons.photo_camera,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
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
            'profile.load_error'.tr(),
          ),
        ),
      );
    }

    final profile = _profile!;
    final emailText = profile.email.trim().isEmpty
        ? 'auth.email_not_provided'.tr()
        : profile.email.trim();

    final usernameText = profile.username.trim().isEmpty
        ? ''
        : '@${profile.username.trim()}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'navigation.profile'.tr(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: Column(
                  children: [
                    _buildAvatar(profile),

                    const SizedBox(height: 16),

                    Text(
                      profile.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (usernameText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        usernameText,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Chip(
                      avatar: const Icon(
                        Icons.verified_user,
                        size: 18,
                      ),
                      label: Text(
                        _roleText(
                          _selectedRole ?? profile.role,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SelectableText(
                      emailText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.2),

              const SizedBox(height: 28),

              _buildStatistics(),

              const SizedBox(height: 32),

              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'profile.first_name'.tr(),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'validation.empty_name'.tr();
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'profile.last_name'.tr(),
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'profile.username'.tr(),
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'validation.empty_field'.tr();
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                enabled: false,
                initialValue: emailText,
                decoration: InputDecoration(
                  labelText: 'auth.email_label'.tr(),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              _buildRoleDropdown(),

              const SizedBox(height: 16),

              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'profile.bio'.tr(),
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(
                      bottom: 64,
                    ),
                    child: Icon(
                      Icons.description,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving || _uploadingAvatar
                      ? null
                      : _saveProfile,
                  icon: const Icon(
                    Icons.save,
                  ),
                  label: Text(
                    _saving
                        ? 'common.saving'.tr()
                        : 'profile.save_changes'.tr(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}