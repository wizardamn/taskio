import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class FileOpenerUtils {
  /// Скачивает файл из Supabase Storage и открывает его.
  /// Возвращает null при успехе или текст ошибки.
  static Future<String?> downloadAndOpen(
      String filePath,
      String fileName,
      ) async {
    if (kIsWeb) {
      return 'errors.file_web_not_supported';
    }

    try {
      AppLogger.info('Downloading file: $filePath');

      // 🔥 Используем download вместо publicUrl (работает и для private bucket)
      final bytes = await SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .download(filePath);

      if (bytes.isEmpty) {
        return 'errors.file_not_found';
      }

      final dir = await getTemporaryDirectory();

      final safeFileName =
      fileName.replaceAll(RegExp(r'[^\w\s\.\-]'), '_');

      final localPath = '${dir.path}/$safeFileName';

      final file = File(localPath);

      await file.writeAsBytes(bytes);

      AppLogger.info('File saved: $localPath');

      final result = await OpenFile.open(localPath);

      if (result.type != ResultType.done) {
        AppLogger.warning(
            'OpenFile error: ${result.message}');
        return result.message;
      }

      AppLogger.info('File opened successfully');

      return null;
    } catch (e, st) {
      AppLogger.error(
        'File download/open error',
        e,
        st,
      );

      return ErrorMapper.map(e);
    }
  }
}