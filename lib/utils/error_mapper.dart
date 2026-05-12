import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  static String map(dynamic error) {
    if (error == null) {
      return 'errors.unknown'.tr();
    }

    // ==============================
    // SUPABASE AUTH
    // ==============================

    if (error is AuthException) {
      return _mapAuthError(error);
    }

    // ==============================
    // SUPABASE DATABASE
    // ==============================

    if (error is PostgrestException) {
      return _mapDatabaseError(error);
    }

    // ==============================
    // SUPABASE STORAGE
    // ==============================

    if (error is StorageException) {
      return _mapStorageError(error);
    }

    final raw = error.toString();
    final message = raw.toLowerCase();

    // ==============================
    // LOCALIZATION KEYS
    // ==============================

    if (message.contains('errors.')) {
      final match = RegExp(r'errors\.[a-zA-Z0-9_]+')
          .firstMatch(raw);

      if (match != null) {
        return match.group(0)!.tr();
      }
    }

    // ==============================
    // GENERIC STRING MATCH
    // ==============================

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return 'errors.network'.tr();
    }

    if (message.contains('timeout')) {
      return 'errors.timeout'.tr();
    }

    if (message.contains('permission')) {
      return 'errors.permission_denied'.tr();
    }

    if (message.contains('not authenticated')) {
      return 'errors.not_authenticated'.tr();
    }

    if (message.contains('not found')) {
      return 'errors.fetch_failed'.tr();
    }

    return 'errors.unknown'.tr();
  }

  static String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'errors.invalid_credentials'.tr();
    }

    if (msg.contains('email not confirmed')) {
      return 'errors.email_not_confirmed'.tr();
    }

    if (msg.contains('user already registered')) {
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

    return 'errors.auth_failed'.tr();
  }

  static String _mapDatabaseError(
      PostgrestException e,
      ) {
    final msg = e.message.toLowerCase().trim();

    if (msg.contains('duplicate key')) {
      return 'errors.duplicate'.tr();
    }

    if (msg.contains('foreign key')) {
      return 'errors.foreign_key'.tr();
    }

    if (msg.contains('permission denied')) {
      return 'errors.permission_denied'.tr();
    }

    if (msg.contains('not found')) {
      return 'errors.fetch_failed'.tr();
    }

    return 'errors.database'.tr();
  }

  static String _mapStorageError(
      StorageException e,
      ) {
    final msg = e.message.toLowerCase();

    if (msg.contains('not found')) {
      return 'errors.file_not_found'.tr();
    }

    if (msg.contains('permission')) {
      return 'errors.permission_denied'.tr();
    }

    if (msg.contains('payload too large')) {
      return 'errors.storage'.tr();
    }

    return 'errors.storage'.tr();
  }
}