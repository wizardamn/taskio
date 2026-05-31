import 'dart:io' show File;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/error_mapper.dart';
import '../../utils/snackbar_manager.dart';
import '../../widgets/participant_selection_dialog.dart';
import '../../widgets/project_form/attachments_section.dart';
import '../../widgets/project_form/color_picker_section.dart';
import '../../widgets/project_form/grade_section.dart';
import '../../widgets/project_form/participants_section.dart';
import '../../widgets/project_tasks_widget.dart';

class ProjectFormScreen extends StatefulWidget {
  final ProjectModel project;
  final bool isNew;

  const ProjectFormScreen({
    super.key,
    required this.project,
    required this.isNew,
  });

  @override
  State<ProjectFormScreen> createState() =>
      _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final SupabaseClient _supabase = SupabaseService.client;

  final TextEditingController _draftTaskController =
  TextEditingController();

  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  late String _color;

  late ProjectCategory _category;
  late int _maxMembers;
  late int _maxAttachments;
  late bool _gradingEnabled;

  List<ProjectParticipant> _participantsData = [];
  List<Attachment> _attachments = [];
  List<Map<String, dynamic>> _users = [];

  final List<String> _draftTasks = [];

  bool _isLoadingUsers = true;
  bool _isUploading = false;
  bool _isSaving = false;

  bool _canEdit = false;
  bool _canManageContent = false;

  String get _currentUserId {
    return _supabase.auth.currentUser?.id ?? '';
  }

  String get _ownerId {
    if (widget.project.ownerId.isNotEmpty) {
      return widget.project.ownerId;
    }

    return _currentUserId;
  }

  bool get _isOwner {
    if (widget.isNew) {
      return true;
    }

    return widget.project.ownerId == _currentUserId;
  }

  bool get _canEditParticipants {
    return _canEdit && _isOwner;
  }

  bool get _isEducationalProject {
    return _category == ProjectCategory.educational;
  }

  bool get _showGradeSection {
    return !widget.isNew &&
        _isEducationalProject &&
        _gradingEnabled;
  }

  @override
  void initState() {
    super.initState();

    _initFields();
    _markAsCurrentProject();
    _initializeScreen();
  }

  @override
  void dispose() {
    _draftTaskController.dispose();
    super.dispose();
  }

  // =========================================================
  // INIT
  // =========================================================

