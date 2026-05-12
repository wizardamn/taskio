import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';

/// ============================================================
/// GLOBAL HELPERS
/// ============================================================

DateTime _parseDateSafe(dynamic value) {
  if (value is DateTime) {
    return value.toLocal();
  }

  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }

  return DateTime.now();
}

/// ============================================================
/// PROJECT ROLE
/// ============================================================

enum ProjectRole {
  owner,
  editor,
  viewer,
}

extension ProjectRoleExtension on ProjectRole {
  static ProjectRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return ProjectRole.owner;
      case 'editor':
        return ProjectRole.editor;
      case 'viewer':
        return ProjectRole.viewer;
      default:
        return ProjectRole.viewer;
    }
  }

  String get value => name;
}

/// ============================================================
/// PROJECT CATEGORY
/// ============================================================

enum ProjectCategory {
  educational,
  creative,
}

extension ProjectCategoryExtension on ProjectCategory {
  static ProjectCategory fromString(String? value) {
    switch (value) {
      case 'educational':
        return ProjectCategory.educational;
      case 'creative':
        return ProjectCategory.creative;
      default:
        return ProjectCategory.creative;
    }
  }

  String get value => name;

  String localizedText() {
    switch (this) {
      case ProjectCategory.educational:
        return 'project.category.educational'.tr();

      case ProjectCategory.creative:
        return 'project.category.creative'.tr();
    }
  }
}

/// ============================================================
/// PROJECT STATUS
/// ============================================================

enum ProjectStatus {
  planned,
  inProgress,
  completed,
  archived,
}

extension ProjectStatusExtension on ProjectStatus {
  String localizedText() {
    switch (this) {
      case ProjectStatus.planned:
        return 'status.planned'.tr();

      case ProjectStatus.inProgress:
        return 'status.in_progress'.tr();

      case ProjectStatus.completed:
        return 'status.completed'.tr();

      case ProjectStatus.archived:
        return 'status.archived'.tr();
    }
  }

  Color get color {
    switch (this) {
      case ProjectStatus.planned:
        return Colors.blueGrey;

      case ProjectStatus.inProgress:
        return Colors.orange;

      case ProjectStatus.completed:
        return Colors.green;

      case ProjectStatus.archived:
        return Colors.brown;
    }
  }
}

/// ============================================================
/// PARTICIPANT
/// ============================================================

class ProjectParticipant {
  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final ProjectRole role;

  const ProjectParticipant({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    required this.role,
  });

  factory ProjectParticipant.fromJson(
      Map<String, dynamic> json,
      ) {
    final profile = json['profiles'];

    Map<String, dynamic>? profileMap;

    if (profile is Map<String, dynamic>) {
      profileMap = profile;
    } else if (profile is List && profile.isNotEmpty) {
      final first = profile.first;
      if (first is Map<String, dynamic>) {
        profileMap = first;
      }
    }

    return ProjectParticipant(
      id: (json['member_id'] ?? json['id'] ?? '').toString(),
      fullName: profileMap?['full_name']?.toString() ??
          json['full_name']?.toString() ??
          'Unknown',
      username: profileMap?['username']?.toString(),
      avatarUrl: profileMap?['avatar_url']?.toString(),
      role: ProjectRoleExtension.fromString(
        json['role']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': id,
      'full_name': fullName,
      'username': username,
      'avatar_url': avatarUrl,
      'role': role.value,
    };
  }
}

/// ============================================================
/// ATTACHMENT
/// ============================================================

class Attachment {
  final String id;
  final String projectId;
  final String fileName;
  final String filePath;
  final String mimeType;
  final DateTime uploadedAt;
  final String uploaderId;

  const Attachment({
    required this.id,
    required this.projectId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.uploadedAt,
    required this.uploaderId,
  });

