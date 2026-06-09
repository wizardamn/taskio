import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum SnackType {
  success,
  error,
  warning,
  info,
}

class SnackbarManager {
  /// Global ScaffoldMessenger key.
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
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = messengerKey.currentState;

      if (messenger == null || !messenger.mounted) {
        return;
      }

      final resolvedMessage = _resolveText(
        cleanMessage,
        isLocalizedKey: isLocalizedKey,
      );

      final resolvedAction = actionLabel == null
          ? null
          : _resolveText(
        actionLabel,
        isLocalizedKey: isLocalizedKey,
      );

      final config = _resolveType(type);

      try {
        messenger.clearSnackBars();
      } catch (_) {
        // ScaffoldMessenger мог быть пересоздан во время перехода экранов.
      }

      try {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: duration,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: config.color,
            elevation: 6,
            content: Row(
              children: [
                Icon(
                  config.icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    resolvedMessage,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            action: resolvedAction != null
                ? SnackBarAction(
              label: resolvedAction,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            )
                : null,
          ),
        );
      } catch (_) {
        // Защита от показа snackbar в момент уничтожения дерева виджетов.
      }
    });
  }

  // =========================================================
  // SHORTCUTS
  // =========================================================

  static void showSuccess(
      String message, {
        bool isLocalizedKey = true,
      }) {
    show(
      message,
      type: SnackType.success,
      isLocalizedKey: isLocalizedKey,
    );
  }

  static void showError(
      String message, {
        bool isLocalizedKey = true,
      }) {
    show(
      message,
      type: SnackType.error,
      isLocalizedKey: isLocalizedKey,
    );
  }

  static void showWarning(
      String message, {
        bool isLocalizedKey = true,
      }) {
    show(
      message,
      type: SnackType.warning,
      isLocalizedKey: isLocalizedKey,
    );
  }

  static void showInfo(
      String message, {
        bool isLocalizedKey = true,
      }) {
    show(
      message,
      type: SnackType.info,
      isLocalizedKey: isLocalizedKey,
    );
  }

  // =========================================================
  // LOCALIZATION
  // =========================================================

  static String _resolveText(
      String value, {
        required bool isLocalizedKey,
      }) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) {
      return cleanValue;
    }

    if (!isLocalizedKey) {
      return cleanValue;
    }

    if (!_looksLikeLocalizationKey(cleanValue)) {
      return cleanValue;
    }

    try {
      return cleanValue.tr();
    } catch (_) {
      return cleanValue;
    }
  }

  static bool _looksLikeLocalizationKey(String value) {
    return RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(value);
  }

  // =========================================================
  // INTERNAL
  // =========================================================

  static _SnackConfig _resolveType(
      SnackType type,
      ) {
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

// ===========================================================
// CONFIG
// ===========================================================

class _SnackConfig {
  final Color color;
  final IconData icon;

  const _SnackConfig({
    required this.color,
    required this.icon,
  });
}