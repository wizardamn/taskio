import 'package:universal_io/io.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../services/notification_service.dart';

import '../../utils/file_opener_utils.dart';
import '../../widgets/project_form_widgets.dart';
import '../../widgets/participant_selection_dialog.dart';
import '../../widgets/project_tasks_widget.dart';
import 'project_chat_screen.dart';

import '../../widgets/project_form/color_picker_section.dart';
import '../../widgets/project_form/participants_section.dart';
import '../../widgets/project_form/attachments_section.dart';

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
  final SupabaseClient _supabase = SupabaseService.client;
  final Uuid _uuid = const Uuid();

  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  late String _color;
  double? _grade;

  // Локальный список вложений. Он отображает то, что есть в проекте сейчас.
  List<Attachment> _attachments = [];

  late List<String> _participants;
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;
  bool _isUploading = false;
  String? _currentlyOpeningFile;

  @override
  void initState() {
    super.initState();
    _title = widget.project.title;
    _description = widget.project.description;
    _deadline = widget.project.deadline;
    _status = widget.project.statusEnum;
    _grade = widget.project.grade;
    _color = widget.project.color;

    // ВАЖНО: Инициализируем список вложений данными из проекта при открытии
    _attachments = List.from(widget.project.attachments);

    final String currentUserId = _supabase.auth.currentUser?.id ?? '';
    final String ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : currentUserId;

    _participants = widget.project.participantIds.toSet().toList();
    if (ownerId.isNotEmpty && !_participants.contains(ownerId)) {
      _participants.add(ownerId);
    }

    _loadUsers();
  }

  // --- Загрузка пользователей ---
  Future<void> _loadUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) setState(() { _users = []; _isLoadingUsers = false; });
        return;
      }
      final res = await _supabase.from('profiles').select('id, full_name').neq('id', currentUserId);
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(res); _isLoadingUsers = false; });
    } catch (e) {
      if (mounted) setState(() { _users = []; _isLoadingUsers = false; });
    }
  }

  String _getUserName(String userId) {
    final user = _users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null) return user['full_name'] as String? ?? 'Без имени';

    final participantData = widget.project.participantsData.firstWhereOrNull((pd) => pd.id == userId);
    if (participantData != null) return participantData.fullName;

    return userId == _supabase.auth.currentUser?.id ? 'Я (Владелец)' : 'Неизвестный';
  }

  void _openChat() {
    if (widget.isNew && widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала сохраните проект.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectChatScreen(
      projectId: widget.project.id,
      projectTitle: _title,
      participants: widget.project.participantsData,
    )));
  }

  Future<void> _selectParticipants() async {
    final currentUser = _supabase.auth.currentUser;
    if (widget.project.ownerId != currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Только владелец может менять участников.')));
      return;
    }

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => ParticipantSelectionDialog(
        allUsers: _users,
        currentParticipantIds: _participants,
        ownerId: widget.project.ownerId.isNotEmpty ? widget.project.ownerId : currentUser?.id ?? '',
      ),
    );
    if (result != null && mounted) {
      setState(() => _participants = result);
    }
  }

  // --- ЗАГРУЗКА ВЛОЖЕНИЙ ---
  Future<void> _pickAttachment() async {
    final prov = context.read<ProjectProvider>();

    // Проверка: проект должен быть создан
    if (widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала сохраните проект (введите название и нажмите галочку).')));
      return;
    }

    if (!prov.canEditProject(widget.project)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет прав на добавление файлов.')));
      return;
    }

    // Множественный выбор файлов
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'mp3', 'mp4', 'zip', 'rar'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _isUploading = true);

    try {
      final List<String> names = result.files.map((f) => f.name).toList();
      final List<File>? files = kIsWeb ? null : result.files.map((f) => File(f.path!)).toList();
      final List<Uint8List>? bytes = result.files.map((f) => f.bytes!).toList();

      // Загружаем через провайдер (он обновляет БД)
      final updatedProject = await prov.uploadAttachments(
          projectId: widget.project.id,
          fileNames: names,
          files: files,
          filesBytes: bytes
      );

      if (mounted) {
        setState(() {
          // Обновляем локальный список, чтобы файлы появились на экране сразу
          _attachments = List.from(updatedProject.attachments);
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файлы успешно загружены')));
      }
    } catch(e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
    }
  }

  // --- ОТКРЫТИЕ ФАЙЛА ---
  Future<void> _handleOpenAttachment(Attachment attachment) async {
    if (kIsWeb) {
      final url = _supabase.storage.from(SupabaseService.bucket).getPublicUrl(attachment.filePath);
      await launchUrl(Uri.parse(url));
      return;
    }
    if (_currentlyOpeningFile == attachment.filePath) return;

    setState(() => _currentlyOpeningFile = attachment.filePath);
    await FileOpenerUtils.downloadAndOpen(attachment.filePath, attachment.fileName);
    if (mounted) setState(() => _currentlyOpeningFile = null);
  }

  // --- УДАЛЕНИЕ ФАЙЛА ---
  Future<void> _deleteAttachment(Attachment att) async {
    final prov = context.read<ProjectProvider>();
    if (widget.project.ownerId != _supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Только владелец может удалять файлы.')));
      return;
    }

    try {
      await prov.deleteAttachment(widget.project.id, att.filePath);
      if (mounted) {
        setState(() {
          // Удаляем локально для мгновенного обновления
          _attachments.removeWhere((a) => a.filePath == att.filePath);
          _attachments = List.from(_attachments);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вложение удалено')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final prov = context.read<ProjectProvider>();
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final project = ProjectModel(
      id: widget.project.id.isNotEmpty ? widget.project.id : _uuid.v4(),
      title: _title,
      description: _description,
      ownerId: widget.project.ownerId.isNotEmpty ? widget.project.ownerId : currentUserId,
      deadline: _deadline,
      status: _status.index,
      grade: _grade,
      attachments: _attachments, // Сохраняем текущий список вложений
      participantsData: const [],
      participantIds: _participants.toSet().toList(),
      createdAt: widget.project.createdAt,
      color: _color,
    );

    try {
      if (widget.isNew) {
        await prov.addProject(project);
      } else {
        await prov.updateProject(project);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final isOwner = widget.project.ownerId == _supabase.auth.currentUser?.id;
    final canEditContent = isOwner || prov.canEditProject(widget.project);

    if (_isLoadingUsers) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? "Новый проект" : "Проект"),
        backgroundColor: Color(int.parse(_color)),
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isNew) IconButton(icon: const Icon(Icons.chat), onPressed: _openChat),
          if (isOwner) IconButton(icon: const Icon(Icons.check), onPressed: _saveProject),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOwner)
                ColorPickerSection(
                    selectedColor: _color,
                    onColorChanged: (c) => setState(() => _color = c)
                ),

              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: "Название", prefixIcon: Icon(Icons.title), border: OutlineInputBorder()),
                enabled: isOwner,
                validator: (v) => v?.isEmpty ?? true ? "Введите название" : null,
                onSaved: (v) => _title = v!,
              ).animate().fadeIn(),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Описание", prefixIcon: Icon(Icons.description), border: OutlineInputBorder()),
                enabled: isOwner,
                onSaved: (v) => _description = v ?? '',
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: DatePickerField(
                    label: 'Дедлайн',
                    initialDate: _deadline,
                    onChanged: isOwner ? (d) => setState(() => _deadline = d!) : null,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: DropdownButtonFormField<ProjectStatus>(
                    value: _status,
                    items: ProjectStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.text))).toList(),
                    onChanged: isOwner ? (v) => setState(() => _status = v!) : null,
                    decoration: const InputDecoration(labelText: "Статус", border: OutlineInputBorder()),
                  )),
                ],
              ).animate().fadeIn(delay: 200.ms),

              if (!widget.isNew) ...[
                const Divider(height: 40),
                ProjectTasksWidget(projectId: widget.project.id, canEdit: canEditContent),
              ],

              const SizedBox(height: 16),
              if (_status == ProjectStatus.completed)
                TextFormField(
                  initialValue: _grade?.toInt().toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Оценка", prefixIcon: Icon(Icons.grade), border: OutlineInputBorder()),
                  enabled: isOwner,
                  onSaved: (v) => _grade = double.tryParse(v ?? ''),
                ),

              const Divider(height: 40),
              ParticipantsSection(
                participantNames: _participants.toSet().map((id) => _getUserName(id)).toList(),
                isOwner: isOwner,
                onEdit: _selectParticipants,
              ),

              const Divider(height: 40),
              AttachmentsSection(
                attachments: _attachments, // Передаем обновляемый список
                isUploading: _isUploading,
                currentlyOpeningFile: _currentlyOpeningFile,
                canEditContent: canEditContent,
                isOwner: isOwner,
                onPick: _pickAttachment,
                onOpen: _handleOpenAttachment,
                onDelete: _deleteAttachment,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}