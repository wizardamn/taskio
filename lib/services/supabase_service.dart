import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static const String bucket = 'project-files';

  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  /// Получает ID и полные имена пользователей по списку ID.
  Future<List<Map<String, String>>> fetchUserNames(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      // ИСПРАВЛЕНО: Используем .filter вместо .inFilter
      final response = await client
          .from('profiles')
          .select('id, full_name')
          .filter('id', 'in', userIds);

      // response уже является List<Map<String, dynamic>>
      final namesMap = response.map((map) {
        return {
          'id': map['id'] as String,
          'full_name': (map['full_name'] as String?) ?? 'Без имени',
        };
      }).toList();

      return namesMap;
    } catch (error) {
      debugPrint('Ошибка при получении имен пользователей: $error');
      return [];
    }
  }

  Future<File?> downloadAttachment(String filePath, String fileName) async {
    try {
      final Uint8List bytes = await client.storage
          .from(bucket)
          .download(filePath);

      final tempDir = await getTemporaryDirectory();
      final safeFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${tempDir.path}/$safeFileName');

      await file.writeAsBytes(bytes);
      return file;
    } catch (error) {
      debugPrint('Ошибка при скачивании файла: $error');
      return null;
    }
  }
}