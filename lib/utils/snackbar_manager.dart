import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

enum SnackType {
  success,
  error,
  warning,
  info,
}

class SnackbarManager {

  /// 🔥 один ключ на всё приложение
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  // =========================================================
  // PUBLIC API
  // =========================================================

  static void show(
      String message, {
        SnackType type = SnackType.info,
        Duration duration = const Duration(seconds: 3),
        String? actionLabel,
        VoidCallback? onAction,
        bool isLocalizedKey = true,
      }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    final resolvedMessage =
    isLocalizedKey ? message.tr() : message;

    final config = _resolveType(type);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                config.icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(resolvedMessage)),
            ],
          ),
          backgroundColor: config.color,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: actionLabel != null
              ? SnackBarAction(
            label: actionLabel.tr(),
            textColor: Colors.white,
            onPressed: onAction ?? () {},
          )
              : null,
        ),
      );
  }

  static void showSuccess(String message) =>
      show(message, type: SnackType.success);

  static void showError(String message) =>
      show(message, type: SnackType.error);

  static void showWarning(String message) =>
      show(message, type: SnackType.warning);

  static void showInfo(String message) =>
      show(message, type: SnackType.info);

  // =========================================================
  // INTERNAL
  // =========================================================

  static _SnackConfig _resolveType(SnackType type) {
    switch (type) {
      case SnackType.success:
        return _SnackConfig(
          color: Colors.green.shade600,
          icon: Icons.check_circle,
        );

      case SnackType.error:
        return _SnackConfig(
          color: Colors.red.shade600,
          icon: Icons.error,
        );

      case SnackType.warning:
        return _SnackConfig(
          color: Colors.orange.shade700,
          icon: Icons.warning,
        );

      case SnackType.info:
        return _SnackConfig(
          color: Colors.blue.shade600,
          icon: Icons.info,
        );
    }
  }
}

class _SnackConfig {
  final Color color;
  final IconData icon;

  const _SnackConfig({
    required this.color,
    required this.icon,
  });
}