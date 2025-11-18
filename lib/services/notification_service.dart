import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Инициализация таймзон
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      // Разрешения запрашиваются здесь
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initializationSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initializationSettings);
  }

  /// Простое уведомление
  Future<void> showSimple(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Основной канал',
      channelDescription: 'Уведомления приложения',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  /// Плановое уведомление (например, напоминание о дедлайне)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Плановые уведомления',
      channelDescription: 'Напоминания о задачах и проектах',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Установка местного часового пояса (tz.local) для планового уведомления
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Удалить конкретное уведомление
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Удалить все уведомления
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

// ❌ Метод requestPermissions удален, так как он требовал
// импорта приватных типов (IOSFlutterLocalNotificationsPlugin)
// и разрешения уже запрашиваются в DarwinInitializationSettings.
}