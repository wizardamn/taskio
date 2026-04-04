import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileModel {
  final String id;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final String email;
  final String? language; // 🔥 новое поле

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.createdAt,
    required this.email,
    this.language,
  });

  // =========================================================
  // FROM JSON
  // =========================================================

  factory ProfileModel.fromJson(
      Map<String, dynamic> json,
      User user,
      ) {
    final roleFromDb =
    json['role'] as String?;

    final metadata =
        user.userMetadata ?? {};

    return ProfileModel(
      id: json['id'].toString(),

      fullName:
      json['full_name'] as String? ??
          metadata['full_name'] as String? ??
          user.email?.split('@').first ??
          'Unknown',

      role:
      roleFromDb ??
          metadata['role'] as String? ??
          'student',

      createdAt: _parseDate(
        json['created_at'],
      ),

      email:
      user.email ??
          'email-not-found@example.com',

      language:
      json['language'] as String?,
    );
  }

  // =========================================================
  // TO JSON
  // =========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'created_at':
      createdAt.toIso8601String(),
      'language': language,
    };
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  ProfileModel copyWith({
    String? fullName,
    String? role,
    String? email,
    String? language,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt,
      email: email ?? this.email,
      language: language ?? this.language,
    );
  }

  // =========================================================
  // SAFE DATE PARSER
  // =========================================================

  static DateTime _parseDate(
      dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
        value.toString()) ??
        DateTime.now();
  }
}