  factory Attachment.fromJson(
      Map<String, dynamic> json,
      ) {
    return Attachment(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      uploadedAt: _parseDateSafe(
        json['created_at'] ?? json['uploaded_at'],
      ),
      uploaderId: (json['uploaded_by'] ?? json['uploader_id'] ?? '')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'file_name': fileName,
      'file_path': filePath,
      'mime_type': mimeType,
      'created_at': uploadedAt.toUtc().toIso8601String(),
      'uploaded_by': uploaderId,
    };
  }
}

/// ============================================================
/// MAIN MODEL
/// ============================================================

class ProjectModel {
  // Уникальный идентификатор проекта
  final String id;
  // ID владельца (создателя) проекта
  final String ownerId;
  // Название проекта
  final String title;
  // Описание проекта
  final String description;
  // Крайний срок выполнения проекта
  final DateTime deadline;
  // Дата создания проекта
  final DateTime createdAt;
  // Текущий статус проекта
  final int status;
  // Цвет проекта для отображения в интерфейсе
  final String color;
  // Категория проекта
  final ProjectCategory category;
  // Максимальное количество участников
  final int maxMembers;
  // Максимальное количество вложений
  final int maxAttachments;
  // Включена ли система оценивания
  final bool gradingEnabled;
  // Список участников проекта
  final List<ProjectParticipant> participantsData;
  // Список прикреплённых файлов
  final List<Attachment> attachments;
  // Общее количество задач
  final int totalTasks;
  // Количество выполненных задач
  final int completedTasks;
  // Последнее сообщение в чате проекта
  final String? lastMessage;
  // Дата и время последнего сообщения
  final DateTime? lastMessageAt;
  // Количество непрочитанных сообщений
  final int unreadCount;

  const ProjectModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.createdAt,
    required this.status,
    required this.color,
    required this.category,
    required this.maxMembers,
    required this.maxAttachments,
    required this.gradingEnabled,
    this.participantsData = const [],
    this.attachments = const [],
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  ProjectStatus get statusEnum {
    if (status < 0 || status >= ProjectStatus.values.length) {
      return ProjectStatus.planned;
    }

    return ProjectStatus.values[status];
  }

  List<String> get participantIds =>
      participantsData.map((e) => e.id).toList();

  double get progress {
    if (totalTasks == 0) return 0;
    return (completedTasks / totalTasks).clamp(0.0, 1.0);
  }

  Color get colorObj {
    try {
      final value = color.startsWith('0x')
          ? int.parse(color)
          : int.parse('0xFF$color');

      return Color(value);
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  factory ProjectModel.fromJson(
      Map<String, dynamic> json,
      ) {
    return ProjectModel(
      id: json['id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      deadline: _parseDateSafe(json['deadline']),
      createdAt: _parseDateSafe(json['created_at']),
      status: (json['status'] as num?)?.toInt() ?? 0,
      color: json['color']?.toString() ?? '0xFF2196F3',
      category: ProjectCategoryExtension.fromString(
        json['category']?.toString(),
      ),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 10,
      maxAttachments: (json['max_attachments'] as num?)?.toInt() ?? 10,
      gradingEnabled: json['grading_enabled'] == true,
      participantsData: _parseParticipantsData(json),
      attachments: _parseAttachments(json),
      totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
      completedTasks: (json['completed_tasks'] as num?)?.toInt() ?? 0,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at'] != null
          ? _parseDateSafe(json['last_message_at'])
          : null,
    );
  }

  static List<ProjectParticipant> _parseParticipantsData(
      Map<String, dynamic> json,
      ) {
    final raw = json['participants_data'] ?? json['project_members'];

    if (raw is! List) return [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProjectParticipant.fromJson)
        .toList();
  }

  static List<Attachment> _parseAttachments(
      Map<String, dynamic> json,
      ) {
    final raw = json['attachments_data'] ?? json['project_attachments'];

    if (raw is! List) return [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(Attachment.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'deadline': deadline.toUtc().toIso8601String(),
      'status': status,
      'color': color,
      'category': category.value,
      'max_members': maxMembers,
      'max_attachments': maxAttachments,
      'grading_enabled': gradingEnabled,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    DateTime? deadline,
    DateTime? createdAt,
    int? status,
    String? color,
    ProjectCategory? category,
    int? maxMembers,
    int? maxAttachments,
    bool? gradingEnabled,
    List<ProjectParticipant>? participantsData,
    List<Attachment>? attachments,
    int? totalTasks,
    int? completedTasks,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      color: color ?? this.color,
      category: category ?? this.category,
      maxMembers: maxMembers ?? this.maxMembers,
      maxAttachments: maxAttachments ?? this.maxAttachments,
      gradingEnabled: gradingEnabled ?? this.gradingEnabled,
      participantsData: participantsData ?? this.participantsData,
      attachments: attachments ?? this.attachments,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  static ProjectModel createEmpty({
    required String ownerId,
  }) {
    return ProjectModel(
      id: const Uuid().v4(),
      ownerId: ownerId,
      title: '',
      description: '',
      deadline: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
      status: ProjectStatus.planned.index,
      color: '0xFF2196F3',
      category: ProjectCategory.creative,
      maxMembers: 10,
      maxAttachments: 10,
      gradingEnabled: false,
    );
  }
}