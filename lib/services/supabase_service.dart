import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Универсальный сервис для работы с клиентом Supabase,
/// инициализацией, профилями и файловым хранилищем.
class SupabaseService {
  // Статический геттер для доступа к инициализированному клиенту
  static SupabaseClient get client => Supabase.instance.client;

  // Имя бакета для файлов
  static const String bucket = 'project-files';

  // ------------------------------------------------
  // ✅ 1. ИНИЦИАЛИЗАЦИЯ
  // ------------------------------------------------
  static Future<void> init() async {
    // Загружаем переменные окружения из .env
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  // -------------------------------------------------------------------
  // ✅ 2. ПОЛУЧЕНИЕ ИМЕН ПОЛЬЗОВАТЕЛЕЙ
  // -------------------------------------------------------------------
  /// Получает ID и полные имена пользователей по списку ID.
  Future<List<Map<String, String>>> fetchUserNames(List<String> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }

    try {
      // ИСПРАВЛЕНО: Используем .filter вместо .inFilter для совместимости с v2
      final response = await client
          .from('profiles')
          .select('id, full_name') // Запрашиваем ID и ИМЯ
          .filter('id', 'in', userIds);

      // ИСПРАВЛЕНО: Убран ненужный as List, так как response уже List
      final namesMap = response.map((map) {
        // ИСПРАВЛЕНО: Явно указываем тип String для 'id'
        return {
          'id': map['id'] as String,
          'full_name': (map['full_name'] as String?) ?? 'Без имени',
        };
      }).toList();

      return namesMap;
    } catch (error) {
      // Используем debugPrint, чтобы не мешать в production
      debugPrint('Ошибка при получении имен пользователей: $error');
      return [];
    }
  }

  // -------------------------------------------------------------------
  // ✅ 3. СКАЧИВАНИЕ ВЛОЖЕНИЯ
  // -------------------------------------------------------------------
  Future<File?> downloadAttachment(String filePath, String fileName) async {
    // На Web скачивание и сохранение в File не поддерживается напрямую через path_provider
    if (kIsWeb) {
      debugPrint('downloadAttachment: На Web используйте публичные ссылки для скачивания.');
      return null;
    }

    try {
      // 1. Получаем байты файла из Supabase Storage
      final Uint8List bytes = await client.storage
          .from(bucket)
          .download(filePath);

      // 2. Создаем временный файл для сохранения данных
      final tempDir = await getTemporaryDirectory();

      // Убеждаемся, что имя файла безопасно для пути, удаляя недопустимые символы.
      final safeFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${tempDir.path}/$safeFileName');

      // 3. Записываем полученные байты в файл
      await file.writeAsBytes(bytes);

      debugPrint('Файл успешно скачан и сохранен по пути: ${file.path}');
      return file;
    } on StorageException catch (e) {
      debugPrint('Ошибка Supabase Storage при скачивании файла: ${e.message}');
      return null;
    } catch (error) {
      debugPrint('Общая ошибка при скачивании файла: $error');
      return null;
    }
  }
}