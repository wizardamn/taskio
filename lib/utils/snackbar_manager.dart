import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

enum SnackType {
  success,
  error,
  warning,
  info,
}

class SnackbarManager {

  /// Global ScaffoldMessenger key
  static final GlobalKey<ScaffoldMessengerState>
  messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  // =========================================================
  // PUBLIC API
  // =========================================================

  static void show(
      String message, {
        SnackType type = SnackType.info,
        Duration duration =
        const Duration(seconds: 3),
        String? actionLabel,
        VoidCallback? onAction,
        bool isLocalizedKey = true,
      }) {

    final messenger =
        messengerKey.currentState;

    if (messenger == null) return;

    // =====================================
    // EMPTY MESSAGE PROTECTION
    // =====================================

    if (message.trim().isEmpty) {
      return;
    }

    // =====================================
    // LOCALIZATION
    // =====================================

    final resolvedMessage =
    isLocalizedKey
        ? message.tr()
        : message;

    final resolvedAction =
    actionLabel?.tr();

    final config =
    _resolveType(type);

    // =====================================
    // HIDE CURRENT
    // =====================================

    messenger.hideCurrentSnackBar();

    // =====================================
    // SHOW
    // =====================================

    messenger.showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,

        duration: duration,

        margin: const EdgeInsets.all(16),

        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(14),
        ),

        backgroundColor:
        config.color,

        elevation: 6,

        content: Row(
          children: [

            // =========================
            // ICON
            // =========================

            Icon(
              config.icon,
              color: Colors.white,
              size: 20,
            ),

            const SizedBox(width: 12),

            // =========================
            // TEXT
            // =========================

            Expanded(
              child: Text(
                resolvedMessage,
                maxLines: 3,
                overflow:
                TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        // =============================
        // ACTION
        // =============================

        action: resolvedAction != null
            ? SnackBarAction(
          label: resolvedAction,
          textColor: Colors.white,
          onPressed:
          onAction ?? () {},
        )
            : null,
      ),
    );
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