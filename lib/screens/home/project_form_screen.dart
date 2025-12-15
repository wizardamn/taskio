import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart'; // <-- ВЕРНУЛИ ИМПОРТ

// --- ИМПОРТЫ ПРОЕКТА ---
import '../../services/supabase_service.dart';
import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../services/notification_service.dart';

// --- НОВЫЕ ИМПОРТЫ ---
import '../../utils/file_opener_utils.dart';
import '../../widgets/project_form_widgets.dart';
import '../../widgets/participant_selection_dialog.dart';

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

  // Состояние формы
  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  double? _grade;
  List<Attachment> _attachments = [];

  // Участники
  late List<String> _participants;
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;

  // Файлы
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
    _attachments = List.from(widget.project.attachments);

    // Инициализация участников
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

  // --- Загрузка пользователей ---
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

  // --- Имя пользователя по ID ---
  String _getUserName(String userId) {
    // 1. Поиск в загруженных (теперь используется стандартный firstWhereOrNull из package:collection)
    final user = _users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null) {
      return user['full_name'] as String? ?? 'Без имени';
    }
    // 2. Поиск в данных проекта
    final participantData = widget.project.participantsData.firstWhereOrNull((pd) => pd.id == userId);
    if (participantData != null) {
      return participantData.fullName;
    }
    // 3. Текущий юзер
    if (userId == _supabase.auth.currentUser?.id) {
      return 'Я (Владелец)';
    }
    return 'Неизвестный';
  }

  // --- Логика выбора участников ---
  Future<void> _selectParticipants() async {
    final prov = context.read<ProjectProvider>();
    final currentUser = _supabase.auth.currentUser;

    // Проверки прав
    if (!prov.canEditProject(widget.project) || widget.project.ownerId != currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только владелец проекта может изменять список участников.')),
      );
      return;
    }

    if (_users.isEmpty && _isLoadingUsers) return;

    final ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : currentUser?.id ?? '';

    // Открываем диалог (код диалога вынесен в отдельный файл)
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

  // --- Загрузка вложения ---
  Future<void> _pickAttachment() async {
    if (widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала сохраните проект')));
      return;
    }

    final prov = context.read<ProjectProvider>();
    if (!prov.canViewProject(widget.project)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет прав на добавление файлов.')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'mp3', 'mp4', 'zip', 'rar'],
    );

    if (result == null || result.files.single.path == null || !mounted) return;

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);

    setState(() => _isUploading = true);

    try {
      final updatedProject = await prov.uploadAttachment(widget.project.id, file);

      // Уведомление отправляется асинхронно
      await NotificationService().showSimple(
        'Файл загружен',
        'Файл "${pickedFile.name}" добавлен к проекту "${updatedProject.title}".',
      );

      // Проверяем mounted после await, перед использованием context
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

  // --- Открытие вложения (с использованием новой утилиты) ---
  Future<void> _handleOpenAttachment(Attachment attachment) async {
    if (_currentlyOpeningFile == attachment.filePath) return;

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

  // --- Удаление вложения ---
  Future<void> _deleteAttachment(Attachment attachment) async {
    final prov = context.read<ProjectProvider>();
    if (!prov.canEditProject(widget.project)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет прав на удаление.')));
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

  // --- Сохранение проекта ---
  Future<void> _saveProject() async {
    final prov = context.read<ProjectProvider>();
    if (!prov.canEditProject(widget.project) || widget.project.ownerId != _supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет прав на сохранение.')));
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
    // Подготовка данных для UI
    final uniqueParticipantIds = _participants.toSet().toList();
    final participantNames = uniqueParticipantIds
        .map((id) => _getUserName(id))
        .toList();

    final prov = context.watch<ProjectProvider>();
    final canEditProject = prov.canEditProject(widget.project);
    final isOwner = widget.project.ownerId == _supabase.auth.currentUser?.id;

    if (_isLoadingUsers) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isNew ? "Создание" : "Загрузка...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? "Новый проект" : "Редактировать проект"),
        actions: [
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
              // Название
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: "Название проекта",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v?.isEmpty ?? true ? "Введите название" : null,
                onSaved: (v) => _title = v!,
                enabled: canEditProject,
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 16),

              // Описание
              TextFormField(
                initialValue: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Описание",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                onSaved: (v) => _description = v ?? '',
                enabled: canEditProject,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 16),

              // Дедлайн и Статус
              Row(
                children: [
                  Expanded(
                    child: DatePickerField(
                      label: 'Дедлайн',
                      initialDate: _deadline,
                      onChanged: canEditProject ? (d) => setState(() => _deadline = d) : null,
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
                      onChanged: canEditProject ? (v) => setState(() => _status = v!) : null,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),

              // Оценка
              if (_status == ProjectStatus.completed && canEditProject)
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
                  enabled: canEditProject,
                ).animate().fadeIn(),

              const Divider(height: 30),

              // Участники (Используем ListTile для открытия диалога)
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

              // Заголовок Вложений
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Вложения", style: Theme.of(context).textTheme.titleMedium),
                  if (_isUploading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (prov.canViewProject(widget.project))
                    TextButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Добавить"),
                      onPressed: _pickAttachment,
                    )
                  else
                    const Text("Нет прав", style: TextStyle(color: Colors.grey)),
                ],
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 10),

              // Список вложений
              if (_attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text("Нет вложений", style: TextStyle(color: Colors.grey))),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var att in _attachments)
                      AttachmentThumb(
                        attachment: att,
                        canEdit: canEditProject,
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
// УБРАНО ЛОКАЛЬНОЕ РАСШИРЕНИЕ, так как добавлен пакет collection