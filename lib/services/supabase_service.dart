import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class SupabaseService {
  /// 🔥 Используем уже инициализированный клиент
  static SupabaseClient get client =>
      Supabase.instance.client;

  static const String bucket = 'project-files';

  // =========================================================
  // FETCH USER NAMES
  // =========================================================

  Future<List<Map<String, String>>> fetchUserNames(
      List<String> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }

    try {
      AppLogger.info(
          '[SupabaseService] Fetch user names');

      final response = await client
          .from('profiles')
          .select('id, full_name')
          .filter('id', 'in', userIds);

      return response.map<Map<String, String>>((map) {
        return {
          'id': map['id'] as String,
          'full_name':
          (map['full_name'] as String?) ??
              'No name',
        };
      }).toList();
    } catch (e, st) {
      AppLogger.error(
          'fetchUserNames error', e);
      AppLogger.error('StackTrace', st);

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
          'downloadAttachment not supported on Web');
      return null;
    }

    try {
      AppLogger.info(
          '[SupabaseService] Download file $fileName');

      final Uint8List bytes =
      await client.storage
          .from(bucket)
          .download(filePath);

      final tempDir =
      await getTemporaryDirectory();

      final safeFileName =
      fileName.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_');

      final file =
      File('${tempDir.path}/$safeFileName');

      await file.writeAsBytes(bytes);

      AppLogger.info(
          'File saved at ${file.path}');

      return file;
    } on StorageException catch (e, st) {
      AppLogger.error(
          'Storage download error', e);
      AppLogger.error('StackTrace', st);
      return null;
    } catch (e, st) {
      AppLogger.error(
          'Download attachment error', e);
      AppLogger.error('StackTrace', st);
      return null;
    }
  }
}