  void _markAsCurrentProject() {
    if (widget.project.id.trim().isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<ProjectProvider>().setCurrentProject(
        widget.project.id,
      );
    });
  }

  void _initFields() {
    final project = widget.project;

    _title = project.title;
    _description = project.description;
    _deadline = project.deadline;
    _status = project.statusEnum;
    _color = project.color;

    _category = project.category;
    _maxMembers = project.maxMembers;
    _maxAttachments = project.maxAttachments;

    _gradingEnabled = _category == ProjectCategory.educational
        ? project.gradingEnabled
        : false;

    _attachments = List<Attachment>.from(
      project.attachments,
    );

    _participantsData = List<ProjectParticipant>.from(
      project.participantsData,
    );

    _ensureOwnerParticipant();

    if (widget.isNew) {
      _status = ProjectStatus.inProgress;
    }
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadUsers(),
      _resolvePermissions(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _participantsData = _normalizeParticipants(
        _participantsData,
      );
      _isLoadingUsers = false;
    });
  }

  Future<void> _resolvePermissions() async {
    if (widget.isNew) {
      _canEdit = true;
      _canManageContent = true;
      return;
    }

    try {
      final provider = context.read<ProjectProvider>();

      _canEdit = provider.canEditProject(
        widget.project,
      );

      _canManageContent = provider.canManageProjectContent(
        widget.project,
      );
    } catch (_) {
      _canEdit = false;
      _canManageContent = false;
    }
  }

  Future<void> _loadUsers() async {
    try {
      final provider = context.read<ProjectProvider>();

      final users = await provider.getUsersForSelection();

      if (!mounted) {
        return;
      }

      _users = users;
    } catch (_) {
      _users = [];
    }
  }

  // =========================================================
  // PARTICIPANTS
  // =========================================================

  Future<void> _editParticipants() async {
    if (!_canEditParticipants) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    final selected = await showDialog<List<ProjectParticipant>>(
      context: context,
      builder: (_) => ParticipantSelectionDialog(
        allUsers: _users,
        currentParticipantIds: _participantsData
            .map((participant) => participant.id)
            .toList(),
        currentParticipants: _participantsData,
        ownerId: _ownerId,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _participantsData = _normalizeParticipants(
        selected,
      );
    });
  }

  List<ProjectParticipant> _buildParticipantsData() {
    return _normalizeParticipants(
      _participantsData,
    );
  }

  List<ProjectParticipant> _normalizeParticipants(
      List<ProjectParticipant> source,
      ) {
    final map = <String, ProjectParticipant>{};

    for (final participant in source) {
      final id = participant.id.trim();

      if (id.isEmpty) {
        continue;
      }

      final user = _findUserById(id);

      map[id] = ProjectParticipant(
        id: id,
        fullName: _displayNameByUserOrParticipant(
          user,
          participant,
        ),
        username: _usernameByUserOrParticipant(
          user,
          participant,
        ),
        avatarUrl: _avatarByUserOrParticipant(
          user,
          participant,
        ),
        role: id == _ownerId
            ? ProjectRole.owner
            : _safeParticipantRole(
          participant.role,
        ),
      );
    }

    if (_ownerId.isNotEmpty) {
      final user = _findUserById(_ownerId);

      map[_ownerId] = ProjectParticipant(
        id: _ownerId,
        fullName: _displayNameByUserOrParticipant(
          user,
          map[_ownerId],
          fallback: 'project.owner'.tr(),
        ),
        username: _usernameByUserOrParticipant(
          user,
          map[_ownerId],
        ),
        avatarUrl: _avatarByUserOrParticipant(
          user,
          map[_ownerId],
        ),
        role: ProjectRole.owner,
      );
    }

    final list = map.values.toList();

    list.sort((a, b) {
      if (a.id == _ownerId) {
        return -1;
      }

      if (b.id == _ownerId) {
        return 1;
      }

      return a.fullName
          .toLowerCase()
          .compareTo(b.fullName.toLowerCase());
    });

    return list;
  }

  void _ensureOwnerParticipant() {
    if (_ownerId.isEmpty) {
      return;
    }

    final hasOwner = _participantsData.any(
          (participant) => participant.id == _ownerId,
    );

    if (hasOwner) {
      _participantsData = _participantsData.map((participant) {
        if (participant.id == _ownerId) {
          return ProjectParticipant(
            id: participant.id,
            fullName: participant.fullName,
            username: participant.username,
            avatarUrl: participant.avatarUrl,
            role: ProjectRole.owner,
          );
        }

        return participant;
      }).toList();

      return;
    }

    _participantsData.add(
      ProjectParticipant(
        id: _ownerId,
        fullName: 'project.owner'.tr(),
        role: ProjectRole.owner,
      ),
    );
  }

  ProjectRole _safeParticipantRole(ProjectRole role) {
    if (role == ProjectRole.owner) {
      return ProjectRole.editor;
    }

    return role;
  }

  Map<String, dynamic>? _findUserById(String id) {
    for (final user in _users) {
      if (user['id']?.toString() == id) {
        return user;
      }
    }

    return null;
  }

  String _displayNameByUserOrParticipant(
      Map<String, dynamic>? user,
      ProjectParticipant? participant, {
        String? fallback,
      }) {
    if (user != null) {
      final fullName = user['full_name']?.toString().trim();

      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }

      final firstName =
          user['first_name']?.toString().trim() ?? '';
      final lastName =
          user['last_name']?.toString().trim() ?? '';

      final combined = '$firstName $lastName'.trim();

      if (combined.isNotEmpty) {
        return combined;
      }

      final username = user['username']?.toString().trim();

      if (username != null && username.isNotEmpty) {
        return username.startsWith('@')
            ? username
            : '@$username';
      }
    }

    final participantName =
        participant?.fullName.trim() ?? '';

    if (participantName.isNotEmpty) {
      return participantName;
    }

    return fallback ?? 'users.no_name'.tr();
  }

  String? _usernameByUserOrParticipant(
      Map<String, dynamic>? user,
      ProjectParticipant? participant,
      ) {
    final userUsername =
    user?['username']?.toString().trim();

    if (userUsername != null && userUsername.isNotEmpty) {
      return userUsername.startsWith('@')
          ? userUsername.substring(1)
          : userUsername;
    }

    final participantUsername =
    participant?.username?.trim();

    if (participantUsername != null &&
        participantUsername.isNotEmpty) {
      return participantUsername.startsWith('@')
          ? participantUsername.substring(1)
          : participantUsername;
    }

    return null;
  }

  String? _avatarByUserOrParticipant(
      Map<String, dynamic>? user,
      ProjectParticipant? participant,
      ) {
    final userAvatar =
    user?['avatar_url']?.toString().trim();

    if (userAvatar != null && userAvatar.isNotEmpty) {
      return userAvatar;
    }

    final participantAvatar =
    participant?.avatarUrl?.trim();

    if (participantAvatar != null &&
        participantAvatar.isNotEmpty) {
      return participantAvatar;
    }

    return null;
  }

  // =========================================================
  // CATEGORY
  // =========================================================

  String _categoryText(ProjectCategory category) {
    switch (category) {
      case ProjectCategory.educational:
        return 'project_category.educational'.tr();

      case ProjectCategory.creative:
        return 'project_category.creative'.tr();
    }
  }

  void _onCategoryChanged(ProjectCategory category) {
    setState(() {
      _category = category;

      if (category == ProjectCategory.educational) {
        _gradingEnabled = true;

        if (_maxMembers < 2) {
          _maxMembers = 30;
        }

        if (_maxAttachments < 1) {
          _maxAttachments = 20;
        }
      } else {
        _gradingEnabled = false;

        if (_maxMembers < 2) {
          _maxMembers = 10;
        }

        if (_maxAttachments < 1) {
          _maxAttachments = 10;
        }
      }
    });
  }

  // =========================================================
  // DRAFT TASKS
  // =========================================================

  void _addDraftTask() {
    final text = _draftTaskController.text.trim();

    if (text.isEmpty) {
      SnackbarManager.showWarning(
        'tasks.empty_title'.tr(),
      );
      return;
    }

    if (_draftTasks.contains(text)) {
      _draftTaskController.clear();
      return;
    }

    setState(() {
      _draftTasks.add(text);
      _draftTaskController.clear();
    });
  }

  void _removeDraftTask(int index) {
    if (index < 0 || index >= _draftTasks.length) {
      return;
    }

    setState(() {
      _draftTasks.removeAt(index);
    });
  }

  Future<void> _saveDraftTasks(String projectId) async {
    if (_draftTasks.isEmpty) {
      return;
    }

    final rows = _draftTasks.map((title) {
      return {
        'project_id': projectId,
        'title': title,
        'is_completed': false,
        'created_at': DateTime.now()
            .toUtc()
            .toIso8601String(),
      };
    }).toList();

    await _supabase.from('project_tasks').insert(rows);
  }

  Widget _buildDraftTasksSection() {
    if (!widget.isNew) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'projects.tasks_on_create'.tr(),
              style:
              Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draftTaskController,
                    enabled: _canEdit,
                    textInputAction:
                    TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'tasks.hint'.tr(),
                      border:
                      const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addDraftTask(),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton.filled(
                  tooltip: 'common.add'.tr(),
                  onPressed:
                  _canEdit ? _addDraftTask : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_draftTasks.isEmpty)
              Text(
                'projects.no_draft_tasks'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount: _draftTasks.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1),
                itemBuilder: (context, index) {
                  final task = _draftTasks[index];

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                    ),
                    title: Text(task),
                    trailing: IconButton(
                      tooltip: 'common.delete'.tr(),
                      icon: const Icon(Icons.close),
                      onPressed: _canEdit
                          ? () => _removeDraftTask(index)
                          : null,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Future<void> _pickAttachment() async {
    if (widget.isNew) {
      SnackbarManager.showWarning(
        'projects.save_before_attachments'.tr(),
      );
      return;
    }

    if (!_canManageContent) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    context.read<ProjectProvider>().setCurrentProject(
      widget.project.id,
    );

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (!mounted || result == null) {
      return;
    }

    final totalAfterUpload =
        _attachments.length + result.files.length;

    if (_maxAttachments > 0 &&
        totalAfterUpload > _maxAttachments) {
      SnackbarManager.showError(
        'projects.max_attachments_error'.tr(),
      );
      return;
    }

    final provider = context.read<ProjectProvider>();

    try {
      setState(() {
        _isUploading = true;
      });

      final names =
      result.files.map((file) => file.name).toList();

      final files = kIsWeb
          ? null
          : result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      final bytes = kIsWeb
          ? result.files
          .where((file) => file.bytes != null)
          .map((file) => file.bytes!)
          .toList()
          : null;

      final updatedProject =
      await provider.uploadAttachments(
        projectId: widget.project.id,
        fileNames: names,
        files: files,
        filesBytes: bytes,
      );

      if (updatedProject != null && mounted) {
        provider.setCurrentProject(updatedProject.id);

        setState(() {
          _attachments = List<Attachment>.from(
            updatedProject.attachments,
          );
        });

        SnackbarManager.showSuccess(
          'attachments.file_added'.tr(),
        );
      }
    } catch (e) {
      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteAttachment(
      Attachment attachment,
      ) async {
    if (!_canManageContent) {
      SnackbarManager.showError(
        'errors.no_permission'.tr(),
      );
      return;
    }

    final provider = context.read<ProjectProvider>();

    try {
      provider.setCurrentProject(widget.project.id);

      await provider.deleteAttachment(
        projectId: widget.project.id,
        filePath: attachment.filePath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _attachments.removeWhere(
              (item) => item.filePath == attachment.filePath,
        );
      });

      SnackbarManager.showSuccess(
        'attachments.delete_success'.tr(),
      );
    } catch (e) {
      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _saveProject() async {
    if (_isSaving) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    form.save();

    if (_currentUserId.isEmpty) {
      SnackbarManager.showError(
        'errors.not_authenticated'.tr(),
      );
      return;
    }

    final provider = context.read<ProjectProvider>();

    final participantsData = _buildParticipantsData();

    if (_maxMembers > 0 &&
        participantsData.length > _maxMembers) {
      SnackbarManager.showError(
        'projects.max_members_error'.tr(),
      );
      return;
    }

    final effectiveGradingEnabled =
    _category == ProjectCategory.educational
        ? _gradingEnabled
        : false;

    final project = ProjectModel(
      id: widget.project.id,
      ownerId:
      _ownerId.isNotEmpty ? _ownerId : _currentUserId,
      title: _title,
      description: _description,
      deadline: _deadline,
      createdAt: widget.project.createdAt,
      status: _status.index,
      color: _color,
      category: _category,
      maxMembers: _maxMembers,
      maxAttachments: _maxAttachments,
      gradingEnabled: effectiveGradingEnabled,
      participantsData: participantsData,
      attachments: _attachments,
      totalTasks: widget.project.totalTasks,
      completedTasks: widget.project.completedTasks,
      lastMessage: widget.project.lastMessage,
      lastMessageAt: widget.project.lastMessageAt,
      unreadCount: widget.project.unreadCount,
    );

    try {
      setState(() {
        _isSaving = true;
      });

      if (widget.isNew) {
        final created =
        await provider.addProject(project);

        if (created == null) {
          return;
        }

        provider.setCurrentProject(created.id);

        await _saveDraftTasks(created.id);

        await provider.refreshProject(
          created.id,
          makeCurrent: true,
        );
      } else {
        provider.setCurrentProject(project.id);

        await provider.updateProject(project);

        await provider.refreshProject(
          project.id,
          makeCurrent: true,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
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
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // UI HELPERS
  // =========================================================

  Color _parseColor(String color) {
    try {
      final value = color.startsWith('0x')
          ? int.parse(color)
          : int.parse('0xFF$color');

      return Color(value);
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  Future<void> _pickDeadline() async {
    if (!_canEdit) {
      return;
    }

    final picked = await showDatePicker(
      context: context,
      locale: context.locale,
      initialDate: _deadline,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _deadline = picked;
    });
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<ProjectCategory>(
      initialValue: _category,
      decoration: InputDecoration(
        labelText: 'projects.category'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: ProjectCategory.values.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(
            _categoryText(category),
          ),
        );
      }).toList(),
      onChanged: _canEdit
          ? (value) {
        if (value != null) {
          _onCategoryChanged(value);
        }
      }
          : null,
    );
  }

  Widget _buildLimitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isEducationalProject) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'projects.grading_enabled'.tr(),
                ),
                subtitle: Text(
                  'projects.grading_enabled_hint'.tr(),
                ),
                value: _gradingEnabled,
                onChanged: _canEdit
                    ? (value) {
                  setState(() {
                    _gradingEnabled = value;
                  });
                }
                    : null,
              ),

              const SizedBox(height: 12),
            ],

            TextFormField(
              key: ValueKey(
                'max_members_$_maxMembers',
              ),
              initialValue: _maxMembers.toString(),
              enabled: _canEdit,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'projects.max_members'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed =
                int.tryParse(value ?? '');

                if (parsed == null || parsed < 1) {
                  return 'validation.empty_field'.tr();
                }

                return null;
              },
              onSaved: (value) {
                _maxMembers =
                    int.tryParse(value ?? '') ??
                        _maxMembers;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              key: ValueKey(
                'max_attachments_$_maxAttachments',
              ),
              initialValue: _maxAttachments.toString(),
              enabled: _canEdit,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'projects.max_attachments'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed =
                int.tryParse(value ?? '');

                if (parsed == null || parsed < 0) {
                  return 'validation.empty_field'.tr();
                }

                return null;
              },
              onSaved: (value) {
                _maxAttachments =
                    int.tryParse(value ?? '') ??
                        _maxAttachments;
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUsers) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final canGradeProject = context
        .read<ProjectProvider>()
        .canGradeProject(widget.project);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? 'projects.new_project'.tr()
              : 'projects.project'.tr(),
        ),
        backgroundColor: _parseColor(_color),
        foregroundColor: Colors.white,
        actions: [
          if (_canEdit)
            IconButton(
              tooltip: 'common.save'.tr(),
              icon: _isSaving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check),
              onPressed:
              _isSaving ? null : _saveProject,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_canEdit)
                ColorPickerSection(
                  selectedColor: _color,
                  onColorChanged: (color) {
                    setState(() {
                      _color = color;
                    });
                  },
                ),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: _title,
                enabled: _canEdit,
                decoration: InputDecoration(
                  labelText: 'projects.name'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'validation.enter_project_name'
                        .tr();
                  }

                  return null;
                },
                onSaved: (value) {
                  _title = value?.trim() ?? '';
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: _description,
                enabled: _canEdit,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                  'projects.description'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onSaved: (value) {
                  _description = value?.trim() ?? '';
                },
              ),

              const SizedBox(height: 16),

              _buildCategoryDropdown(),

              const SizedBox(height: 16),

              _buildLimitsSection(),

              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'projects.deadline'.tr(),
                ),
                subtitle: Text(
                  DateFormat.yMd(
                    context.locale.toString(),
                  ).format(_deadline),
                ),
                trailing:
                const Icon(Icons.calendar_today),
                onTap:
                _canEdit ? _pickDeadline : null,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<ProjectStatus>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'projects.status'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: ProjectStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      status.localizedText(),
                    ),
                  );
                }).toList(),
                onChanged: _canEdit
                    ? (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                }
                    : null,
              ),

              const SizedBox(height: 24),

              ParticipantsSection(
                participants: _buildParticipantsData(),
                isOwner: _canEditParticipants,
                onEdit: _editParticipants,
              ),

              const SizedBox(height: 24),

              _buildDraftTasksSection(),

              const SizedBox(height: 24),

              AttachmentsSection(
                attachments: _attachments,
                isUploading: _isUploading,
                currentlyOpeningFile: null,
                canEditContent: _canManageContent,
                isOwner: _isOwner,
                onPick: _pickAttachment,
                onOpen: (_) {},
                onDelete: _deleteAttachment,
              ),

              const SizedBox(height: 24),

              if (!widget.isNew)
                ProjectTasksWidget(
                  projectId: widget.project.id,
                  canEdit: _canManageContent,
                ),

              if (_showGradeSection) ...[
                const SizedBox(height: 24),
                GradeSection(
                  projectId: widget.project.id,
                  canEdit: canGradeProject,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}