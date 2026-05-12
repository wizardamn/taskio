import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  student,
  teacher,
  general,
}

extension UserRoleExtension on UserRole {
  static UserRole fromString(String? value) {
    switch (value) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'general':
        return UserRole.general;
      default:
        return UserRole.general;
    }
  }

  String get value => name;
}

class ProfileModel {
  final String id;

  final String username;
  final String firstName;
  final String lastName;
  final String fullName;

  final String? avatarUrl;
  final String? bio;

  final UserRole role;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String email;
  final String? language;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.language,
  });

  // =========================================================
  // FROM JSON
  // =========================================================

  factory ProfileModel.fromJson(
      Map<String, dynamic> json, {
        User? user,
      }) {
    final metadata = user?.userMetadata ?? {};

    final firstName =
        json['first_name']?.toString() ??
            metadata['first_name']?.toString() ??
            '';

    final lastName =
        json['last_name']?.toString() ??
            metadata['last_name']?.toString() ??
            '';

    final fullName =
        json['full_name']?.toString() ??
            _buildFullName(firstName, lastName) ??
            metadata['full_name']?.toString() ??
            user?.email?.split('@').first ??
            'Unknown';

    return ProfileModel(
      id: json['id']?.toString() ?? user?.id ?? '',

      username:
      json['username']?.toString() ??
          metadata['username']?.toString() ??
          user?.email?.split('@').first ??
          '',

      firstName: firstName,
      lastName: lastName,
      fullName: fullName,

      avatarUrl:
      json['avatar_url']?.toString(),

      bio:
      json['bio']?.toString(),

      role: UserRoleExtension.fromString(
        json['role']?.toString() ??
            metadata['role']?.toString(),
      ),

      createdAt: _parseDate(
        json['created_at'],
      ),

      updatedAt: _parseDate(
        json['updated_at'],
      ),

      email:
      user?.email ??
          json['email']?.toString() ??
          'email-not-found@example.com',

      language:
      json['language']?.toString(),
    );
  }

  // =========================================================
  // TO JSON
  // =========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'role': role.value,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'language': language,
    };
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  ProfileModel copyWith({
    String? username,
    String? firstName,
    String? lastName,
    String? fullName,
    String? avatarUrl,
    String? bio,
    UserRole? role,
    String? email,
    String? language,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: email ?? this.email,
      language: language ?? this.language,
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static String? _buildFullName(
      String first,
      String last,
      ) {
    final combined =
    '${first.trim()} ${last.trim()}'.trim();

    if (combined.isEmpty) {
      return null;
    }

    return combined;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal() ??
        DateTime.now();
  }
}