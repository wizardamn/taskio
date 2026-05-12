import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final Map<String, String> _cache = {};

  /// ===========================
  /// TRANSLATE TEXT
  /// ===========================
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    if (text.trim().isEmpty) return text;

    final cacheKey = '$text|$targetLanguage';

    // 🔥 CACHE
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final url =
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx'
        '&sl=$sourceLanguage'
        '&tl=$targetLanguage'
        '&dt=t'
        '&q=${Uri.encodeComponent(text)}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final translated = data[0][0][0].toString();

        _cache[cacheKey] = translated;

        return translated;
      }

      throw Exception('translation_failed');
    } catch (e) {
      throw Exception('translation_failed');
    }
  }

  /// ===========================
  /// DETECT LANGUAGE
  /// ===========================
  Future<String> detectLanguage(String text) async {
    if (text.trim().isEmpty) return 'unknown';

    final url =
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx'
        '&sl=auto'
        '&tl=en'
        '&dt=t'
        '&q=${Uri.encodeComponent(text)}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data[2] ?? 'unknown';
      }

      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }
}