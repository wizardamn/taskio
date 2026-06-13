import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  const ErrorMapper._();

  static String map(dynamic error) {
    if (error == null) {
      return 'errors.unknown'.tr();
    }

    if (error is AuthException) {
      return _mapAuthError(error);
    }

    if (error is PostgrestException) {
      return _mapDatabaseError(error);
    }

    if (error is StorageException) {
      return _mapStorageError(error);
    }

    final raw = error.toString().trim();

    final localization = _tryTranslateLocalizationKey(raw);

    if (localization != null) {
      return localization;
    }

    final message = raw.toLowerCase();

    if (message.contains('username_taken')) {
      return 'validation.username_taken'.tr();
    }

    if (message.contains('email not confirmed') ||
        message.contains('email_not_confirmed')) {
      return 'errors.email_not_confirmed'.tr();
    }

    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'errors.invalid_credentials'.tr();
    }

    if (message.contains('user already registered') ||
        message.contains('user already exists') ||
        message.contains('user_exists')) {
      return 'errors.user_exists'.tr();
    }

    if (message.contains('database error saving new user') ||
        message.contains('error saving new user')) {
      return 'errors.database_saving_user'.tr();
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return 'errors.network'.tr();
    }

    if (message.contains('timeout')) {
      return 'errors.timeout'.tr();
    }

    if (message.contains('permission') ||
        message.contains('row-level security') ||
        message.contains('42501')) {
      return 'errors.permission_denied'.tr();
    }

    if (message.contains('not authenticated')) {
      return 'errors.not_authenticated'.tr();
    }

    if (message.contains('not found')) {
      return 'errors.fetch_failed'.tr();
    }

    if (message.contains('duplicate key') ||
        message.contains('23505')) {
      return 'errors.duplicate'.tr();
    }

    if (message.contains('foreign key') ||
        message.contains('23503')) {
      return 'errors.foreign_key'.tr();
    }

    return 'errors.unknown'.tr();
  }

  // =========================================================
  // AUTH
  // =========================================================

  static String _mapAuthError(AuthException e) {
    final raw = e.message.trim();

    final localization = _tryTranslateLocalizationKey(raw);

    if (localization != null) {
      return localization;
    }

    final msg = raw.toLowerCase();

    if (msg.contains('username_taken')) {
      return 'validation.username_taken'.tr();
    }

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'errors.invalid_credentials'.tr();
    }

    if (msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return 'errors.email_not_confirmed'.tr();
    }

    if (msg.contains('user already registered') ||
        msg.contains('user already exists')) {
      return 'errors.user_exists'.tr();
    }

    if (msg.contains('invalid email')) {
      return 'errors.invalid_email'.tr();
    }

    if (msg.contains('weak password') ||
        msg.contains('password should')) {
      return 'errors.weak_password'.tr();
    }

    if (msg.contains('missing email') ||
        msg.contains('missing password')) {
      return 'errors.empty_credentials'.tr();
    }

    if (msg.contains('database error saving new user') ||
        msg.contains('error saving new user')) {
      return 'errors.database_saving_user'.tr();
    }

    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return 'errors.network'.tr();
    }

    if (msg.contains('timeout')) {
      return 'errors.timeout'.tr();
    }

    return 'errors.auth_failed'.tr();
  }

  // =========================================================
  // DATABASE
  // =========================================================

  static String _mapDatabaseError(
      PostgrestException e,
      ) {
    final raw = e.message.trim();

    final localization = _tryTranslateLocalizationKey(raw);

    if (localization != null) {
      return localization;
    }

    final msg = raw.toLowerCase();

    if (msg.contains('username_taken')) {
      return 'validation.username_taken'.tr();
    }

    if (msg.contains('duplicate key') ||
        msg.contains('23505')) {
      if (msg.contains('username') ||
          msg.contains('profiles_username')) {
        return 'validation.username_taken'.tr();
      }

      return 'errors.duplicate'.tr();
    }

    if (msg.contains('foreign key') ||
        msg.contains('23503')) {
      return 'errors.foreign_key'.tr();
    }

    if (msg.contains('permission denied') ||
        msg.contains('row-level security') ||
        msg.contains('42501')) {
      return 'errors.permission_denied'.tr();
    }

    if (msg.contains('not found')) {
      return 'errors.fetch_failed'.tr();
    }

    if (msg.contains('invalid input value for enum')) {
      return 'errors.database'.tr();
    }

    return 'errors.database'.tr();
  }

  // =========================================================
  // STORAGE
  // =========================================================

  static String _mapStorageError(
      StorageException e,
      ) {
    final raw = e.message.trim();

    final localization = _tryTranslateLocalizationKey(raw);

    if (localization != null) {
      return localization;
    }

    final msg = raw.toLowerCase();

    if (msg.contains('not found')) {
      return 'errors.file_not_found'.tr();
    }

    if (msg.contains('permission') ||
        msg.contains('row-level security') ||
        msg.contains('42501')) {
      return 'errors.permission_denied'.tr();
    }

    if (msg.contains('payload too large')) {
      return 'errors.storage'.tr();
    }

    return 'errors.storage'.tr();
  }

  // =========================================================
  // LOCALIZATION HELPERS
  // =========================================================

  static String? _tryTranslateLocalizationKey(String raw) {
    final clean = raw.trim();

    if (clean.isEmpty) {
      return null;
    }

    final directKey = _cleanLocalizationKey(clean);

    if (_isSupportedLocalizationKey(directKey)) {
      return directKey.tr();
    }

    final match = RegExp(
      r'(validation|errors|profile|projects|auth|attachments|notifications|chat)\.[a-zA-Z0-9_]+',
    ).firstMatch(clean);

    if (match == null) {
      return null;
    }

    final key = match.group(0);

    if (key == null || key.trim().isEmpty) {
      return null;
    }

    return key.tr();
  }

  static String _cleanLocalizationKey(String value) {
    var text = value.trim();

    if (text.startsWith('Exception:')) {
      text = text.replaceFirst('Exception:', '').trim();
    }

    if (text.startsWith('AuthException(message:')) {
      final match = RegExp(
        r'AuthException\(message:\s*([^,\)]+)',
      ).firstMatch(text);

      if (match != null) {
        text = match.group(1)?.trim() ?? text;
      }
    }

    return text;
  }

  static bool _isSupportedLocalizationKey(String value) {
    return value.startsWith('validation.') ||
        value.startsWith('errors.') ||
        value.startsWith('profile.') ||
        value.startsWith('projects.') ||
        value.startsWith('auth.') ||
        value.startsWith('attachments.') ||
        value.startsWith('notifications.') ||
        value.startsWith('chat.');
  }
}