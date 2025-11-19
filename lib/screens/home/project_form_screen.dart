import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../services/supabase_service.dart';
import '../../models/project_model.dart';
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
  final SupabaseClient _supabase = SupabaseService.client;
  final Uuid _uuid = const Uuid();

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
  bool _isUploading = false;

  // Флаг для предотвращения повторного нажатия при открытии/скачивании
  String? _currentlyOpeningFile;

  static const String bucket = SupabaseService.bucket;

  @override
  void initState() {
    super.initState();

    _title = widget.project.title;
    _description = widget.project.description;
    _deadline = widget.project.deadline;
    _status = widget.project.statusEnum;
    _grade = widget.project.grade;
    _attachments = List.from(widget.project.attachments);

    _participants = List.from(widget.project.participantIds);
    if (widget.project.ownerId.isNotEmpty && !_participants.contains(widget.project.ownerId)) {
      _participants.add(widget.project.ownerId);
    } else if (_supabase.auth.currentUser?.id != null && !_participants.contains(_supabase.auth.currentUser!.id)) {
      _participants.add(_supabase.auth.currentUser!.id);
    }

    _loadUsers();
  }

  // Загрузка всех пользователей для списка участников
  Future<void> _loadUsers() async {
    try {
      final res = await _supabase.from('profiles').select('id, full_name');

      if (!mounted) { return; }

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

  // Найти имя по ID
  String? _getUserName(String userId) {
    final user = _users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null) {
      final name = user['full_name'] as String?;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    final participantData = widget.project.participantsData.firstWhereOrNull((pd) => pd.id == userId);
    if (participantData != null) {
      return participantData.fullName;
    }

    return null;
  }

  // Выбор участников через диалог
  Future<void> _selectParticipants() async {
    if (_users.isEmpty) { return; }

    if (!mounted) { return; }
    final List<String> selected = List.from(_participants);
    final String ownerId = widget.project.ownerId.isNotEmpty ? widget.project.ownerId : _supabase.auth.currentUser?.id ?? '';

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
                    final id = u['id'] as String;
                    final isOwner = ownerId == id;
                    final name = u['full_name'] as String? ?? id;

                    final isDisabled = isOwner;

                    return CheckboxListTile(
                      title: Text(name),
                      value: tempSelected.contains(id),
                      onChanged: isDisabled
                          ? null
                          : (v) {
                        setInnerState(() {
                          if (v == true) {
                            if (!tempSelected.contains(id)) {
                              tempSelected.add(id);
                            }
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
    if (widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала сохраните проект, чтобы добавить вложения')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'mp3', 'mp4', 'zip', 'rar'
      ],
    );

    if (result == null || result.files.single.path == null || !mounted) { return; }

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);
    final provider = context.read<ProjectProvider>();

    setState(() => _isUploading = true);

    try {
      final updatedProject = await provider.uploadAttachment(widget.project.id, file);

      if (!mounted) { return; }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл успешно загружен')),
      );

      setState(() {
        _attachments = updatedProject.attachments;
      });
    } catch (e) {
      if (mounted) {
        final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки файла: $errorMessage')),
        );
      }
    } finally {
      if (mounted) { setState(() => _isUploading = false); }
    }
  }

  // ============================
  //  СКАЧИВАНИЕ И ОТКРЫТИЕ ВЛОЖЕНИЙ С ПОМОЩЬЮ OPEN_FILE
  // ============================
  Future<void> _downloadAndOpenAttachment(Attachment attachment) async {
    if (_currentlyOpeningFile == attachment.filePath) { return; }

    setState(() => _currentlyOpeningFile = attachment.filePath);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Загрузка и открытие: ${attachment.fileName}')),
    );

    final String fullPublicUrl = _supabase.storage
        .from(bucket)
        .getPublicUrl(attachment.filePath);

    try {
      // 1. Скачиваем файл по URL
      final response = await http.get(Uri.parse(fullPublicUrl));
      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить файл. Код: ${response.statusCode}');
      }

      // 2. Получаем временный каталог для сохранения
      final dir = await getTemporaryDirectory();

      // 3. Создаем локальный файл с оригинальным именем
      final localPath = '${dir.path}/${attachment.fileName}';
      final file = File(localPath);

      // 4. Записываем данные в файл
      await file.writeAsBytes(response.bodyBytes);

      // 5. Открываем локальный файл с помощью open_file.
      // Пакет open_file возвращает Future<String>.
      final result = await OpenFile.open(localPath);

      if (!mounted) { return; }

      // ПРОВЕРКА РЕЗУЛЬТАТА: open_file возвращает 'done' при успехе или сообщение об ошибке.
      if (result == 'done') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл ${attachment.fileName} открыт.')),
        );
      } else {
        // result содержит сообщение об ошибке (например, 'No app found to open...')
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия: $result')),
        );
      }

    } catch (e) {
      debugPrint('Ошибка скачивания/открытия: $e');
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обработки файла: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if(mounted) { setState(() => _currentlyOpeningFile = null); }
    }
  }

  // Сохранение проекта
  Future<void> _saveProject() async {
    if (!mounted || !_formKey.currentState!.validate()) { return; }

    _formKey.currentState!.save();

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: Пользователь не авторизован.')),
        );
      }
      return;
    }

    final projectId = widget.project.id.isNotEmpty ? widget.project.id : _uuid.v4();
    final ownerId = widget.project.ownerId.isNotEmpty ? widget.project.ownerId : currentUserId;

    final Set<String> participantSet = _participants.toSet();
    participantSet.add(ownerId);
    final finalParticipantIds = participantSet.toList();


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
      participantIds: finalParticipantIds,
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
        final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $errorMessage')),
        );
      }
    }
  }

  // Удаление вложений
  Future<void> _deleteAttachment(Attachment attachment) async {
    if (widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: Проект не сохранен в базе.')),
      );
      return;
    }

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
        final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $errorMessage')),
        );
      }
    }
  }

  // Виджет для плитки участников
  Widget _buildParticipantsTile(BuildContext context, List<String> participantNames) {
    return ListTile(
      leading: const Icon(Icons.people),
      title: const Text("Участники команды"),
      subtitle: Text(
        participantNames.isEmpty
            ? "Никто не выбран"
            : participantNames.join(', '),
      ),
      trailing: ElevatedButton.icon(
        icon: const Icon(Icons.edit),
        label: const Text("Изменить"),
        onPressed: _selectParticipants,
      ),
    ).animate().fadeIn(delay: 300.ms);
  }


  @override
  Widget build(BuildContext context) {
    final uniqueParticipantIds = _participants.toSet().toList();

    final participantNames = uniqueParticipantIds
        .map((id) => _getUserName(id))
        .whereType<String>()
        .toList();


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

              // Дата и Статус
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
                      items: ProjectStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
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
                    initialValue: _grade != null ? _grade!.truncate().toString() : '',
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
                      final int? num = int.tryParse(v);
                      if (num == null || num < 0 || num > 100) {
                        return "Введите целое число от 0 до 100";
                      }
                      return null;
                    },
                    onSaved: (v) => _grade = v != null && v.isNotEmpty ? int.tryParse(v)?.toDouble() : null,
                  ).animate().fadeIn().scale(),
                ),

              const Divider(),

              // Участники
              _buildParticipantsTile(context, participantNames),

              const SizedBox(height: 8),
              if (participantNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Выбрано: ${participantNames.length} чел.",
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                  ),
                ),


              const Divider(),

              // Вложения
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Вложения (нажмите для скачивания/открытия)", style: Theme.of(context).textTheme.titleMedium),
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
                      onTap: () => _downloadAndOpenAttachment(att),
                      onDelete: () => _deleteAttachment(att),
                      isOpening: _currentlyOpeningFile == att.filePath,
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

// Улучшенный DatePickerField
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
        final initialDateTime = DateTime(initialDate.year, initialDate.month, initialDate.day);

        final picked = await showDatePicker(
          context: context,
          initialDate: initialDateTime,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
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

// Превью вложения
class AttachmentThumb extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool isOpening;

  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.onDelete,
    this.onTap,
    this.isOpening = false,
  });

  bool _isImage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImage(attachment.fileName);
    const size = 100.0;

    final String fullPublicUrl = SupabaseService.client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(attachment.filePath);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: isOpening ? null : onTap, // Отключаем onTap, пока файл открывается
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isOpening ? Colors.blue.shade50 : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: isOpening ? 2.5 : 1),
            ),
            child: isOpening
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(height: 8),
                  Text('Открытие...', style: TextStyle(fontSize: 10, color: Colors.blue.shade800))
                ],
              ),
            )
                : ClipRRect(
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
        if (onDelete != null && !isOpening)
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

// Добавляем этот простой экстеншн, чтобы .firstWhereOrNull работал
extension _ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}