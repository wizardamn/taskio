import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ----------------------------------------------------------------------
// 1. Модель участника проекта (для отображения имени)
// ----------------------------------------------------------------------
class ProjectParticipant {
  final String id;
  final String fullName; // Полное имя участника

  ProjectParticipant({required this.id, required this.fullName});

  // Фабрика для парсинга, если ProjectService обогащает данные
  factory ProjectParticipant.fromJson(Map<String, dynamic> json) {
    return ProjectParticipant(
      // ИСПРАВЛЕНО: Часто приходит как 'profile_id' из JOIN
      id: json['profile_id'] as String? ?? json['id'] as String,
      // Предполагаем, что полное имя хранится в 'full_name'
      fullName: json['full_name'] as String? ?? 'Неизвестный участник',
    );
  }
}

// ----------------------------------------------------------------------
// ENUM: СТАТУС ПРОЕКТА
// ----------------------------------------------------------------------
enum ProjectStatus {
  planned, // 0 - Запланирован
  inProgress, // 1 - В работе
  completed, // 2 - Завершен
  archived, // 3 - Архив
}

// ----------------------------------------------------------------------
// РАСШИРЕНИЕ ДЛЯ ОТОБРАЖЕНИЯ СТАТУСА И ЦВЕТА
// ----------------------------------------------------------------------
extension ProjectStatusExtension on ProjectStatus {
  // Возвращает русскую строку
  String get text {
    switch (this) {
      case ProjectStatus.planned:
        return 'Запланирован';
      case ProjectStatus.inProgress:
        return 'В работе';
      case ProjectStatus.completed:
        return 'Завершен';
      case ProjectStatus.archived:
        return 'Архив';
    }
  }

  // Возвращает цвет, ассоциированный со статусом
  Color get color {
    switch (this) {
      case ProjectStatus.planned:
        return Colors.blueGrey.shade400;
      case ProjectStatus.inProgress:
        return Colors.orange.shade600;
      case ProjectStatus.completed:
        return Colors.green.shade600;
      case ProjectStatus.archived:
        return Colors.brown.shade400;
    }
  }
}

// ----------------------------------------------------------------------
// МОДЕЛЬ ВЛОЖЕНИЯ (ATTACHMENT)
// ----------------------------------------------------------------------
class Attachment {
  final String fileName;
  final String filePath; // Путь в Supabase Storage
  final String mimeType;
  final DateTime uploadedAt;
  final String uploaderId;

  // Геттер для обратной совместимости
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
// МОДЕЛЬ ПРОЕКТА
// ----------------------------------------------------------------------
class ProjectModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final DateTime deadline;
  final int status; // Хранится как индекс enum для Supabase (0, 1, 2, 3)
  final double? grade;
  // Хранит список ID участников, как он приходит/отправляется в БД
  final List<String> participantIds;
  // Хранит обогащенный список объектов ProjectParticipant (для UI)
  final List<ProjectParticipant> participantsData;
  final List<Attachment> attachments;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
    this.grade,
    required this.participantIds,
    required this.participantsData,
    required this.attachments,
    required this.createdAt,
  });

  // Геттер для удобного доступа к статусу как к enum
  ProjectStatus get statusEnum {
    // Безопасная проверка: если индекс вне допустимого диапазона, возвращаем planned.
    if (status < 0 || status >= ProjectStatus.values.length) {
      return ProjectStatus.planned;
    }
    return ProjectStatus.values[status];
  }

  // Вспомогательный метод для получения локализованного статуса
  String getLocalizedStatus() {
    return statusEnum.text;
  }

  // ------------------------------------------------
  // COPY WITH (для иммутабельности и обновления)
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
    );
  }

  // ------------------------------------------------
  // FROM JSON (Десериализация из Supabase)
  // ------------------------------------------------
  factory ProjectModel.fromJson(Map<String, dynamic> json) {

    // Безопасное получение списка ID участников
    List<String> parseParticipantIds(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (json['participant_ids'] is List) {
        return (json['participant_ids'] as List).map((e) => e.toString()).toList();
      }
      return [];
    }

    // Десериализация списка вложений
    List<Attachment> parseAttachments(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map((e) => Attachment.fromJson(e))
            .toList();
      }
      return [];
    }

    return ProjectModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      // Преобразование строки ISO в DateTime
      deadline: DateTime.parse(json['deadline'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      // Статус должен быть int, по умолчанию ProjectStatus.planned (0)
      status: json['status'] as int? ?? ProjectStatus.planned.index,
      // Парсинг numeric в double
      grade: (json['grade'] as num?)?.toDouble(),
      // Записываем список ID из поля 'participants'
      participantIds: parseParticipantIds(json['participants']),
      // Изначально список объектов участников пуст
      participantsData: [],
      attachments: parseAttachments(json['attachments']),
    );
  }

  // ------------------------------------------------
  // TO JSON (Сериализация для Supabase)
  // ------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      // ID включается только при обновлении
      if (id.isNotEmpty) 'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      // Сохраняем в UTC для базы данных
      'deadline': deadline.toUtc().toIso8601String(),
      'status': status,
      // Сохраняем как double или null
      'grade': grade,
      // Используем 'participants' (согласно схеме) для отправки списка ID
      'participants': participantIds,
      // 'attachments' - это JSONB поле
      'attachments': attachments.map((a) => a.toJson()).toList(),
      // 'created_at' передается для полноты, хотя обычно устанавливается БД
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  // Добавление createEmpty для создания нового проекта
  static ProjectModel createEmpty({required String ownerId}) {
    return ProjectModel(
      id: const Uuid().v4(),
      ownerId: ownerId,
      title: '',
      description: '',
      deadline: DateTime.now().add(const Duration(days: 7)),
      status: ProjectStatus.planned.index,
      participantIds: [ownerId], // Владелец сразу в списке ID
      participantsData: [],
      attachments: [],
      createdAt: DateTime.now(),
    );
  }
}