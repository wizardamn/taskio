import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogger {
  /// Включать ли логи
  static bool enableLogs = kDebugMode;

  /// Минимальный уровень логов
  static LogLevel minLevel = LogLevel.debug;

  // =========================================================
  // PUBLIC METHODS
  // =========================================================

  static void debug(
      String message, {
        String? tag,
      }) {
    _log(
      LogLevel.debug,
      message,
      null,
      null,
      tag,
    );
  }

  static void info(
      String message, {
        String? tag,
      }) {
    _log(
      LogLevel.info,
      message,
      null,
      null,
      tag,
    );
  }

  static void warning(
      String message, {
        String? tag,
      }) {
    _log(
      LogLevel.warning,
      message,
      null,
      null,
      tag,
    );
  }

  static void error(
      String message, {
        dynamic error,
        StackTrace? stackTrace,
        String? tag,
      }) {
    _log(
      LogLevel.error,
      message,
      error,
      stackTrace,
      tag,
    );
  }

  // =========================================================
  // CORE LOGGER
  // =========================================================

  static void _log(
      LogLevel level,
      String message,
      dynamic error,
      StackTrace? stackTrace,
      String? tag,
      ) {
    if (!enableLogs) return;

    if (level.index < minLevel.index) {
      return;
    }

    final timestamp =
    DateTime.now().toIso8601String();

    final levelLabel =
    _levelLabel(level);

    final tagLabel =
    tag != null ? '[$tag]' : '';

    final logMessage =
        '[$timestamp] $levelLabel $tagLabel $message';

    _safePrint(logMessage);

    // =====================================
    // ERROR
    // =====================================

    if (error != null) {
      _safePrint(
        '   ↳ Error: ${error.toString()}',
      );
    }

    // =====================================
    // STACKTRACE
    // =====================================

    if (stackTrace != null) {
      _safePrint(
        '   ↳ StackTrace:\n$stackTrace',
      );
    }
  }

  // =========================================================
  // SAFE PRINT
  // =========================================================

  static void _safePrint(String text) {
    const chunkSize = 800;

    for (
    int i = 0;
    i < text.length;
    i += chunkSize
    ) {
      final end = (i + chunkSize < text.length)
          ? i + chunkSize
          : text.length;

      debugPrint(
        text.substring(i, end),
      );
    }
  }

  // =========================================================
  // LEVEL LABEL
  // =========================================================

  static String _levelLabel(
      LogLevel level,
      ) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';

      case LogLevel.info:
        return '[INFO]';

      case LogLevel.warning:
        return '[WARNING]';

      case LogLevel.error:
        return '[ERROR]';
    }
  }
}