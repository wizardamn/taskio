import 'package:universal_io/io.dart'; // Support for both Web and Mobile File
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for web file opening

// --- PROJECT IMPORTS ---
import '../../services/supabase_service.dart';
import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../services/notification_service.dart';

// --- NEW IMPORTS ---
import '../../utils/file_opener_utils.dart';
import '../../widgets/project_form_widgets.dart';
import '../../widgets/participant_selection_dialog.dart';
import '../../widgets/project_tasks_widget.dart'; // Task Widget
import 'project_chat_screen.dart'; // Chat Screen

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

  // Form State
  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  late String _color; // Project Color
  double? _grade;
  List<Attachment> _attachments = [];

  // Participants
  late List<String> _participants;
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;

  // Files
  bool _isUploading = false;
  String? _currentlyOpeningFile;

  // Color Palette
  final List<Color> _availableColors = const [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _title = widget.project.title;
    _description = widget.project.description;
    _deadline = widget.project.deadline;
    _status = widget.project.statusEnum;
    _grade = widget.project.grade;
    _color = widget.project.color; // Initialize color
    _attachments = List.from(widget.project.attachments);

    // Initialize participants
    final Set<String> participantSet = widget.project.participantIds.toSet();
    final String currentUserId = _supabase.auth.currentUser?.id ?? '';
    final String ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : currentUserId;

    if (ownerId.isNotEmpty) {
      participantSet.add(ownerId);
    }
    _participants = participantSet.toList();

    _loadUsers();
  }

  void _openChat() {
    // Chat is unavailable if project is new and not saved
    if (widget.isNew && widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала сохраните проект, чтобы использовать чат.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectChatScreen(
          projectId: widget.project.id,
          projectTitle: _title,
          participants: widget.project.participantsData,
        ),
      ),
    );
  }

  // --- Load Users ---
  Future<void> _loadUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        if (!mounted) return;
        setState(() {
          _users = [];
          _isLoadingUsers = false;
        });
        return;
      }

      final res = await _supabase.from('profiles')
          .select('id, full_name')
          .neq('id', currentUserId);

      if (!mounted) return;

      setState(() {
        _users = List<Map<String, dynamic>>.from(res);
        _isLoadingUsers = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _isLoadingUsers = false;
        });
        debugPrint("Ошибка загрузки пользователей: $e");
      }
    }
  }

  // --- Get User Name by ID ---
  String _getUserName(String userId) {
    final user = _users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null) {
      return user['full_name'] as String? ?? 'Без имени';
    }
    final participantData = widget.project.participantsData.firstWhereOrNull((pd) => pd.id == userId);
    if (participantData != null) {
      return participantData.fullName;
    }
    if (userId == _supabase.auth.currentUser?.id) {
      return 'Я (Владелец)';
    }
    return 'Неизвестный';
  }

  // --- Select Participants ---
  Future<void> _selectParticipants() async {
    final currentUser = _supabase.auth.currentUser;

    if (widget.project.ownerId != currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только владелец проекта может изменять список участников.')),
      );
      return;
    }

    if (_users.isEmpty && _isLoadingUsers) return;

    final ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : currentUser?.id ?? '';

    final List<String>? result = await showDialog(
      context: context,
      builder: (ctx) => ParticipantSelectionDialog(
        allUsers: _users,
        currentParticipantIds: _participants,
        ownerId: ownerId,
      ),
    );

    if (result != null && mounted) {
      setState(() => _participants = result);
    }
  }

  // --- Pick Attachment ---
  Future<void> _pickAttachment() async {
    if (widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала сохраните проект')));
      return;
    }

    final prov = context.read<ProjectProvider>();
    if (!prov.canEditProject(widget.project)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет прав на добавление файлов.')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'mp3', 'mp4', 'zip', 'rar'],
      withData: kIsWeb, // Important for Web support
    );

    // Check for null result or missing data
    if (result == null || (kIsWeb ? result.files.single.bytes == null : result.files.single.path == null) || !mounted) return;

    setState(() => _isUploading = true);

    try {
      final fileName = result.files.single.name;
      ProjectModel updatedProject;

      if (kIsWeb) {
        // Web: Pass bytes
        updatedProject = await prov.uploadAttachment(
            widget.project.id,
            File(''), // Dummy file for type safety in method signature if needed, but provider handles bytes
            fileBytes: result.files.single.bytes,
            fileName: fileName
        );
      } else {
        // Mobile: Pass file path
        final file = File(result.files.single.path!);
        updatedProject = await prov.uploadAttachment(
            widget.project.id,
            file,
            fileName: fileName
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файл успешно загружен')));
      setState(() => _attachments = updatedProject.attachments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- Open Attachment ---
  Future<void> _handleOpenAttachment(Attachment attachment) async {
    if (_currentlyOpeningFile == attachment.filePath) return;

    // Web handling
    if (kIsWeb) {
      final url = _supabase.storage.from(SupabaseService.bucket).getPublicUrl(attachment.filePath);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
      }
      return;
    }

    setState(() => _currentlyOpeningFile = attachment.filePath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Открытие: ${attachment.fileName}')));

    final error = await FileOpenerUtils.downloadAndOpen(attachment.filePath, attachment.fileName);

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Файл ${attachment.fileName} открыт.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }

    setState(() => _currentlyOpeningFile = null);
  }

  // --- Delete Attachment ---
  Future<void> _deleteAttachment(Attachment attachment) async {
    final prov = context.read<ProjectProvider>();

    // CHECK: Only Owner can delete files
    if (widget.project.ownerId != _supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Только владелец может удалять файлы.')));
      return;
    }

    try {
      await prov.deleteAttachment(widget.project.id, attachment.filePath);

      await NotificationService().showSimple(
        'Файл удалён',
        'Файл "${attachment.fileName}" удален из проекта.',
      );

      if (mounted) {
        setState(() => _attachments.removeWhere((a) => a.filePath == attachment.filePath));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вложение удалено')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
      }
    }
  }

  // --- Save Project ---
  Future<void> _saveProject() async {
    final prov = context.read<ProjectProvider>();

    if (widget.project.ownerId != _supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Только владелец может сохранять изменения.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final projectId = widget.project.id.isNotEmpty ? widget.project.id : _uuid.v4();
    final ownerId = widget.project.ownerId.isNotEmpty ? widget.project.ownerId : currentUserId;

    final projectModel = ProjectModel(
      id: projectId,
      title: _title,
      description: _description,
      ownerId: ownerId,
      deadline: _deadline,
      status: _status.index,
      grade: _grade,
      attachments: _attachments,
      participantsData: const [],
      participantIds: _participants.toSet().toList(),
      createdAt: widget.project.createdAt.isBefore(DateTime(2000)) ? DateTime.now() : widget.project.createdAt,
      color: _color, // Save Color
    );

    try {
      if (widget.isNew) {
        final saved = await prov.addProject(projectModel);
        if (saved != null) {
          await NotificationService().showSimple('Проект создан', 'Проект "${saved.title}" успешно создан.');
        }
      } else {
        await prov.updateProject(projectModel);
        await NotificationService().showSimple('Проект обновлён', 'Проект "${projectModel.title}" был обновлён.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isNew ? 'Создано' : 'Обновлено')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uniqueParticipantIds = _participants.toSet().toList();
    final participantNames = uniqueParticipantIds
        .map((id) => _getUserName(id))
        .toList();

    final prov = context.watch<ProjectProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // ACCESS RIGHTS
    final currentUserId = _supabase.auth.currentUser?.id;
    final isOwner = widget.project.ownerId == currentUserId;
    // Editor can add files and tasks, but not change project fields
    final canEditContent = isOwner || prov.canEditProject(widget.project);

    if (_isLoadingUsers) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isNew ? "Создание" : "Загрузка...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? "Новый проект" : "Проект"),
        backgroundColor: Color(int.parse(_color)), // AppBar Color matches Project Color
        foregroundColor: Colors.white, // Ensure text is visible
        actions: [
          // Chat (only if project is created)
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Открыть чат',
              onPressed: _openChat,
            ),

          // Save (Only Owner)
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProject,
              tooltip: 'Сохранить',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COLOR SELECTION (Only Owner)
              if (isOwner) ...[
                Text("Цвет проекта", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final color = _availableColors[index];
                      final colorString = '0x${color.value.toRadixString(16).toUpperCase()}';
                      final isSelected = _color == colorString;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _color = colorString;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 40 : 32,
                          height: isSelected ? 40 : 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: colorScheme.onSurface, width: 2) : null,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Title
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: "Название проекта",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v?.isEmpty ?? true ? "Введите название" : null,
                onSaved: (v) => _title = v!,
                enabled: isOwner, // Strict permission
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                initialValue: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Описание",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                onSaved: (v) => _description = v ?? '',
                enabled: isOwner,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 16),

              // Deadline & Status
              Row(
                children: [
                  Expanded(
                    child: DatePickerField(
                      label: 'Дедлайн',
                      initialDate: _deadline,
                      // Editable by Owner only
                      onChanged: isOwner ? (d) => setState(() => _deadline = d) : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<ProjectStatus>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: "Статус",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      items: ProjectStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.text))).toList(),
                      // Editable by Owner only
                      onChanged: isOwner ? (v) => setState(() => _status = v!) : null,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),

              // --- TASKS ---
              if (!widget.isNew)
                Column(
                  children: [
                    const Divider(height: 30),
                    ProjectTasksWidget(
                      projectId: widget.project.id,
                      canEdit: canEditContent, // Editable by Owner AND Editors
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Grade
              if (_status == ProjectStatus.completed)
                TextFormField(
                  initialValue: _grade?.toInt().toString() ?? '',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Оценка (0-100)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grade),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = int.tryParse(v);
                    if (n == null || n < 0 || n > 100) return "0-100";
                    return null;
                  },
                  onSaved: (v) {
                    final parsed = int.tryParse(v ?? '');
                    _grade = parsed?.toDouble();
                  },
                  enabled: isOwner,
                ).animate().fadeIn(),

              const Divider(height: 30),

              // Participants
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text("Участники команды"),
                subtitle: Text(participantNames.isEmpty ? "Никто не выбран" : participantNames.join(', ')),
                trailing: isOwner
                    ? ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Изменить"),
                  onPressed: _selectParticipants,
                )
                    : null,
              ).animate().fadeIn(delay: 300.ms),

              const Divider(height: 30),

              // Attachments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Вложения", style: Theme.of(context).textTheme.titleMedium),
                  if (_isUploading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (canEditContent)
                    TextButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Добавить"),
                      onPressed: _pickAttachment,
                    )
                  else
                    Text("Только просмотр", style: TextStyle(color: colorScheme.outline)),
                ],
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 10),

              if (_attachments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text("Нет вложений", style: TextStyle(color: colorScheme.outline))),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var att in _attachments)
                      AttachmentThumb(
                        attachment: att,
                        // canEdit here controls deletion. Only Owner can delete.
                        canEdit: isOwner,
                        isOpening: _currentlyOpeningFile == att.filePath,
                        onTap: () => _handleOpenAttachment(att),
                        onDelete: () => _deleteAttachment(att),
                      ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
                  ],
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}