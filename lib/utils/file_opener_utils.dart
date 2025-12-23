import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart'; // Для kIsWeb
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../services/supabase_service.dart';

class FileOpenerUtils {
  /// Скачивает файл из Supabase Storage и открывает его локально.
  /// Возвращает сообщение об ошибке или null, если все прошло успешно.
  static Future<String?> downloadAndOpen(String filePath, String fileName) async {
    // На Web файловая система недоступна таким образом.
    // Логика открытия ссылок для Web должна обрабатываться на уровне UI.
    if (kIsWeb) {
      return 'Открытие файлов в этом режиме не поддерживается. Используйте веб-просмотр.';
    }

    try {
      final String fullPublicUrl = SupabaseService.client.storage
          .from(SupabaseService.bucket)
          .getPublicUrl(filePath);

      // 1. Скачиваем файл
      final response = await http.get(Uri.parse(fullPublicUrl));
      if (response.statusCode != 200) {
        return 'Не удалось загрузить файл. Код: ${response.statusCode}';
      }

      // 2. Получаем временный каталог
      // ВАЖНО: Этот вызов упадет на Web, поэтому он должен быть строго после проверки kIsWeb
      final dir = await getTemporaryDirectory();

      // 3. Создаем локальный файл
      // Очищаем имя файла от недопустимых символов для безопасности ОС
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.\-]'), '_');
      final localPath = '${dir.path}/$safeFileName';
      final file = File(localPath);

      // 4. Записываем данные
      await file.writeAsBytes(response.bodyBytes);

      // 5. Открываем с помощью установленного приложения
      final result = await OpenFile.open(localPath);

      if (result.type != ResultType.done) {
        return 'Ошибка открытия: ${result.message}';
      }

      return null; // Успех
    } catch (e) {
      return 'Ошибка обработки файла: ${e.toString().replaceFirst('Exception: ', '')}';
    }
  }
}