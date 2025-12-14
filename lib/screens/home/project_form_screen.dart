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

  // ИНИЦИАЛИЗАЦИЯ UUID
  final Uuid _uuid = Uuid();

  // Локальные переменные состояния
  late String _title;
  late String _description;
  late DateTime _deadline;
  late ProjectStatus _status;
  double? _grade;
  late List<Attachment> _attachments;

  // Список ID участников, включая владельца
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

    // --- Логика инициализации участников ---
    final Set<String> participantSet = widget.project.participantIds.toSet();

    final String currentUserId = _supabase.auth.currentUser?.id ?? '';
    final String ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : currentUserId;

    if (ownerId.isNotEmpty) {
      participantSet.add(ownerId);
    }

    _participants = participantSet.toList();
    // ------------------------------------

    _loadUsers();
  }

  // Загрузка всех пользователей для списка участников
  Future<void> _loadUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      // Если пользователь не авторизован, логично ничего не загружать
      if (currentUserId == null) {
        if (!mounted) return;
        setState(() {
          _users = [];
          _isLoadingUsers = false;
        });
        return; // Прерываем выполнение метода
      }

      // Загружаем всех, кроме текущего, чтобы не дублировать "Я" в списке пользователей,
      // но при этом иметь всех остальных
      final res = await _supabase.from('profiles')
          .select('id, full_name')
          .neq('id', currentUserId); // <-- Теперь currentUserId гарантированно String

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
        // Используем явный toString() для безопасности
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки пользователей: ${e.toString()}')),
        );
      }
      debugPrint("Ошибка загрузки списка пользователей: $e");
    }
  }

  // Найти имя по ID
  String _getUserName(String userId) {
    // 1. Поиск в загруженном списке пользователей
    final user = _users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null) {
      final String? name = user['full_name'] as String?;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    // 2. Поиск в данных участников, пришедших с проектом
    final participantData = widget.project.participantsData.firstWhereOrNull((pd) => pd.id == userId);
    if (participantData != null) {
      return participantData.fullName;
    }

    // 3. Проверяем, не является ли это текущим пользователем
    final currentUserId = _supabase.auth.currentUser?.id;
    if (userId == currentUserId) {
      return 'Я (Владелец)';
    }

    return 'Неизвестный пользователь';
  }

  // Выбор участников через диалог
  Future<void> _selectParticipants() async {
    // --- ПРОВЕРКА: Только владелец может изменять список участников ---
    final prov = context.read<ProjectProvider>();
    if (!prov.canEditProject(widget.project) || widget.project.ownerId != _supabase.auth.currentUser?.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Только владелец проекта может изменять список участников.')),
        );
      }
      return;
    }

    if (_users.isEmpty && _isLoadingUsers) { return; }

    if (!mounted) { return; }

    final Set<String> selected = _participants.toSet();
    final String ownerId = widget.project.ownerId.isNotEmpty
        ? widget.project.ownerId
        : _supabase.auth.currentUser?.id ?? '';


    await showDialog(
      context: context,
      builder: (ctx) {
        final Set<String> tempSelected = Set.from(selected);

        return StatefulBuilder(
          builder: (context, setInnerState) {
            // Список всех пользователей для выбора
            final List<Map<String, dynamic>> allUsersForSelection = [
              // Добавляем владельца как плейсхолдер, если его нет в списке _users (потому что мы его отфильтровали)
              if (ownerId.isNotEmpty)
                _users.firstWhereOrNull((u) => u['id'] == ownerId) ??
                    {'id': ownerId, 'full_name': 'Я (Владелец)'},
              ..._users.where((u) => u['id'] != ownerId),
            ].toSet().toList(); // Уникальный список

            return AlertDialog(
              title: const Text("Выбор участников"),
              content: SizedBox(
                width: 300,
                height: 400,
                child: ListView(
                  children: allUsersForSelection.map((u) {
                    final String id = u['id'] as String;
                    final isOwner = ownerId == id;

                    final String displayName = (u['full_name'] as String?) ?? id;

                    final isDisabled = isOwner;

                    // Владелец всегда выбран и не может быть снят
                    if (isOwner && !tempSelected.contains(id)) {
                      tempSelected.add(id);
                    }

                    return CheckboxListTile(
                      title: Text(displayName),
                      value: tempSelected.contains(id),
                      onChanged: isDisabled
                          ? null
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
                    setState(() => _participants = tempSelected.toList());
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
  //  Загрузка вложений (теперь доступна всем участникам)
  // ============================
  Future<void> _pickAttachment() async {
    if (widget.project.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала сохраните проект, чтобы добавить вложения')),
        );
      }
      return;
    }

    // --- ПРОВЕРКА: Любой участник может добавлять вложения ---
    final prov = context.read<ProjectProvider>();
    if (!prov.canViewProject(widget.project)) { // <-- Проверяем, может ли пользователь *видеть* проект
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы не состоите в этом проекте и не можете добавлять вложения.')),
        );
      }
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
    // final provider = context.read<ProjectProvider>(); // Уже получен выше

    setState(() => _isUploading = true);

    try {
      final updatedProject = await prov.uploadAttachment(widget.project.id, file); // <-- Вызываем через провайдер

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
      final result = await OpenFile.open(localPath);

      if (!mounted) { return; }

      // ПРОВЕРКА РЕЗУЛЬТАТА: open_file возвращает 'done' при успехе или сообщение об ошибке.
      if (result.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл ${attachment.fileName} открыт.')),
        );
      } else {
        // result содержит сообщение об ошибке (например, 'No app found to open...')
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия: ${result.message}')),
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

  // Сохранение проекта (доступно только владельцу)
  Future<void> _saveProject() async {
    // --- ПРОВЕРКА: Только владелец может сохранить проект ---
    final prov = context.read<ProjectProvider>();
    if (!prov.canEditProject(widget.project) || widget.project.ownerId != _supabase.auth.currentUser?.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Только владелец проекта может сохранить изменения.')),
        );
      }
      return;
    }

    if (!mounted || !_formKey.currentState!.validate()) { return; }

    // Убеждаемся, что все поля сохранены
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

    final finalParticipantIds = _participants.toSet().toList();

    // Создание модели проекта
    final projectModel = ProjectModel(
      id: projectId,
      title: _title,
      description: _description,
      ownerId: ownerId,
      deadline: _deadline,
      status: _status.index,
      grade: _grade,
      attachments: _attachments,
      participantsData: const [], // ИСПРАВЛЕНО: Убрано ненужное конструирование []
      participantIds: finalParticipantIds,
      createdAt: widget.project.createdAt.isBefore(DateTime(2000)) ? DateTime.now() : widget.project.createdAt,
    );

    // final provider = context.read<ProjectProvider>(); // Уже получен выше

    try {
      if (widget.isNew) {
        final savedProject = await prov.addProject(projectModel);
        if (savedProject == null) {
          throw Exception("Не удалось создать проект (ошибка провайдера).");
        }
        // Если проект успешно создан, обновляем ID для последующих операций (вложений)
        // Хотя в этом виджете мы сразу покинем экран, это хорошая практика.
        // widget.project.id = savedProject.id; // Нельзя менять final, но логика на сервере должна быть учтена.

      } else {
        await prov.updateProject(projectModel);
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

  // Удаление вложений (доступно только редакторам и владельцам)
  Future<void> _deleteAttachment(Attachment attachment) async {
    if (widget.project.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: Проект не сохранен в базе.')),
      );
      return;
    }

    // --- ПРОВЕРКА: Только владелец или редактор может удалить вложение ---
    final prov = context.read<ProjectProvider>();
    if (!prov.canEditProject(widget.project)) { // <-- Используем canEditProject для проверки прав на изменение
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Только участники с правами редактирования могут удалять вложения.')),
        );
      }
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

  // Виджет для плитки участников (теперь доступен только владельцу)
  Widget _buildParticipantsTile(BuildContext context, List<String> participantNames) {
    // --- ПРОВЕРКА: Кнопка "Изменить" доступна только владельцу ---
    final prov = context.read<ProjectProvider>();
    final canEditParticipants = widget.project.ownerId == _supabase.auth.currentUser?.id;

    return ListTile(
      leading: const Icon(Icons.people),
      title: const Text("Участники команды"),
      subtitle: Text(
        participantNames.isEmpty
            ? "Никто не выбран"
            : participantNames.join(', '),
      ),
      trailing: canEditParticipants // <-- Показываем кнопку только владельцу
          ? ElevatedButton.icon(
        icon: const Icon(Icons.edit),
        label: const Text("Изменить"),
        onPressed: _selectParticipants,
      )
          : null, // Если не владелец, кнопка не показывается
    ).animate().fadeIn(delay: 300.ms);
  }

  @override
  Widget build(BuildContext context) {
    // Получаем уникальный список участников и их имена
    final uniqueParticipantIds = _participants.toSet().toList();

    final participantNames = uniqueParticipantIds
        .map((id) => _getUserName(id))
        .whereType<String>()
        .toList();

    // --- ПРОВЕРКА ПРАВ ---
    final prov = context.read<ProjectProvider>();
    final canEditProject = prov.canEditProject(widget.project); // Владелец или редактор
    final canEditParticipants = widget.project.ownerId == _supabase.auth.currentUser?.id; // Только владелец

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
          // --- КНОПКА СОХРАНЕНИЯ: ПОКАЗЫВАЕТСЯ ТОЛЬКО ВЛАДЕЛЬЦУ ---
          if (canEditParticipants)
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
              // Название (редактируется только если canEditProject)
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: "Название проекта",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v == null || v.isEmpty ? "Введите название" : null,
                onSaved: (v) => _title = v!, // ИСПРАВЛЕНО: Теперь v! безопасен, т.к. валидатор проверяет на null/empty
                enabled: canEditProject, // <-- Редактируемость зависит от прав
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 16),

              // Описание (редактируется только если canEditProject)
              TextFormField(
                initialValue: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Описание",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                onSaved: (v) => _description = v ?? '', // ИСПРАВЛЕНО: Обработка null для необязательного поля
                enabled: canEditProject, // <-- Редактируемость зависит от прав
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 16),

              // Дата и Статус (редактируются только если canEditProject)
              Row(
                children: [
                  Expanded(
                    child: DatePickerField(
                      label: 'Дедлайн',
                      initialDate: _deadline,
                      // onChanged доступен только если canEditProject
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
                      items: ProjectStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.text),
                        );
                      }).toList(),
                      // onChanged доступно только если canEditProject
                      onChanged: canEditProject ? (v) => setState(() => _status = v!) : null,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 16),

              // Оценка (редактируется только если canEditProject и статус == completed)
              if (_status == ProjectStatus.completed && canEditProject)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    // Используем toInt() для отображения целого числа
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
                      final int? num = int.tryParse(v);
                      if (num == null || num < 0 || num > 100) {
                        return "Введите целое число от 0 до 100";
                      }
                      return null;
                    },
                    // onSaved доступно только если canEditProject
                    onSaved: (v) {
                      if (v != null && v.isNotEmpty) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          _grade = parsed.toDouble();
                        } else {
                          _grade = null;
                        }
                      } else {
                        _grade = null;
                      }
                    },
                    enabled: canEditProject, // <-- Редактируемость зависит от прав
                  ).animate().fadeIn().scale(),
                ),

              const Divider(),

              // Участники (кнопка "Изменить" доступна только владельцу)
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

              // Вложения (кнопка "Добавить" доступна всем участникам, удаление - только редакторам/владельцу)
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
                  // --- КНОПКА ДОБАВЛЕНИЯ: ПОКАЗЫВАЕТСЯ ВСЕМ УЧАСТНИКАМ ---
                    if (prov.canViewProject(widget.project)) // <-- Проверка, что пользователь *видит* проект
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
                      // --- Передаём canEditProject в AttachmentThumb ---
                      canEdit: canEditProject, // <-- Позволяет показать/скрыть иконку удаления
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
  final ValueChanged<DateTime>? onChanged; // Может быть null
  final String label;

  const DatePickerField({
    super.key,
    required this.initialDate,
    required this.onChanged, // <-- Требуем, но может быть null
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // --- РЕДАКТИРУЕМОСТЬ: onTap доступен только если onChanged != null ---
    return InkWell(
      onTap: onChanged != null ? () async { // <-- Проверка
        final initialDateTime = DateTime(initialDate.year, initialDate.month, initialDate.day);

        final picked = await showDatePicker(
          context: context,
          initialDate: initialDateTime,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged!(picked); // <-- Вызов безопасен, так как проверили на null
        }
      } : null, // <-- Если null, onTap не сработает
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
  // --- НОВОЕ: Флаг canEdit для управления иконкой удаления ---
  final bool canEdit; // <-- Добавлен флаг

  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.onTap,
    this.onDelete,
    this.isOpening = false,
    required this.canEdit, // <-- Требуем флаг
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
        // --- ИКОНКА УДАЛЕНИЯ: ПОКАЗЫВАЕТСЯ ТОЛЬКО ЕСЛИ canEdit ---
        if (onDelete != null && !isOpening && canEdit) // <-- Проверка canEdit
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