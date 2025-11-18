import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Анимации

import '../../services/supabase_service.dart';
import '../../models/project_model.dart'; // Импортируем модель и Enum
import '../../providers/project_provider.dart';

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
  final SupabaseClient _supabase = Supabase.instance.client;

  // Локальные переменные состояния
  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  double? _grade;
  late List<Attachment> _attachments;
  late List<String> _participants;

  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;
  bool _isUploading = false; // Флаг для индикатора загрузки файла

  static const String bucket = SupabaseService.bucket;

  @override
  void initState() {
    super.initState();

    _title = widget.project.title;
    _description = widget.project.description;
    _deadline = widget.project.deadline;
    // Используем геттер из модели для безопасного получения Enum
    _status = widget.project.statusEnum;
    _grade = widget.project.grade;
    _attachments = List.from(widget.project.attachments);
    _participants = List.from(widget.project.participants);

    _loadUsers();
  }

  // Загрузка всех пользователей для списка участников
  Future<void> _loadUsers() async {
    try {
      final res = await _supabase.from('profiles').select('id, full_name');

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки пользователей: $e')),
        );
      }
      debugPrint("Ошибка загрузки списка пользователей: $e");
    }
  }

  // Выбор участников через диалог
  Future<void> _selectParticipants() async {
    if (_users.isEmpty) return;

    if (!mounted) return;
    final List<String> selected = List.from(_participants);

    await showDialog(
      context: context,
      builder: (ctx) {
        final List<String> tempSelected = List.from(selected);

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("Выбор участников"),
              content: SizedBox(
                width: 300,
                height: 400,
                child: ListView(
                  children: _users.map((u) {
                    final id = u['id'];
                    final currentUserId = _supabase.auth.currentUser?.id;

                    // Проверка: владелец не может удалить сам себя, если проект уже существует
                    final isOwner = widget.project.ownerId == id;
                    final isDisabled = !widget.isNew && isOwner;

                    return CheckboxListTile(
                      title: Text(u['full_name'] ?? "Нет имени"),
                      value: tempSelected.contains(id),
                      onChanged: isDisabled
                          ? null // Отключаем, если это владелец
                          : (v) {
                        setInnerState(() {
                          if (v == true) {
                            tempSelected.add(id);
                          } else {
                            tempSelected.remove(id);
                          }
                        });
                      },
                      subtitle: isDisabled
                          ? Text("Владелец",
                          style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold))
                          : null,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Отмена"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _participants = tempSelected);
                    Navigator.pop(ctx);
                  },
                  child: const Text("Готово"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================
  //  Загрузка вложений
  // ============================
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'mp3', 'mp4', 'zip', 'rar'
      ],
    );

    if (result == null || result.files.single.path == null || !mounted) return;

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);
    final provider = context.read<ProjectProvider>();

    setState(() => _isUploading = true);

    try {
      final updatedProject = await provider.uploadAttachment(widget.project.id, file);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл успешно загружен')),
      );

      setState(() {
        _attachments = updatedProject.attachments;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки файла: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ============================
  //  Открытие/Скачивание вложений
  // ============================
  Future<void> _openAttachment(Attachment attachment) async {
    final String fullPublicUrl = SupabaseService.client.storage
        .from(bucket)
        .getPublicUrl(attachment.filePath);

    try {
      if (!mounted) return;
      final uri = Uri.parse(fullPublicUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Ошибка открытия URL: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть файл. Попробуйте скачать его.')),
    );
  }


  // Сохранение проекта
  Future<void> _saveProject() async {
    if (!mounted || !_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final user = _supabase.auth.currentUser;
    final currentUserId = user?.id ?? const Uuid().v4();

    // Гарантируем, что текущий пользователь (владелец) есть в списке участников
    if (widget.isNew && !_participants.contains(currentUserId)) {
      _participants.add(currentUserId);
    }
    if (!widget.isNew && !_participants.contains(widget.project.ownerId)) {
      _participants.add(widget.project.ownerId);
    }

    final projectModel = ProjectModel(
      id: widget.project.id.isNotEmpty ? widget.project.id : const Uuid().v4(),
      title: _title,
      description: _description,
      ownerId: widget.project.ownerId.isEmpty ? currentUserId : widget.project.ownerId,
      deadline: _deadline,
      // Используем index для сохранения int в базу
      status: _status.index,
      grade: _grade,
      attachments: _attachments,
      participants: _participants.toSet().toList(),
      createdAt: widget.project.createdAt,
    );

    final provider = context.read<ProjectProvider>();

    try {
      if (widget.isNew) {
        await provider.addProject(projectModel);
      } else {
        await provider.updateProject(projectModel);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isNew ? 'Проект создан' : 'Проект обновлен')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  // Удаление вложений
  Future<void> _deleteAttachment(Attachment attachment) async {
    final provider = context.read<ProjectProvider>();
    try {
      await provider.deleteAttachment(widget.project.id, attachment.filePath);

      if (mounted) {
        setState(() => _attachments.removeWhere((a) => a.filePath == attachment.filePath));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вложение удалено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUsers) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isNew ? "Создание" : "Редактирование")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? "Новый проект" : "Редактировать проект"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Сохранить',
            onPressed: _saveProject,
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
                validator: (v) => v == null || v.isEmpty ? "Введите название" : null,
                onSaved: (v) => _title = v!,
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0),

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
                onSaved: (v) => _description = v!,
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 16),

              // Дата и Статус в одном ряду (для планшетов/широких экранов) или колонкой
              Row(
                children: [
                  Expanded(
                    child: DatePickerField(
                      label: 'Дедлайн',
                      initialDate: _deadline,
                      onChanged: (d) => setState(() => _deadline = d),
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
                      // Используем values из Enum
                      items: ProjectStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          // Используем расширение .text для локализации
                          child: Text(s.text),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 16),

              // Оценка (если завершен)
              if (_status == ProjectStatus.completed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    initialValue: _grade?.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Оценка (0-100)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.grade),
                    ),
                    onSaved: (v) => _grade = v != null && v.isNotEmpty ? double.tryParse(v) : null,
                  ).animate().fadeIn().scale(),
                ),

              const Divider(),

              // Участники
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text("Участники команды"),
                subtitle: Text(
                  _participants.isEmpty
                      ? "Никто не выбран"
                      : "Выбрано: ${_participants.length} чел.",
                ),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Изменить"),
                  onPressed: _selectParticipants,
                ),
              ).animate().fadeIn(delay: 300.ms),

              const Divider(),

              // Вложения
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Вложения", style: Theme.of(context).textTheme.titleMedium),
                  if (_isUploading)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  else
                    TextButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Добавить"),
                      onPressed: _pickAttachment,
                    ),
                ],
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 10),

              if (_attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text("Нет вложений", style: TextStyle(color: Colors.grey))),
                ),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var att in _attachments)
                    AttachmentThumb(
                      attachment: att,
                      onTap: () => _openAttachment(att),
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

// =======================================================
//   Виджет выбора даты (Улучшенный)
// =======================================================
class DatePickerField extends StatelessWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;
  final String label;

  const DatePickerField({
    super.key,
    required this.initialDate,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          locale: const Locale('ru', 'RU'),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_month),
        ),
        child: Text(
          DateFormat('dd.MM.yyyy').format(initialDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// =======================================================
//   Превью вложения (Улучшенное)
// =======================================================
class AttachmentThumb extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.onDelete,
    this.onTap,
  });

  bool _isImage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImage(attachment.fileName);
    const size = 100.0;

    // Получаем публичный URL
    final String fullPublicUrl = SupabaseService.client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(attachment.filePath);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage
                  ? Image.network(
                fullPublicUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFileIcon(),
              )
                  : _buildFileIcon(),
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.blueGrey, size: 32),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}