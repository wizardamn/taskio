import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';

/// ============================================================
/// 1️⃣ PARTICIPANT
/// ============================================================

class ProjectParticipant {
  final String id;
  final String fullName;
  final String? role;

  const ProjectParticipant({
    required this.id,
    required this.fullName,
    this.role,
  });

  factory ProjectParticipant.fromJson(Map<String, dynamic> json) {
    return ProjectParticipant(
      id: (json['member_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'users.unknown'.tr()).toString(),
      role: json['role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'member_id': id,
    'full_name': fullName,
    'role': role,
  };
}

/// ============================================================
/// 2️⃣ STATUS ENUM
/// ============================================================

enum ProjectStatus {
  planned,
  inProgress,
  completed,
  archived,
}

extension ProjectStatusExtension on ProjectStatus {
  String localizedText(BuildContext context) {
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
/// 3️⃣ ATTACHMENT
/// ============================================================

class Attachment {
  final String fileName;
  final String filePath;
  final String mimeType;
  final DateTime uploadedAt;
  final String uploaderId;

  const Attachment({
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.uploadedAt,
    required this.uploaderId,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      uploadedAt: _safeDate(json['uploaded_at']),
      uploaderId: json['uploader_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'file_name': fileName,
    'file_path': filePath,
    'mime_type': mimeType,
    'uploaded_at': uploadedAt.toUtc().toIso8601String(),
    'uploader_id': uploaderId,
  };

  static DateTime _safeDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

/// ============================================================
/// 4️⃣ MAIN MODEL
/// ============================================================

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

  const ProjectModel({
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

  /// SAFE STATUS
  ProjectStatus get statusEnum {
    if (status < 0 || status >= ProjectStatus.values.length) {
      return ProjectStatus.planned;
    }
    return ProjectStatus.values[status];
  }

  /// PROGRESS
  double get progress {
    if (totalTasks == 0) return 0;
    return completedTasks / totalTasks;
  }

  /// SAFE COLOR
  Color get colorObj {
    try {
      return Color(int.parse(color));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  /// ============================================================
  /// FROM JSON (УНИВЕРСАЛЬНЫЙ И БЕЗОПАСНЫЙ)
  /// ============================================================

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      deadline: _safeDate(json['deadline']),
      status:
      (json['status'] as num?)?.toInt() ?? ProjectStatus.planned.index,
      grade: (json['grade'] as num?)?.toDouble(),
      participantIds: _parseParticipants(json),
      attachments: _parseAttachments(json['attachments']),
      createdAt: _safeDate(json['created_at']),
      totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
      completedTasks:
      (json['completed_tasks'] as num?)?.toInt() ?? 0,
      color: json['color']?.toString() ?? '0xFF2196F3',
    );
  }

  /// ============================================================
  /// ATTACHMENTS SAFE PARSER
  /// ============================================================

  static List<Attachment> _parseAttachments(dynamic raw) {
    if (raw == null) return [];

    try {
      if (raw is String) {
        raw = jsonDecode(raw);
      }

      if (raw is List) {
        return raw.map((e) {
          if (e is String) {
            return Attachment.fromJson(
                Map<String, dynamic>.from(jsonDecode(e)));
          } else if (e is Map) {
            return Attachment.fromJson(
                Map<String, dynamic>.from(e));
          }
          return null;
        }).whereType<Attachment>().toList();
      }
    } catch (_) {}

    return [];
  }

  static List<String> _parseParticipants(Map<String, dynamic> json) {
    final raw = json['participants'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// ============================================================
  /// TO JSON
  /// ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'deadline': deadline.toUtc().toIso8601String(),
      'status': status,
      'grade': grade,
      'participants': participantIds,
      'attachments':
      attachments.map((a) => a.toJson()).toList(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'color': color,
    };
  }

  /// COPY WITH
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
    String? color,
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
      participantsData:
      participantsData ?? this.participantsData,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks:
      completedTasks ?? this.completedTasks,
      color: color ?? this.color,
    );
  }

  static DateTime _safeDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ??
        DateTime.now();
  }

  static ProjectModel createEmpty({
    required String ownerId,
  }) {
    return ProjectModel(
      id: const Uuid().v4(),
      ownerId: ownerId,
      title: '',
      description: '',
      deadline:
      DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      participantIds: [ownerId],
      createdAt: DateTime.now(),
    );
  }
}