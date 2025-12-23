import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ----------------------------------------------------------------------
// 1. Модель участника проекта
// ----------------------------------------------------------------------
class ProjectParticipant {
  final String id;
  final String fullName;
  final String? role; // "owner" | "editor" | "viewer"

  ProjectParticipant({
    required this.id,
    required this.fullName,
    this.role,
  });

  factory ProjectParticipant.fromJson(Map<String, dynamic> json) {
    return ProjectParticipant(
      id: json['member_id'] as String? ?? json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Неизвестный участник',
      role: json['role'] as String?,
    );
  }

  @override
  String toString() => 'ProjectParticipant(id: $id, name: $fullName, role: $role)';
}

// ----------------------------------------------------------------------
// ENUM: СТАТУС ПРОЕКТА
// ----------------------------------------------------------------------
enum ProjectStatus {
  planned,
  inProgress,
  completed,
  archived,
}

extension ProjectStatusExtension on ProjectStatus {
  String get text {
    switch (this) {
      case ProjectStatus.planned:   return 'Запланирован';
      case ProjectStatus.inProgress: return 'В работе';
      case ProjectStatus.completed:  return 'Завершен';
      case ProjectStatus.archived:   return 'Архив';
    }
  }

  Color get color {
    switch (this) {
      case ProjectStatus.planned:   return Colors.blueGrey.shade400;
      case ProjectStatus.inProgress: return Colors.orange.shade600;
      case ProjectStatus.completed:  return Colors.green.shade600;
      case ProjectStatus.archived:   return Colors.brown.shade400;
    }
  }
}

// ----------------------------------------------------------------------
// МОДЕЛЬ ВЛОЖЕНИЯ
// ----------------------------------------------------------------------
class Attachment {
  final String fileName;
  final String filePath;
  final String mimeType;
  final DateTime uploadedAt;
  final String uploaderId;

  String get path => filePath;

  Attachment({
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.uploadedAt,
    required this.uploaderId,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      mimeType: json['mime_type'] as String? ?? '',
      uploadedAt: DateTime.parse(json['uploaded_at'] as String).toLocal(),
      uploaderId: json['uploader_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'file_path': filePath,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toUtc().toIso8601String(),
      'uploader_id': uploaderId,
    };
  }
}

// ----------------------------------------------------------------------
// ОСНОВНАЯ МОДЕЛЬ ПРОЕКТА
// ----------------------------------------------------------------------
class ProjectModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final DateTime deadline;
  final int status;
  final double? grade;

  final List<String> participantIds;
  final List<ProjectParticipant> participantsData;
  final List<Attachment> attachments;
  final DateTime createdAt;

  final int totalTasks;
  final int completedTasks;

  final String color;

  ProjectModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
    this.grade,
    this.participantIds = const [],
    this.participantsData = const [],
    this.attachments = const [],
    required this.createdAt,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.color = '0xFF2196F3',
  });

  ProjectStatus get statusEnum {
    if (status < 0 || status >= ProjectStatus.values.length) {
      return ProjectStatus.planned;
    }
    return ProjectStatus.values[status];
  }

  // Геттер прогресса (0.0 ... 1.0)
  double get progress {
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }

  // Удобный геттер для получения объекта Color
  Color get colorObj {
    try {
      return Color(int.parse(color));
    } catch (_) {
      return const Color(0xFF2196F3); // Fallback
    }
  }

  String getLocalizedStatus() => statusEnum.text;

  // ------------------------------------------------
  // COPY WITH
  // ------------------------------------------------
  ProjectModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    DateTime? deadline,
    int? status,
    double? grade,
    List<String>? participantIds,
    List<ProjectParticipant>? participantsData,
    List<Attachment>? attachments,
    DateTime? createdAt,
    int? totalTasks,
    int? completedTasks,
    String? color, // <--
  }) {
    return ProjectModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      grade: grade ?? this.grade,
      participantIds: participantIds ?? this.participantIds,
      participantsData: participantsData ?? this.participantsData,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      color: color ?? this.color, // <--
    );
  }

  // ------------------------------------------------
  // FROM JSON
  // ------------------------------------------------
  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    List<String> parseParticipantIds(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<Attachment> parseAttachments(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(Attachment.fromJson)
            .toList();
      }
      return [];
    }

    return ProjectModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      deadline: DateTime.parse(json['deadline'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      status: json['status'] as int? ?? ProjectStatus.planned.index,
      grade: (json['grade'] as num?)?.toDouble(),
      participantIds: parseParticipantIds(json['participants']),
      participantsData: [],
      attachments: parseAttachments(json['attachments']),
      // Парсинг статистики из VIEW
      totalTasks: json['total_tasks'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      // Парсинг цвета
      color: json['color'] as String? ?? '0xFF2196F3', // <--
    );
  }

  // ------------------------------------------------
  // TO JSON
  // ------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'deadline': deadline.toUtc().toIso8601String(),
      'status': status,
      'grade': grade,
      'participants': participantIds,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'color': color, // <--
    };
  }

  // ------------------------------------------------
  // Фабрика для пустого проекта
  // ------------------------------------------------
  static ProjectModel createEmpty({required String ownerId}) {
    return ProjectModel(
      id: const Uuid().v4(),
      ownerId: ownerId,
      title: '',
      description: '',
      deadline: DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      participantIds: [ownerId],
      participantsData: [],
      attachments: [],
      createdAt: DateTime.now(),
      color: '0xFF2196F3', // <--
    );
  }
}