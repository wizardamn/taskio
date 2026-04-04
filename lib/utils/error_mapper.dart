import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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

    // ==============================
    // GENERIC STRING MATCH
    // ==============================

    final message =
    error.toString().toLowerCase();

    if (message.contains('network')) {
      return 'errors.network'.tr();
    }

    if (message.contains('timeout')) {
      return 'errors.timeout'.tr();
    }

    if (message.contains('socket')) {
      return 'errors.network'.tr();
    }

    return 'errors.unknown'.tr();
  }

  // =========================================================
  // AUTH ERRORS
  // =========================================================

  static String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials')) {
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

    if (msg.contains('weak password')) {
      return 'errors.weak_password'.tr();
    }

    return 'errors.auth_failed'.tr();
  }

  // =========================================================
  // DATABASE ERRORS
  // =========================================================

  static String _mapDatabaseError(
      PostgrestException e) {

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

    return 'errors.database'.tr();
  }

  // =========================================================
  // STORAGE ERRORS
  // =========================================================

  static String _mapStorageError(
      StorageException e) {
    final msg =
    e.message.toLowerCase();

    if (msg.contains('not found')) {
      return 'errors.file_not_found'.tr();
    }

    if (msg.contains('permission')) {
      return 'errors.permission_denied'.tr();
    }

    return 'errors.storage'.tr();
  }
}