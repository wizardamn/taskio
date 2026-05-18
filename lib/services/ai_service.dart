import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AIService {
  static const Duration _requestTimeout =
  Duration(seconds: 10);

  final Map<String, String> _translateCache = {};
  final Map<String, String> _detectCache = {};

  // =========================================================
  // TRANSLATE TEXT
  // =========================================================

  Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return text;
    }

    final normalizedTarget =
    _normalizeLanguageCode(targetLanguage);

    final normalizedSource =
    _normalizeLanguageCode(sourceLanguage);

    final cacheKey =
        '$normalizedSource|$normalizedTarget|$trimmedText';

    if (_translateCache.containsKey(cacheKey)) {
      return _translateCache[cacheKey]!;
    }

    final uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      {
        'client': 'gtx',
        'sl': normalizedSource,
        'tl': normalizedTarget,
        'dt': 't',
        'q': trimmedText,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          'translation_failed_status_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      final translated =
      _extractTranslatedText(decoded);

      if (translated.trim().isEmpty) {
        throw Exception('translation_empty_result');
      }

      _translateCache[cacheKey] = translated;

      return translated;
    } on TimeoutException {
      throw Exception('translation_timeout');
    } catch (_) {
      throw Exception('translation_failed');
    }
  }

  // =========================================================
  // DETECT LANGUAGE
  // =========================================================

  Future<String> detectLanguage(
      String text,
      ) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return 'unknown';
    }

    if (_detectCache.containsKey(trimmedText)) {
      return _detectCache[trimmedText]!;
    }

    final uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      {
        'client': 'gtx',
        'sl': 'auto',
        'tl': 'en',
        'dt': 't',
        'q': trimmedText,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return 'unknown';
      }

      final decoded = jsonDecode(response.body);
      final language =
      _extractDetectedLanguage(decoded);

      _detectCache[trimmedText] = language;

      return language;
    } catch (_) {
      return 'unknown';
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _extractTranslatedText(
      dynamic decoded,
      ) {
    if (decoded is! List || decoded.isEmpty) {
      throw Exception('invalid_translation_response');
    }

    final sentences = decoded[0];

    if (sentences is! List || sentences.isEmpty) {
      throw Exception('invalid_translation_segments');
    }

    final buffer = StringBuffer();

    for (final segment in sentences) {
      if (segment is List &&
          segment.isNotEmpty &&
          segment[0] != null) {
        buffer.write(segment[0].toString());
      }
    }

    return buffer.toString();
  }

  String _extractDetectedLanguage(
      dynamic decoded,
      ) {
    if (decoded is List &&
        decoded.length > 2 &&
        decoded[2] != null) {
      final detected = decoded[2].toString().trim();

      if (detected.isNotEmpty) {
        return _normalizeLanguageCode(detected);
      }
    }

    return 'unknown';
  }

  String _normalizeLanguageCode(
      String value,
      ) {
    final code = value.trim().toLowerCase();

    if (code.isEmpty) {
      return 'auto';
    }

    if (code == 'auto' || code == 'unknown') {
      return code;
    }

    if (code.contains('_')) {
      return code.split('_').first;
    }

    if (code.contains('-')) {
      return code.split('-').first;
    }

    return code;
  }

  void clearCache() {
    _translateCache.clear();
    _detectCache.clear();
  }
}