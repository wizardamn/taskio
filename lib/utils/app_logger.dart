import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogger {
  static bool enableLogs = kDebugMode;

  // =========================================================
  // PUBLIC METHODS
  // =========================================================

  static void debug(String message) {
    _log(LogLevel.debug, message);
  }

  static void info(String message) {
    _log(LogLevel.info, message);
  }

  static void warning(String message) {
    _log(LogLevel.warning, message);
  }

  static void error(
      String message, [
        dynamic error,
        StackTrace? stackTrace,
      ]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  // =========================================================
  // CORE LOGGER
  // =========================================================

  static void _log(
      LogLevel level,
      String message, [
        dynamic error,
        StackTrace? stackTrace,
      ]) {
    if (!enableLogs) return;

    final timestamp =
    DateTime.now().toIso8601String();

    final levelLabel = _levelLabel(level);

    debugPrint(
      '[$timestamp] $levelLabel $message',
    );

    if (error != null) {
      debugPrint('   ↳ Details: $error');
    }

    if (stackTrace != null) {
      debugPrint('   ↳ StackTrace:\n$stackTrace');
    }
  }

  static String _levelLabel(LogLevel level) {
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