import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
  // GET GRADE
  // =========================================================

  Future<ProjectGrade?> getGrade(String projectId) async {
    if (projectId.trim().isEmpty) {
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
          .eq('project_id', projectId)
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
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    if (projectId.trim().isEmpty) {
      throw Exception('errors.project_not_found');
    }

    if (grade < 2 || grade > 5) {
      throw Exception('grades.invalid_grade');
    }

    try {
      final existing = await getGrade(projectId);

      final now = DateTime.now().toUtc();
      final cleanComment = comment?.trim();

      if (existing == null) {
        final id = const Uuid().v4();

        final row = {
          'id': id,
          'project_id': projectId,
          'graded_by': userId,
          'grade': grade,
          'comment':
          cleanComment == null || cleanComment.isEmpty
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

        return ProjectGrade.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      final data = await _client
          .from('project_grades')
          .update({
        'graded_by': userId,
        'grade': grade,
        'comment':
        cleanComment == null || cleanComment.isEmpty
            ? null
            : cleanComment,
        'updated_at': now.toIso8601String(),
      })
          .eq('id', existing.id)
          .select()
          .single();

      return ProjectGrade.fromJson(
        Map<String, dynamic>.from(data),
      );
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
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw Exception('errors.not_authenticated');
    }

    if (projectId.trim().isEmpty) {
      return;
    }

    try {
      await _client
          .from('project_grades')
          .delete()
          .eq('project_id', projectId);
    } catch (e, st) {
      _handleError(
        e,
        st,
        'grades.delete_error',
      );
    }
  }
}