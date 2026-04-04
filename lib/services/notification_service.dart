import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance =
  NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // =========================================================
  // INIT
  // =========================================================

  Future<void> init() async {
    if (_initialized) return;

    try {
      AppLogger.info('Initializing NotificationService');

      tz.initializeTimeZones();

      const androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      final iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse:
            (response) async {
          AppLogger.info(
              'Notification clicked: ${response.payload}');
        },
      );

      // 🔥 Android 13+ permission (НОВЫЙ МЕТОД)
      if (!kIsWeb) {
        final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin
            ?.requestNotificationsPermission();
      }

      _initialized = true;

      AppLogger.info('NotificationService initialized');
    } catch (e, st) {
      AppLogger.error('Notification init error', e);
      AppLogger.error('StackTrace', st);
    }
  }

  // =========================================================
  // SIMPLE NOTIFICATION
  // =========================================================

  Future<void> showSimple(
      String title,
      String body, {
        String? payload,
      }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'main_channel',
        'Main notifications',
        channelDescription:
        'General app notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const iosDetails =
      DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        DateTime.now()
            .millisecondsSinceEpoch
            .remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );

      AppLogger.info('Simple notification shown');
    } catch (e, st) {
      AppLogger.error('showSimple error', e);
      AppLogger.error('StackTrace', st);
    }
  }

  // =========================================================
  // SCHEDULE NOTIFICATION
  // =========================================================

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Duration reminderOffset =
        Duration.zero,
    String? payload,
  }) async {
    try {
      const androidDetails =
      AndroidNotificationDetails(
        'scheduled_channel',
        'Scheduled notifications',
        channelDescription:
        'Deadline reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const iosDetails =
      DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final actualTime =
      scheduledTime.subtract(reminderOffset);

      final tzTime = tz.TZDateTime.from(
          actualTime, tz.local);

      if (tzTime.isBefore(
          tz.TZDateTime.now(tz.local))) {
        AppLogger.warning(
            'Notification time already passed');
        return;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode:
        AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation
            .absoluteTime,
        payload: payload,
      );

      AppLogger.info('Notification scheduled');
    } catch (e, st) {
      AppLogger.error(
          'scheduleNotification error', e);
      AppLogger.error('StackTrace', st);
    }
  }

  // =========================================================
  // CANCEL
  // =========================================================

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      AppLogger.info(
          'Notification cancelled: $id');
    } catch (e, st) {
      AppLogger.error(
          'cancel notification error', e);
      AppLogger.error('StackTrace', st);
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      AppLogger.info(
          'All notifications cancelled');
    } catch (e, st) {
      AppLogger.error('cancelAll error', e);
      AppLogger.error('StackTrace', st);
    }
  }
}