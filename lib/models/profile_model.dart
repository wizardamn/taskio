import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  student,
  teacher,
  leader,
  general,
}

extension UserRoleExtension on UserRole {
  static UserRole fromString(String? value) {
    final normalized = value?.toLowerCase().trim();

    switch (normalized) {
      case 'student':
        return UserRole.student;

      case 'teacher':
        return UserRole.teacher;

      case 'leader':
      case 'team_lead':
      case 'teamlead':
      case 'lead':
        return UserRole.leader;

      case 'general':
      case 'user':
      case 'default':
        return UserRole.general;

      default:
        return UserRole.general;
    }
  }

  String get value => name;

  String localizedText() {
    switch (this) {
      case UserRole.student:
        return 'roles.student'.tr();

      case UserRole.teacher:
        return 'roles.teacher'.tr();

      case UserRole.leader:
        return 'roles.leader'.tr();

      case UserRole.general:
        return 'roles.general'.tr();
    }
  }
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

  /// Email берётся в основном из Supabase Auth.
  /// В таблице profiles его может не быть.
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
  // DISPLAY HELPERS
  // =========================================================

  String get displayName {
    final name = fullName.trim();

    if (name.isNotEmpty) {
      return name;
    }

    if (username.trim().isNotEmpty) {
      return '@$username';
    }

    if (email.trim().isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    return 'users.no_name'.tr();
  }

  String get displayUsername {
    final clean = username.trim();

    if (clean.isEmpty) {
      return '';
    }

    return clean.startsWith('@') ? clean : '@$clean';
  }

  String get roleText {
    return role.localizedText();
  }

  bool get hasAvatar {
    return avatarUrl != null && avatarUrl!.trim().isNotEmpty;
  }

  bool get hasEmail {
    return email.trim().isNotEmpty;
  }

  // =========================================================
  // FROM JSON
  // =========================================================

  factory ProfileModel.fromJson(
      Map<String, dynamic> json, {
        User? user,
      }) {
    final metadata = user?.userMetadata ?? {};

    final firstName = _firstNonEmpty([
      json['first_name'],
      metadata['first_name'],
    ]);

    final lastName = _firstNonEmpty([
      json['last_name'],
      metadata['last_name'],
    ]);

    final authEmail = user?.email?.trim() ?? '';

    final username = _normalizeUsername(
      _firstNonEmpty([
        json['username'],
        metadata['username'],
        authEmail.contains('@') ? authEmail.split('@').first : '',
      ]),
    );

    final generatedFullName = _buildFullName(
      firstName,
      lastName,
    );

    final fullName = _firstNonEmpty([
      json['full_name'],
      metadata['full_name'],
      generatedFullName,
      username,
    ]);

    final email = _firstNonEmpty([
      authEmail,
      json['email'],
      metadata['email'],
    ]);

    return ProfileModel(
      id: _firstNonEmpty([
        json['id'],
        user?.id,
      ]),
      username: username,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName.isNotEmpty ? fullName : 'users.no_name'.tr(),
      avatarUrl: _emptyToNull(
        json['avatar_url'] ?? metadata['avatar_url'],
      ),
      bio: _emptyToNull(
        json['bio'] ?? metadata['bio'],
      ),
      role: UserRoleExtension.fromString(
        _firstNonEmpty([
          json['role'],
          metadata['role'],
        ]),
      ),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      email: email,
      language: _emptyToNull(json['language']),
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
      'email': email,
      'language': language,
    };
  }

  /// Безопасный JSON именно для таблицы profiles.
  /// Email обычно хранится в Supabase Auth, поэтому здесь он не обязателен.
  Map<String, dynamic> toProfileJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'role': role.value,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'language': language,
    };
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  ProfileModel copyWith({
    String? id,
    String? username,
    String? firstName,
    String? lastName,
    String? fullName,
    String? avatarUrl,
    String? bio,
    UserRole? role,
    String? email,
    String? language,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: email ?? this.email,
      language: language ?? this.language,
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  static String? _emptyToNull(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static String _normalizeUsername(String value) {
    final username = value.trim();

    if (username.startsWith('@')) {
      return username.substring(1);
    }

    return username;
  }

  static String? _buildFullName(
      String first,
      String last,
      ) {
    final combined = '${first.trim()} ${last.trim()}'.trim();

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