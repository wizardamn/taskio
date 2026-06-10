import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class FileOpenerUtils {
  /// Скачать файл из Supabase Storage и открыть.
  ///
  /// Возвращает:
  /// - null -> успех
  /// - String -> localization key ошибки
  static Future<String?> downloadAndOpen(
      String filePath,
      String fileName,
      ) async {
    final normalizedPath = _normalizeStoragePath(filePath);

    if (normalizedPath == null || normalizedPath.isEmpty) {
      return 'errors.file_not_found';
    }

    try {
      AppLogger.info(
        'Open file request: $normalizedPath',
        tag: 'FileOpener',
      );

      // =====================================================
      // WEB
      // =====================================================

      if (kIsWeb) {
        final publicUrl = _publicUrlFromPath(normalizedPath);

        return _openUrl(publicUrl);
      }

      // =====================================================
      // DIRECT URL
      // =====================================================

      if (_isHttpUrl(filePath)) {
        return _openUrl(filePath.trim());
      }

      // =====================================================
      // DOWNLOAD FROM SUPABASE STORAGE
      // =====================================================

      final bytes = await SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .download(normalizedPath);

      if (bytes.isEmpty) {
        return 'errors.file_not_found';
      }

      // =====================================================
      // TEMP DIRECTORY
      // =====================================================

      final dir = await getTemporaryDirectory();

      // =====================================================
      // SAFE FILE NAME
      // =====================================================

      final safeFileName = _sanitizeFileName(
        fileName,
        fallbackPath: normalizedPath,
      );

      final localPath = p.join(
        dir.path,
        safeFileName,
      );

      // =====================================================
      // WRITE FILE
      // =====================================================

      final file = File(localPath);

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      AppLogger.info(
        'File saved: $localPath',
        tag: 'FileOpener',
      );

      // =====================================================
      // OPEN FILE
      // =====================================================

      final result = await OpenFile.open(localPath);

      if (result.type != ResultType.done) {
        AppLogger.warning(
          'OpenFile error: ${result.message}',
          tag: 'FileOpener',
        );

        return 'errors.file_open_failed';
      }

      AppLogger.info(
        'File opened successfully',
        tag: 'FileOpener',
      );

      return null;
    } catch (e, st) {
      AppLogger.error(
        'File download/open error',
        error: e,
        stackTrace: st,
        tag: 'FileOpener',
      );

      final mapped = ErrorMapper.map(e);

      if (mapped.trim().isEmpty) {
        return 'errors.file_open_failed';
      }

      return mapped;
    }
  }

  /// Открыть файл напрямую по публичной ссылке.
  ///
  /// Можно использовать для Web или если файл уже хранится как URL.
  static Future<String?> openUrl(String url) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return 'errors.file_not_found';
    }

    return _openUrl(cleanUrl);
  }

  /// Получить публичную ссылку Supabase Storage по пути файла.
  static String? getPublicUrl(String filePath) {
    final normalizedPath = _normalizeStoragePath(filePath);

    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }

    return _publicUrlFromPath(normalizedPath);
  }

  // =========================================================
  // OPEN URL
  // =========================================================

  static Future<String?> _openUrl(String url) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return 'errors.file_not_found';
    }

    final uri = Uri.tryParse(cleanUrl);

    if (uri == null) {
      return 'errors.file_open_failed';
    }

    try {
      final canOpen = await canLaunchUrl(uri);

      if (!canOpen) {
        AppLogger.warning(
          'Cannot launch url: $cleanUrl',
          tag: 'FileOpener',
        );

        return 'errors.file_open_failed';
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      if (!launched) {
        return 'errors.file_open_failed';
      }

      return null;
    } catch (e, st) {
      AppLogger.error(
        'Open url error',
        error: e,
        stackTrace: st,
        tag: 'FileOpener',
      );

      return 'errors.file_open_failed';
    }
  }

  // =========================================================
  // PUBLIC URL
  // =========================================================

  static String _publicUrlFromPath(String filePath) {
    final normalizedPath = _normalizeStoragePath(filePath) ?? filePath;

    return SupabaseService.client.storage
        .from(SupabaseService.bucket)
        .getPublicUrl(normalizedPath);
  }

  // =========================================================
  // NORMALIZE STORAGE PATH
  // =========================================================

  static String? _normalizeStoragePath(String filePath) {
    var path = filePath.trim();

    if (path.isEmpty) {
      return null;
    }

    path = path.replaceAll('\\', '/');

    if (_isHttpUrl(path)) {
      final extracted = _extractStoragePathFromUrl(path);

      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }

      return path;
    }

    while (path.startsWith('/')) {
      path = path.substring(1);
    }

    final bucketPrefix = '${SupabaseService.bucket}/';

    if (path.startsWith(bucketPrefix)) {
      path = path.substring(bucketPrefix.length);
    }

    return path.trim().isEmpty ? null : path.trim();
  }

  static String? _extractStoragePathFromUrl(String url) {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return null;
    }

    final path = uri.path;

    final publicMarker =
        '/storage/v1/object/public/${SupabaseService.bucket}/';

    final signMarker =
        '/storage/v1/object/sign/${SupabaseService.bucket}/';

    if (path.contains(publicMarker)) {
      final result = path.split(publicMarker).last;

      return Uri.decodeComponent(result);
    }

    if (path.contains(signMarker)) {
      final result = path.split(signMarker).last;

      return Uri.decodeComponent(result);
    }

    return null;
  }

  static bool _isHttpUrl(String value) {
    final text = value.trim().toLowerCase();

    return text.startsWith('http://') || text.startsWith('https://');
  }

  // =========================================================
  // SANITIZE FILE NAME
  // =========================================================

  static String _sanitizeFileName(
      String fileName, {
        String? fallbackPath,
      }) {
    var name = fileName.trim();

    if (name.isEmpty && fallbackPath != null) {
      name = p.basename(fallbackPath);
    }

    if (name.isEmpty) {
      name = 'file';
    }

    // Сохраняем кириллицу, но убираем запрещённые символы.
    var sanitized = name.replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    );

    sanitized = sanitized.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    sanitized = sanitized.trim();

    if (sanitized.isEmpty) {
      sanitized = 'file';
    }

    // Защита от слишком длинного имени файла.
    if (sanitized.length > 180) {
      final extension = p.extension(sanitized);
      final baseName = p.basenameWithoutExtension(sanitized);

      final maxBaseLength = extension.isEmpty
          ? 180
          : 180 - extension.length;

      final safeBase = baseName.length > maxBaseLength
          ? baseName.substring(0, maxBaseLength)
          : baseName;

      sanitized = '$safeBase$extension';
    }

    return sanitized;
  }
}