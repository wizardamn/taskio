import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';

/// ============================================================
/// GLOBAL HELPERS
/// ============================================================

DateTime _parseDateSafe(dynamic value) {
  if (value == null) {
    return DateTime.now();
  }

  if (value is DateTime) {
    return value.toLocal();
  }

  final parsed = DateTime.tryParse(value.toString());

  if (parsed != null) {
    return parsed.toLocal();
  }

  return DateTime.now();
}

DateTime? _parseDateNullable(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value.toLocal();
  }

  return DateTime.tryParse(value.toString())?.toLocal();
}

int _parseIntSafe(
    dynamic value, {
      int fallback = 0,
    }) {
  if (value == null) {
    return fallback;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString()) ?? fallback;
}

bool _parseBoolSafe(
    dynamic value, {
      bool fallback = false,
    }) {
  if (value == null) {
    return fallback;
  }

  if (value is bool) {
    return value;
  }

  final text = value.toString().toLowerCase().trim();

  return text == 'true' || text == '1' || text == 'yes';
}

String _stringSafe(dynamic value) {
  return value?.toString().trim() ?? '';
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
    switch (value?.toLowerCase().trim()) {
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

  String localizedText() {
    switch (this) {
      case ProjectRole.owner:
        return 'project_roles.owner'.tr();

      case ProjectRole.editor:
        return 'project_roles.editor'.tr();

      case ProjectRole.viewer:
        return 'project_roles.viewer'.tr();
    }
  }
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
    switch (value?.toLowerCase().trim()) {
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
        return 'project_category.educational'.tr();

      case ProjectCategory.creative:
        return 'project_category.creative'.tr();
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
  static ProjectStatus fromValue(dynamic value) {
    if (value is int) {
      if (value >= 0 && value < ProjectStatus.values.length) {
        return ProjectStatus.values[value];
      }

      return ProjectStatus.planned;
    }

    if (value is num) {
      final index = value.toInt();

      if (index >= 0 && index < ProjectStatus.values.length) {
        return ProjectStatus.values[index];
      }

      return ProjectStatus.planned;
    }

    switch (value?.toString().toLowerCase().trim()) {
      case 'planned':
      case '0':
        return ProjectStatus.planned;

      case 'in_progress':
      case 'inprogress':
      case '1':
        return ProjectStatus.inProgress;

      case 'completed':
      case '2':
        return ProjectStatus.completed;

      case 'archived':
      case 'archive':
      case '3':
        return ProjectStatus.archived;

      default:
        return ProjectStatus.planned;
    }
  }

  int get dbValue => index;

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
    final profileMap = _extractProfile(json);

    final id = _stringSafe(
      json['member_id'] ?? json['id'] ?? json['user_id'],
    );

    final firstName = _stringSafe(
      profileMap?['first_name'] ?? json['first_name'],
    );

    final lastName = _stringSafe(
      profileMap?['last_name'] ?? json['last_name'],
    );

    final fullName = _resolveFullName(
      fullName: profileMap?['full_name'] ?? json['full_name'],
      firstName: firstName,
      lastName: lastName,
      username: profileMap?['username'] ?? json['username'],
    );

    return ProjectParticipant(
      id: id,
      fullName: fullName,
      username: _normalizeUsername(
        profileMap?['username'] ?? json['username'],
      ),
      avatarUrl: _emptyToNull(
        profileMap?['avatar_url'] ?? json['avatar_url'],
      ),
      role: ProjectRoleExtension.fromString(
        json['role']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': id,
      'id': id,
      'full_name': fullName,
      'username': username,
      'avatar_url': avatarUrl,
      'role': role.value,
    };
  }

  static Map<String, dynamic>? _extractProfile(
      Map<String, dynamic> json,
      ) {
    final profile = json['profiles'] ?? json['profile'];

    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }

    if (profile is List && profile.isNotEmpty) {
      final first = profile.first;

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return null;
  }

  static String _resolveFullName({
    required dynamic fullName,
    required String firstName,
    required String lastName,
    required dynamic username,
  }) {
    final directFullName = _stringSafe(fullName);

    if (directFullName.isNotEmpty) {
      return directFullName;
    }

    final combined = '$firstName $lastName'.trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    final normalizedUsername = _normalizeUsername(username);

    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      return '@$normalizedUsername';
    }

    return 'users.no_name'.tr();
  }

  static String? _normalizeUsername(dynamic value) {
    final username = _stringSafe(value);

    if (username.isEmpty) {
      return null;
    }

    if (username.startsWith('@')) {
      return username.substring(1);
    }

    return username;
  }

  static String? _emptyToNull(dynamic value) {
    final text = _stringSafe(value);

    if (text.isEmpty) {
      return null;
    }

    return text;
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
  final int fileSize;
  final DateTime uploadedAt;
  final String uploaderId;

  const Attachment({
    required this.id,
    required this.projectId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    this.fileSize = 0,
    required this.uploadedAt,
    required this.uploaderId,
  });

  factory Attachment.fromJson(
      Map<String, dynamic> json,
      ) {
    return Attachment(
      id: _stringSafe(json['id']),
      projectId: _stringSafe(json['project_id']),
      fileName: _stringSafe(json['file_name']),
      filePath: _stringSafe(json['file_path']),
      mimeType: _stringSafe(json['mime_type']),
      fileSize: _parseIntSafe(json['file_size']),
      uploadedAt: _parseDateSafe(
        json['created_at'] ?? json['uploaded_at'],
      ),
      uploaderId: _stringSafe(
        json['uploaded_by'] ?? json['uploader_id'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'file_name': fileName,
      'file_path': filePath,
      'mime_type': mimeType,
      'file_size': fileSize,
      'created_at': uploadedAt.toUtc().toIso8601String(),
      'uploaded_by': uploaderId,
    };
  }
}

/// ============================================================
/// MAIN MODEL
/// ============================================================

class ProjectModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final DateTime deadline;
  final DateTime createdAt;
  final int status;
  final String color;

  final ProjectCategory category;
  final int maxMembers;
  final int maxAttachments;
  final bool gradingEnabled;

  final List<ProjectParticipant> participantsData;
  final List<Attachment> attachments;

  final int totalTasks;
  final int completedTasks;

  final String? lastMessage;
  final DateTime? lastMessageAt;

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
    return ProjectStatusExtension.fromValue(status);
  }

  List<String> get participantIds {
    return participantsData
        .map((participant) => participant.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  double get progress {
    if (totalTasks <= 0) {
      return 0;
    }

    return (completedTasks / totalTasks).clamp(0.0, 1.0);
  }

  Color get colorObj {
    try {
      final prepared = color.startsWith('0x')
          ? color
          : color.startsWith('#')
          ? '0xFF${color.substring(1)}'
          : '0xFF$color';

      return Color(int.parse(prepared));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  factory ProjectModel.fromJson(
      Map<String, dynamic> json,
      ) {
    final parsedStatus = ProjectStatusExtension.fromValue(
      json['status'],
    );

    return ProjectModel(
      id: _stringSafe(json['id']),
      ownerId: _stringSafe(json['owner_id']),
      title: _stringSafe(json['title']),
      description: _stringSafe(json['description']),
      deadline: _parseDateSafe(json['deadline']),
      createdAt: _parseDateSafe(json['created_at']),
      status: parsedStatus.dbValue,
      color: _stringSafe(json['color']).isNotEmpty
          ? _stringSafe(json['color'])
          : '0xFF2196F3',
      category: ProjectCategoryExtension.fromString(
        json['category']?.toString(),
      ),
      maxMembers: _parseIntSafe(
        json['max_members'],
        fallback: 10,
      ),
      maxAttachments: _parseIntSafe(
        json['max_attachments'],
        fallback: 10,
      ),
      gradingEnabled: _parseBoolSafe(
        json['grading_enabled'],
      ),
      participantsData: _parseParticipantsData(json),
      attachments: _parseAttachments(json),
      totalTasks: _parseIntSafe(json['total_tasks']),
      completedTasks: _parseIntSafe(json['completed_tasks']),
      unreadCount: _parseIntSafe(
        json['unread_count'] ?? json['unread'],
      ),
      lastMessage: _emptyStringToNull(json['last_message']),
      lastMessageAt: _parseDateNullable(json['last_message_at']),
    );
  }

  static List<ProjectParticipant> _parseParticipantsData(
      Map<String, dynamic> json,
      ) {
    final raw = json['participants_data'] ??
        json['project_members'] ??
        json['members'];

    if (raw is! List) {
      return [];
    }

    final result = <ProjectParticipant>[];

    for (final item in raw) {
      if (item is Map) {
        result.add(
          ProjectParticipant.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    return result;
  }

  static List<Attachment> _parseAttachments(
      Map<String, dynamic> json,
      ) {
    final raw = json['attachments_data'] ??
        json['project_attachments'] ??
        json['attachments'];

    if (raw is! List) {
      return [];
    }

    final result = <Attachment>[];

    for (final item in raw) {
      if (item is Map) {
        result.add(
          Attachment.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    return result;
  }

  static String? _emptyStringToNull(dynamic value) {
    final text = _stringSafe(value);

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'deadline': deadline.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
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
      deadline: DateTime.now().add(
        const Duration(days: 7),
      ),
      createdAt: DateTime.now(),
      status: ProjectStatus.planned.dbValue,
      color: '0xFF2196F3',
      category: ProjectCategory.creative,
      maxMembers: 10,
      maxAttachments: 10,
      gradingEnabled: false,
      participantsData: [
        ProjectParticipant(
          id: ownerId,
          fullName: 'project.owner'.tr(),
          role: ProjectRole.owner,
        ),
      ],
    );
  }
}