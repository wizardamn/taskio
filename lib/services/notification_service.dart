import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Инициализация таймзон для плановых уведомлений
    tz.initializeTimeZones();

    // Настройка для Android
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Настройка для iOS
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

    // Инициализация плагина.
    // onDidReceiveNotificationResponse необходим для обработки нажатий на уведомления.
    await _plugin.initialize(
      initializationSettings,
      // Placeholder для обработки нажатия на уведомление (необходимо для инициализации)
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Здесь можно обработать ответ: например, перейти на нужный экран
        if (response.payload != null) {
          // Выполнить навигацию или другие действия
        }
      },
    );
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
    // Смещение напоминания перед scheduledTime (по умолчанию — 0)
    Duration reminderOffset = Duration.zero,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Плановые уведомления',
      channelDescription: 'Напоминания о задачах и проектах',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 1. ВЫЧИСЛЕНИЕ ВРЕМЕНИ:
    // Отнимаем offset (смещение) от scheduledTime (дедлайна)
    final actualScheduleTime = scheduledTime.subtract(reminderOffset);

    // 2. Установка местного часового пояса (tz.local) для планового уведомления
    final tzTime = tz.TZDateTime.from(actualScheduleTime, tz.local);

    // 3. Проверка: не планируем, если время уже прошло
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      notificationDetails,
      // ✅ Исправлено: замена androidAllowWhileIdle на androidScheduleMode
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      // payload может быть добавлен для передачи данных при нажатии
      // payload: 'project_id_$id',
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
}