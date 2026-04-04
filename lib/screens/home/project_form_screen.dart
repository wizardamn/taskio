import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../services/supabase_service.dart';
import '../../models/project_model.dart';
import '../../providers/project_provider.dart';

import '../../utils/snackbar_manager.dart';
import '../../utils/error_mapper.dart';

import '../../widgets/project_form/color_picker_section.dart';
import '../../widgets/project_form/participants_section.dart';
import '../../widgets/project_form/attachments_section.dart';
import '../../widgets/participant_selection_dialog.dart';
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
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final SupabaseClient _supabase = SupabaseService.client;

  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  late String _color;

  List<String> _participants = [];
  List<Attachment> _attachments = [];

  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initFields();
    _loadUsers();
  }

  void _initFields() {
    _title = widget.project.title;
    _description = widget.project.description;
    _deadline = widget.project.deadline;
    _status = widget.project.statusEnum;
    _color = widget.project.color;
    _attachments = List.from(widget.project.attachments);

    final currentUserId = _supabase.auth.currentUser?.id ?? '';

    final ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : currentUserId;

    _participants = widget.project.participantIds.toSet().toList();

    if (!_participants.contains(ownerId) && ownerId.isNotEmpty) {
      _participants.add(ownerId);
    }
  }

  // =========================================================
  // LOAD USERS
  // =========================================================

  Future<void> _loadUsers() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name');

      if (!mounted) return;

      setState(() {
        _users = List<Map<String, dynamic>>.from(res);
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

  // =========================================================
  // PARTICIPANTS
  // =========================================================

  Future<void> _editParticipants() async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => ParticipantSelectionDialog(
        allUsers: _users,
        currentParticipantIds: _participants,
        ownerId: widget.project.ownerId,
      ),
    );

    if (selected != null) {
      setState(() => _participants = selected);
    }
  }

  List<String> _getParticipantNames() {
    return _users
        .where((u) => _participants.contains(u['id']))
        .map((u) => (u['full_name'] ?? 'Unknown').toString())
        .toList();
  }

  // =========================================================
  // ATTACHMENTS
  // =========================================================

  Future<void> _pickAttachment() async {
    if (widget.isNew) {
      SnackbarManager.showWarning(
          'projects.save_before_attachments'.tr());
      return;
    }

    final provider = context.read<ProjectProvider>();

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null) return;

    try {
      setState(() => _isUploading = true);

      final names = result.files.map((f) => f.name).toList();
      final files = kIsWeb
          ? null
          : result.files.map((f) => File(f.path!)).toList();
      final bytes = result.files.map((f) => f.bytes!).toList();

      final updatedProject = await provider.uploadAttachments(
        projectId: widget.project.id,
        fileNames: names,
        files: files,
        filesBytes: bytes,
      );

      setState(() {
        _attachments = List.from(updatedProject.attachments);
      });

      SnackbarManager.showSuccess('attachments.file_added'.tr());
    } catch (e) {
      SnackbarManager.showError(ErrorMapper.map(e).tr());
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteAttachment(Attachment att) async {
    final provider = context.read<ProjectProvider>();

    try {
      await provider.deleteAttachment(widget.project.id, att.filePath);

      setState(() {
        _attachments.removeWhere((a) => a.filePath == att.filePath);
      });

      SnackbarManager.showSuccess('attachments.delete_success'.tr());
    } catch (e) {
      SnackbarManager.showError(ErrorMapper.map(e).tr());
    }
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final provider = context.read<ProjectProvider>();
    final currentUserId = _supabase.auth.currentUser?.id;

    if (currentUserId == null) return;

    final project = ProjectModel(
      id: widget.project.id.isNotEmpty
          ? widget.project.id
          : _uuid.v4(),
      ownerId: widget.project.ownerId.isNotEmpty
          ? widget.project.ownerId
          : currentUserId,
      title: _title,
      description: _description,
      deadline: _deadline,
      status: _status.index,
      attachments: _attachments,
      participantIds: _participants,
      participantsData: const [],
      createdAt: widget.project.createdAt,
      color: _color,
    );

    try {
      if (widget.isNew) {
        await provider.addProject(project);
      } else {
        await provider.updateProject(project);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      SnackbarManager.showError(ErrorMapper.map(e).tr());
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUsers) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserId = _supabase.auth.currentUser?.id;

    final isOwner =
        widget.project.ownerId == currentUserId || widget.isNew;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew
            ? 'projects.new_project'.tr()
            : 'projects.project'.tr()),
        backgroundColor: Color(int.tryParse(_color) ?? 0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
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
              if (isOwner)
                ColorPickerSection(
                  selectedColor: _color,
                  onColorChanged: (c) =>
                      setState(() => _color = c),
                ),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(
                  labelText: 'projects.name'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                v == null || v.isEmpty
                    ? 'validation.enter_project_name'.tr()
                    : null,
                onSaved: (v) => _title = v!,
              ),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: _description,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'projects.description'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onSaved: (v) => _description = v ?? '',
              ),

              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('projects.deadline'.tr()),
                subtitle: Text(
                  DateFormat.yMd(context.locale.toString())
                      .format(_deadline),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );

                  if (picked != null) {
                    setState(() => _deadline = picked);
                  }
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<ProjectStatus>(
                value: _status,
                decoration: InputDecoration(
                  labelText: 'projects.status'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: ProjectStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.localizedText(context)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _status = val);
                  }
                },
              ),

              const SizedBox(height: 24),

              ParticipantsSection(
                participantNames: _getParticipantNames(),
                isOwner: isOwner,
                onEdit: _editParticipants,
              ),

              const SizedBox(height: 24),

              AttachmentsSection(
                attachments: _attachments,
                isUploading: _isUploading,
                currentlyOpeningFile: null,
                canEditContent: isOwner,
                isOwner: isOwner,
                onPick: _pickAttachment,
                onOpen: (_) {},
                onDelete: _deleteAttachment,
              ),

              const SizedBox(height: 24),

              if (!widget.isNew)
                ProjectTasksWidget(
                  projectId: widget.project.id,
                  canEdit: isOwner,
                ),
            ],
          ),
        ),
      ),
    );
  }
}