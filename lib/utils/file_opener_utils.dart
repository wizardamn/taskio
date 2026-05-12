import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

    // =====================================================
    // WEB NOT SUPPORTED
    // =====================================================

    if (kIsWeb) {
      return 'errors.file_web_not_supported';
    }

    try {
      AppLogger.info(
        'Downloading file: $filePath',
        tag: 'FileOpener',
      );

      // =====================================================
      // DOWNLOAD
      // =====================================================

      final bytes = await SupabaseService
          .client
          .storage
          .from(SupabaseService.bucket)
          .download(filePath);

      if (bytes.isEmpty) {
        return 'errors.file_not_found';
      }

      // =====================================================
      // TEMP DIRECTORY
      // =====================================================

      final dir =
      await getTemporaryDirectory();

      // =====================================================
      // SAFE FILE NAME
      // =====================================================

      final safeFileName =
      _sanitizeFileName(fileName);

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

      final result =
      await OpenFile.open(localPath);

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

      return ErrorMapper.map(e);
    }
  }

  // =========================================================
  // SANITIZE FILE NAME
  // =========================================================

  static String _sanitizeFileName(
      String fileName,
      ) {

    // сохраняем кириллицу
    final sanitized = fileName.replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    );

    // защита от пустого имени
    if (sanitized.trim().isEmpty) {
      return 'file';
    }

    return sanitized;
  }
}