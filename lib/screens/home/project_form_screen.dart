import 'dart:io';

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

class _ProjectFormScreenState
    extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final SupabaseClient _supabase =
      SupabaseService.client;

  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  late String _color;

  late ProjectCategory _category;
  late int _maxMembers;
  late int _maxAttachments;
  late bool _gradingEnabled;

  List<String> _participants = [];
  List<Attachment> _attachments = [];
  List<Map<String, dynamic>> _users = [];

  bool _isLoadingUsers = true;
  bool _isUploading = false;
  bool _canEdit = false;

  String get _currentUserId =>
      _supabase.auth.currentUser?.id ?? '';

  bool get _isOwner {
    if (widget.isNew) return true;
    return widget.project.ownerId == _currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _initFields();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadUsers(),
      _resolvePermissions(),
    ]);
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
    _gradingEnabled = project.gradingEnabled;

    _attachments =
    List<Attachment>.from(project.attachments);

    final ownerId = project.ownerId.isNotEmpty
        ? project.ownerId
        : _currentUserId;

    _participants =
        project.participantIds.toSet().toList();

    if (ownerId.isNotEmpty &&
        !_participants.contains(ownerId)) {
      _participants.add(ownerId);
    }
  }

  Future<void> _resolvePermissions() async {
    if (widget.isNew) {
      _canEdit = true;

      if (mounted) {
        setState(() {});
      }

      return;
    }

    try {
      final provider =
      context.read<ProjectProvider>();

      _canEdit =
          provider.canEditProject(widget.project);
    } catch (_) {
      _canEdit = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUsers() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select(
        'id, full_name, username, avatar_url',
      );

      final users =
      List<Map<String, dynamic>>.from(res);

      users.sort((a, b) {
        final aName =
        (a['full_name'] ?? '')
            .toString()
            .toLowerCase();

        final bName =
        (b['full_name'] ?? '')
            .toString()
            .toLowerCase();

        return aName.compareTo(bName);
      });

      if (!mounted) return;

      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _users = [];
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _editParticipants() async {
    final ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : _currentUserId;

    final selected =
    await showDialog<List<String>>(
      context: context,
      builder: (_) => ParticipantSelectionDialog(
        allUsers: _users,
        currentParticipantIds: _participants,
        ownerId: ownerId,
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _participants =
          selected.toSet().toList();
    });
  }

  List<String> _getParticipantNames() {
    return _users
        .where(
          (u) => _participants.contains(u['id']),
    )
        .map(
          (u) =>
          (u['full_name'] ?? 'Unknown')
              .toString(),
    )
        .toList();
  }

  List<ProjectParticipant>
  _buildParticipantsData() {
    return _participants.map((id) {
      final user = _users.firstWhere(
            (u) => u['id'] == id,
        orElse: () => {},
      );

      return ProjectParticipant(
        id: id,
        fullName:
        user['full_name']?.toString() ??
            'Unknown',
        username:
        user['username']?.toString(),
        avatarUrl:
        user['avatar_url']?.toString(),
        role: id ==
            (widget.project.ownerId.isNotEmpty
                ? widget.project.ownerId
                : _currentUserId)
            ? ProjectRole.owner
            : ProjectRole.editor,
      );
    }).toList();
  }

  Future<void> _pickAttachment() async {
    if (widget.isNew) {
      SnackbarManager.showWarning(
        'projects.save_before_attachments'.tr(),
      );
      return;
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (!mounted || result == null) {
      return;
    }

    final provider = context.read<ProjectProvider>();

    try {
      setState(() {
        _isUploading = true;
      });

      final names =
      result.files.map((f) => f.name).toList();

      final files = kIsWeb
          ? null
          : result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();

      final bytes = result.files
          .where((f) => f.bytes != null)
          .map((f) => f.bytes!)
          .toList();

      final updatedProject =
      await provider.uploadAttachments(
        projectId: widget.project.id,
        fileNames: names,
        files: files,
        filesBytes: bytes,
      );

      if (updatedProject != null && mounted) {
        setState(() {
          _attachments = List<Attachment>.from(
            updatedProject.attachments,
          );
        });
      }

      SnackbarManager.showSuccess(
        'attachments.file_added'.tr(),
      );
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
      Attachment att) async {
    final provider =
    context.read<ProjectProvider>();

    try {
      await provider.deleteAttachment(
        projectId: widget.project.id,
        filePath: att.filePath,
      );

      if (!mounted) return;

      setState(() {
        _attachments.removeWhere(
              (a) => a.filePath == att.filePath,
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

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    final provider =
    context.read<ProjectProvider>();

    if (_currentUserId.isEmpty) {
      SnackbarManager.showError(
        'errors.not_authenticated'.tr(),
      );
      return;
    }

    final participantsData =
    _buildParticipantsData();

    final project = ProjectModel(
      id: widget.project.id,
      ownerId: widget.project.ownerId.isNotEmpty
          ? widget.project.ownerId
          : _currentUserId,
      title: _title,
      description: _description,
      deadline: _deadline,
      createdAt: widget.project.createdAt,
      status: _status.index,
      color: _color,
      category: _category,
      maxMembers: _maxMembers,
      maxAttachments: _maxAttachments,
      gradingEnabled: _gradingEnabled,
      participantsData: participantsData,
      attachments: _attachments,
      totalTasks: widget.project.totalTasks,
      completedTasks:
      widget.project.completedTasks,
      lastMessage: widget.project.lastMessage,
      lastMessageAt:
      widget.project.lastMessageAt,
      unreadCount: widget.project.unreadCount,
    );

    try {
      if (widget.isNew) {
        final created =
        await provider.addProject(project);

        if (created == null) {
          return;
        }
      } else {
        await provider.updateProject(project);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUsers) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
              icon: const Icon(Icons.check),
              onPressed: _saveProject,
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
                  onColorChanged: (c) {
                    setState(() {
                      _color = c;
                    });
                  },
                ),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: _title,
                enabled: _canEdit,
                decoration: InputDecoration(
                  labelText: 'projects.name'.tr(),
                  border:
                  const OutlineInputBorder(),
                ),
                validator: (v) {
                  // Проверка: поле пустое или содержит только пробелы
                  if (v == null || v.trim().isEmpty) {
                    // Возврат сообщения об ошибке валидации
                    return 'validation.enter_project_name'.tr();
                  }
                  // Ошибок нет — ввод корректный
                  return null;
                },
                onSaved: (v) {
                  _title = v!.trim();
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
                  border:
                  const OutlineInputBorder(),
                ),
                onSaved: (v) {
                  _description = v?.trim() ?? '';
                },
              ),

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
                onTap: _canEdit
                    ? () async {
                  final picked =
                  await showDatePicker(
                    context: context,
                    locale: context.locale,
                    initialDate: _deadline,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );

                  if (picked != null &&
                      mounted) {
                    setState(() {
                      _deadline = picked;
                    });
                  }
                }
                    : null,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<ProjectStatus>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText:
                  'projects.status'.tr(),
                  border:
                  const OutlineInputBorder(),
                ),
                items: ProjectStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.localizedText(),
                    ),
                  ),
                )
                    .toList(),
                onChanged: _canEdit
                    ? (val) {
                  if (val != null) {
                    setState(() {
                      _status = val;
                    });
                  }
                }
                    : null,
              ),

              const SizedBox(height: 24),

              ParticipantsSection(
                participantNames:
                _getParticipantNames(),
                isOwner: _isOwner,
                onEdit: () {
                  if (_canEdit) {
                    _editParticipants();
                  }
                },
              ),

              const SizedBox(height: 24),

              AttachmentsSection(
                attachments: _attachments,
                isUploading: _isUploading,
                currentlyOpeningFile: null,
                canEditContent: _canEdit,
                isOwner: _isOwner,
                onPick: _pickAttachment,
                onOpen: (_) {},
                onDelete: _deleteAttachment,
              ),

              const SizedBox(height: 24),

              if (!widget.isNew)
                ProjectTasksWidget(
                  projectId: widget.project.id,
                  canEdit: _canEdit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}