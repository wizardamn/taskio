import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/project_model.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class ProjectGrade {
  final String id;
  final String projectId;
  final String gradedBy;
  final int grade;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectGrade({
    required this.id,
    required this.projectId,
    required this.gradedBy,
    required this.grade,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectGrade.fromJson(Map<String, dynamic> json) {
    return ProjectGrade(
      id: _stringSafe(json['id']),
      projectId: _stringSafe(json['project_id']),
      gradedBy: _stringSafe(json['graded_by']),
      grade: _parseGrade(json['grade']),
      comment: _emptyToNull(json['comment']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'graded_by': gradedBy,
      'grade': grade,
      'comment': comment,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String _stringSafe(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _emptyToNull(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static int _parseGrade(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return double.tryParse(value.toString())?.toInt() ?? 0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return DateTime.now();
    }

    return parsed.toLocal();
  }
}

class GradeService {
  final SupabaseClient _client = SupabaseService.client;

  final NotificationService _notifications = NotificationService();

  // =========================================================
  // ERROR
  // =========================================================

  Never _handleError(
      Object e,
      StackTrace st,
      String operation,
      ) {
    debugPrint('[GradeService] $operation: $e');

    Error.throwWithStackTrace(
      Exception('$operation: $e'),
      st,
    );
  }

  // =========================================================
  // CURRENT USER
  // =========================================================

  String? get _currentUserId {
    return _client.auth.currentUser?.id;
  }

  // =========================================================
  // PROJECT
  // =========================================================

  Future<ProjectModel?> _getProject(String projectId) async {
    final normalizedProjectId = projectId.trim();

    if (normalizedProjectId.isEmpty) {
      return null;
    }

    try {
      final data = await _client
          .from('projects_view')
          .select()
          .eq('id', normalizedProjectId)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return ProjectModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'project.load_error',
      );
    }
  }

  Future<ProjectModel> _requireProjectOwner(String projectId) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    final project = await _getProject(projectId);

    if (project == null) {
      throw Exception('errors.project_not_found');
    }

    if (project.ownerId != userId) {
      throw Exception('errors.no_permission');
    }

    return project;
  }

  // =========================================================
  // GET GRADE
  // =========================================================

  Future<ProjectGrade?> getGrade(String projectId) async {
    final normalizedProjectId = projectId.trim();

    if (normalizedProjectId.isEmpty) {
      return null;
    }

    try {
      final data = await _client
          .from('project_grades')
          .select(
        '''
            id,
            project_id,
            graded_by,
            grade,
            comment,
            created_at,
            updated_at
            ''',
      )
          .eq('project_id', normalizedProjectId)
          .order(
        'updated_at',
        ascending: false,
      )
          .limit(1)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return ProjectGrade.fromJson(
        Map<String, dynamic>.from(data),
      );
    } catch (e, st) {
      _handleError(
        e,
        st,
        'grades.load_error',
      );
    }
  }

  // =========================================================
  // SAVE / UPDATE GRADE
  // =========================================================

  Future<ProjectGrade> saveGrade({
    required String projectId,
    required int grade,
    String? comment,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    final normalizedProjectId = projectId.trim();

    if (normalizedProjectId.isEmpty) {
      throw Exception('errors.project_not_found');
    }

    if (grade < 2 || grade > 5) {
      throw Exception('grades.invalid_grade');
    }

    try {
      final project = await _requireProjectOwner(
        normalizedProjectId,
      );

      final existing = await getGrade(
        normalizedProjectId,
      );

      final now = DateTime.now().toUtc();

      final cleanComment = comment?.trim();

      ProjectGrade savedGrade;

      if (existing == null) {
        final id = const Uuid().v4();

        final row = {
          'id': id,
          'project_id': normalizedProjectId,
          'graded_by': userId,
          'grade': grade,
          'comment': cleanComment == null || cleanComment.isEmpty
              ? null
              : cleanComment,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final data = await _client
            .from('project_grades')
            .insert(row)
            .select()
            .single();

        savedGrade = ProjectGrade.fromJson(
          Map<String, dynamic>.from(data),
        );
      } else {
        final data = await _client
            .from('project_grades')
            .update({
          'graded_by': userId,
          'grade': grade,
          'comment': cleanComment == null || cleanComment.isEmpty
              ? null
              : cleanComment,
          'updated_at': now.toIso8601String(),
        })
            .eq('id', existing.id)
            .select()
            .single();

        savedGrade = ProjectGrade.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      await _notifications.notifyProjectGradedForMembers(
        project: project,
        grade: savedGrade.grade,
        senderId: userId,
      );

      return savedGrade;
    } catch (e, st) {
      _handleError(
        e,
        st,
        'grades.save_error',
      );
    }
  }

  // =========================================================
  // DELETE GRADE
  // =========================================================

  Future<void> deleteGrade(String projectId) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    final normalizedProjectId = projectId.trim();

    if (normalizedProjectId.isEmpty) {
      return;
    }

    try {
      await _requireProjectOwner(
        normalizedProjectId,
      );

      await _client
          .from('project_grades')
          .delete()
          .eq('project_id', normalizedProjectId);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'grades.delete_error',
      );
    }
  }
}