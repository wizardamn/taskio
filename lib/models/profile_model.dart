import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileModel {
  final String id;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final String email;

  ProfileModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.createdAt,
    required this.email,
  });

  /// Фабричный конструктор для создания модели из данных 'profiles'.
  /// Требует объект User для получения email.
  factory ProfileModel.fromJson(Map<String, dynamic> json, User user) {
    // ✅ ИСПРАВЛЕНИЕ: Получаем роль из БД. Если нет в БД, берем из метаданных Auth.
    final String profileRole = json['role'] as String? ?? user.userMetadata?['role'] as String? ?? 'student';

    return ProfileModel(
      id: json['id'].toString(),
      // Берем имя из БД, fallback на имя из метаданных, затем email
      fullName: json['full_name'] as String? ?? user.userMetadata?['full_name'] as String? ?? user.email?.split('@').first ?? 'Неизвестно',
      // ✅ Используем роль, полученную из БД или метаданных
      role: profileRole,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      // Email берется из объекта User
      email: user.email ?? 'email-not-found@example.com',
    );
  }

  /// Преобразование модели обратно в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}