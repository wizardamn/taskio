import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/project_model.dart';
import '../utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance =
  NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initializingFuture;

  bool get _enabled => !kIsWeb;

  // =========================================================
  // INIT
  // =========================================================

  Future<void> init() async {
    if (!_enabled) {
      AppLogger.warning(
        'Notifications disabled on Web',
        tag: 'NotificationService',
      );
      return;
    }

    if (_initialized) {
      return;
    }

    if (_initializingFuture != null) {
      await _initializingFuture;
      return;
    }

    _initializingFuture = _initInternal();

    await _initializingFuture;
  }

  Future<void> _initInternal() async {
    try {
      AppLogger.info(
        'Initializing NotificationService',
        tag: 'NotificationService',
      );

      tz.initializeTimeZones();

      await _configureTimezone();

      const androidInit =
      AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const iosInit =
      DarwinInitializationSettings();

      const settings =
      InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: iosInit,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) async {
          AppLogger.info(
            'Notification clicked: ${response.payload}',
            tag: 'NotificationService',
          );
        },
      );

      await _configurePermissions();

      _initialized = true;

      AppLogger.info(
        'NotificationService initialized',
        tag: 'NotificationService',
      );
    } catch (e, st) {
      AppLogger.error(
        'Notification init error',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    } finally {
      _initializingFuture = null;
    }
  }

  Future<void> _configureTimezone() async {
    try {
      if (!kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isMacOS)) {
        final timeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(
          tz.getLocation(timeZone.identifier),
        );
      } else {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e, st) {
      AppLogger.warning(
        'Timezone fallback: $e',
        tag: 'NotificationService',
      );

      AppLogger.error(
        'Timezone config error',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );

      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _configurePermissions() async {
    if (!_enabled) {
      return;
    }

    if (Platform.isAndroid) {
      final androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin
            .createNotificationChannel(
          const AndroidNotificationChannel(
            'main_channel',
            'Main notifications',
            description:
            'General app notifications',
            importance: Importance.max,
          ),
        );

        await androidPlugin
            .createNotificationChannel(
          const AndroidNotificationChannel(
            'scheduled_channel',
            'Scheduled notifications',
            description:
            'Deadline reminders',
            importance: Importance.max,
          ),
        );

        await androidPlugin
            .requestNotificationsPermission();
      }
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      final macPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();

      await macPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> _ensureInit() async {
    if (!_enabled) {
      return;
    }

    if (!_initialized) {
      await init();
    }

    if (!_initialized) {
      throw Exception(
        'NotificationService init failed',
      );
    }
  }

  int _stableNotificationId(String input) {
    return input.hashCode & 0x7fffffff;
  }

  // =========================================================
  // SIMPLE
  // =========================================================

  Future<void> showSimple(
      String title,
      String body, {
        String? payload,
      }) async {
    if (!_enabled) {
      return;
    }

    try {
      await _ensureInit();

      const details =
      NotificationDetails(
        android: AndroidNotificationDetails(
          'main_channel',
          'Main notifications',
          channelDescription:
          'General app notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      final id =
      DateTime.now().millisecondsSinceEpoch &
      0x7fffffff;

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e, st) {
      AppLogger.error(
        'showSimple error',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  // =========================================================
  // SCHEDULE
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
    if (!_enabled) {
      return;
    }

    try {
      await _ensureInit();

      final scheduleAt =
      scheduledTime.subtract(reminderOffset);

      final tzTime = tz.TZDateTime.from(
        scheduleAt,
        tz.local,
      );

      if (tzTime.isBefore(
        tz.TZDateTime.now(tz.local),
      )) {
        AppLogger.warning(
          'Notification time already passed',
          tag: 'NotificationService',
        );
        return;
      }

      const details =
      NotificationDetails(
        android:
        AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled notifications',
          channelDescription:
          'Deadline reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode:
        AndroidScheduleMode.exactAllowWhileIdle,
      );

      AppLogger.info(
        'Notification scheduled',
        tag: 'NotificationService',
      );
    } catch (e, st) {
      AppLogger.error(
        'scheduleNotification error',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  // =========================================================
  // PROJECT DEADLINES
  // =========================================================

  Future<void> scheduleProjectDeadline({
    required String projectId,
    required String title,
    required DateTime deadline,
  }) async {
    if (!_enabled) {
      return;
    }

    if (deadline.isBefore(DateTime.now())) {
      return;
    }

    final id =
    _stableNotificationId(projectId);

    await scheduleNotification(
      id: id,
      title:
      'notifications.deadline_title'.tr(),
      body:
      '${'notifications.deadline_body'.tr()} $title',
      scheduledTime: deadline,
      reminderOffset:
      const Duration(hours: 1),
      payload: projectId,
    );
  }

  Future<void> scheduleProjects(
      List<ProjectModel> projects) async {
    if (!_enabled) {
      return;
    }

    await cancelAll();

    for (final project in projects) {
      await scheduleProjectDeadline(
        projectId: project.id,
        title: project.title,
        deadline: project.deadline,
      );
    }
  }

  // =========================================================
  // CANCEL
  // =========================================================

  Future<void> cancel(int id) async {
    if (!_enabled) {
      return;
    }

    try {
      await _ensureInit();
      await _plugin.cancel(id: id);
    } catch (e, st) {
      AppLogger.error(
        'cancel error',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_enabled) {
      return;
    }

    try {
      await _ensureInit();
      await _plugin.cancelAll();
    } catch (e, st) {
      AppLogger.error(
        'cancelAll error',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }
}