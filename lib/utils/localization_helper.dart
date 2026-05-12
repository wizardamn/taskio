import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import '../utils/snackbar_manager.dart';

class LocalizationHelper {

  // =========================================================
  // CHANGE LANGUAGE
  // =========================================================

  static Future<void> changeLanguage(
      BuildContext context,
      String languageCode,
      ) async {

    try {

      final newLocale = Locale(languageCode);

      if (context.locale == newLocale) {
        return;
      }

      AppLogger.info(
        'Changing language to $languageCode',
        tag: 'Localization',
      );

      await context.setLocale(newLocale);

      final user =
          Supabase.instance.client.auth.currentUser;

      if (user != null) {

        try {

          await Supabase.instance.client
              .from('profiles')
              .update({
            'language': languageCode,
          })
              .eq('id', user.id);

        } catch (e, st) {

          AppLogger.error(
            'Failed to save language',
            error: e,
            stackTrace: st,
            tag: 'Localization',
          );
        }
      }

      if (context.mounted) {

        SnackbarManager.showSuccess(
          'language.changed'.tr(),
        );
      }

    } catch (e, st) {

      AppLogger.error(
        'changeLanguage error',
        error: e,
        stackTrace: st,
        tag: 'Localization',
      );

      if (context.mounted) {

        SnackbarManager.showError('errors.unknown'.tr(),);
      }
    }
  }

  // =========================================================
  // APPLY SAVED LANGUAGE
  // =========================================================

  static Future<void> applySavedLanguage(
      BuildContext context,
      String? languageCode,
      ) async {

    if (languageCode == null ||
        languageCode.isEmpty) {
      return;
    }

    final savedLocale = Locale(languageCode);

    if (context.locale == savedLocale) {
      return;
    }

    try {

      AppLogger.info(
        'Applying saved language: $languageCode',
        tag: 'Localization',
      );

      await context.setLocale(savedLocale);

    } catch (e, st) {

      AppLogger.error(
        'applySavedLanguage error',
        error: e,
        stackTrace: st,
        tag: 'Localization',
      );
    }
  }
}