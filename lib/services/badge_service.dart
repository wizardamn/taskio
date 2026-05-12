import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger_plus/flutter_app_badger_plus.dart';

class BadgeService {
  static int _lastCount = -1;

  static Future<void> update(int count) async {
    try {
      if (kIsWeb) return;

      if (!(Platform.isAndroid || Platform.isIOS)) {
        return;
      }

      if (_lastCount == count) {
        return;
      }

      final supported =
      await FlutterAppBadgerPlus.isAppBadgeSupported();

      if (!supported) return;

      _lastCount = count;

      if (count <= 0) {
        await FlutterAppBadgerPlus.removeBadge();
      } else {
        await FlutterAppBadgerPlus.updateBadgeCount(count);
      }
    } catch (e) {
      debugPrint('BadgeService update error: $e');
    }
  }

  static Future<void> clear() async {
    try {
      if (kIsWeb) return;

      if (!(Platform.isAndroid || Platform.isIOS)) {
        return;
      }

      final supported =
      await FlutterAppBadgerPlus.isAppBadgeSupported();

      if (!supported) return;

      _lastCount = 0;

      await FlutterAppBadgerPlus.removeBadge();
    } catch (e) {
      debugPrint('BadgeService clear error: $e');
    }
  }
}