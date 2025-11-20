import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart'; // Нужен для downloadAttachment. Убедитесь, что 'path_provider' добавлен в pubspec.yaml!
import 'package:flutter/foundation.dart'; // Для debugPrint и Uint8List

// Универсальный сервис для работы с клиентом Supabase,
// инициализацией, профилями и файловым хранилищем.
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
    // Убедитесь, что файл .env находится в корне проекта и содержит SUPABASE_URL и SUPABASE_ANON_KEY.
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  // -------------------------------------------------------------------
  // ✅ 2. ПОЛУЧЕНИЕ ИМЕН ПОЛЬЗОВАТЕЛЕЙ (Оставлен для возможных будущих нужд)
  // -------------------------------------------------------------------
  /// Получает ID и полные имена пользователей по списку ID.
  Future<List<Map<String, String>>> fetchUserNames(List<String> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }

    try {
      final response = await client
          .from('profiles')
          .select('id, full_name') // Запрашиваем ID и ИМЯ
          .inFilter('id', userIds);

      // Преобразуем ответ в нужный формат: List<Map<String, String>>
      final namesMap = (response as List).map<Map<String, String>>((map) => {
        'id': map['id'] as String,
        'full_name': (map['full_name'] as String?) ?? 'Без имени',
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
  /// Скачивает файл из Supabase Storage и сохраняет его во временную папку.
  ///
  /// [filePath] - путь к файлу внутри бакета.
  /// [fileName] - имя файла для сохранения (включая расширение).
  Future<File?> downloadAttachment(String filePath, String fileName) async {
    try {
      // 1. Получаем байты файла из Supabase Storage
      // Uint8List теперь доступен через flutter/foundation.dart
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