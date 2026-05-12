import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client =>
      Supabase.instance.client;

  static const String bucket =
      'project-files';

  // =========================================================
  // FETCH USER NAMES
  // =========================================================

  Future<List<Map<String, String>>> fetchUserNames(
      List<String> userIds,
      ) async {
    final ids = userIds
        .where(
          (id) => id.trim().isNotEmpty,
    )
        .toSet()
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    try {
      AppLogger.info(
        'Fetch user names (${ids.length})',
        tag: 'SupabaseService',
      );

      final response = await client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids);

      final data =
      List<Map<String, dynamic>>.from(
        response as List,
      );

      return data.map((item) {
        return {
          'id':
          item['id']?.toString() ?? '',
          'full_name':
          item['full_name']
              ?.toString()
              .trim()
              .isNotEmpty ==
              true
              ? item['full_name']
              .toString()
              : 'Unknown',
        };
      }).toList();
    } catch (e, st) {
      AppLogger.error(
        'fetchUserNames error',
        error: e,
        stackTrace: st,
        tag: 'SupabaseService',
      );

      return [];
    }
  }

  // =========================================================
  // DOWNLOAD ATTACHMENT
  // =========================================================

  Future<File?> downloadAttachment(
      String filePath,
      String fileName,
      ) async {
    if (kIsWeb) {
      AppLogger.warning(
        'downloadAttachment not supported on Web',
        tag: 'SupabaseService',
      );
      return null;
    }

    final cleanPath = filePath.trim();

    if (cleanPath.isEmpty) {
      AppLogger.warning(
        'downloadAttachment: empty file path',
        tag: 'SupabaseService',
      );
      return null;
    }

    try {
      AppLogger.info(
        'Download file: $fileName',
        tag: 'SupabaseService',
      );

      final Uint8List bytes =
      await client.storage
          .from(bucket)
          .download(cleanPath);

      if (bytes.isEmpty) {
        AppLogger.warning(
          'Downloaded file is empty',
          tag: 'SupabaseService',
        );
        return null;
      }

      final tempDir =
      await getTemporaryDirectory();

      String safeFileName = fileName
          .replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      )
          .trim();

      if (safeFileName.isEmpty) {
        safeFileName =
        'attachment_${DateTime.now().millisecondsSinceEpoch}';
      }

      final uniqueFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      final file = File(
        '${tempDir.path}/$uniqueFileName',
      );

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      AppLogger.info(
        'File saved at ${file.path}',
        tag: 'SupabaseService',
      );

      return file;
    } on StorageException catch (e, st) {
      AppLogger.error(
        'Storage download error',
        error: e,
        stackTrace: st,
        tag: 'SupabaseService',
      );

      return null;
    } catch (e, st) {
      AppLogger.error(
        'Download attachment error',
        error: e,
        stackTrace: st,
        tag: 'SupabaseService',
      );

      return null;
    }
  }
}