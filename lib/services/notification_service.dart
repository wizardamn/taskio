import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';

enum NotificationCategory {
  chat,
  projectUpdates,
  deadline,
}

class NotificationSettingsData {
  final bool allEnabled;
  final bool chatEnabled;
  final bool projectUpdatesEnabled;

  const NotificationSettingsData({
    required this.allEnabled,
    required this.chatEnabled,
    required this.projectUpdatesEnabled,
  });

  const NotificationSettingsData.defaults()
      : allEnabled = true,
        chatEnabled = true,
        projectUpdatesEnabled = true;

  NotificationSettingsData copyWith({
    bool? allEnabled,
    bool? chatEnabled,
    bool? projectUpdatesEnabled,
  }) {
    return NotificationSettingsData(
      allEnabled: allEnabled ?? this.allEnabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      projectUpdatesEnabled:
      projectUpdatesEnabled ?? this.projectUpdatesEnabled,
    );
  }

  bool allows(NotificationCategory category) {
    if (!allEnabled) {
      return false;
    }

    switch (category) {
      case NotificationCategory.chat:
        return chatEnabled;

      case NotificationCategory.projectUpdates:
      case NotificationCategory.deadline:
        return projectUpdatesEnabled;
    }
  }

  NotificationSettingsData mergeWithProject(
      NotificationSettingsData project,
      ) {
    return NotificationSettingsData(
      allEnabled: allEnabled && project.allEnabled,
      chatEnabled: chatEnabled && project.chatEnabled,
      projectUpdatesEnabled:
      projectUpdatesEnabled && project.projectUpdatesEnabled,
    );
  }

  factory NotificationSettingsData.fromJson(
      Map<String, dynamic>? json,
      ) {
    if (json == null) {
      return const NotificationSettingsData.defaults();
    }

    return NotificationSettingsData(
      allEnabled: json['all_enabled'] != false,
      chatEnabled: json['chat_enabled'] != false,
      projectUpdatesEnabled:
      json['project_updates_enabled'] != false,
    );
  }
}

class NotificationService {
  static final NotificationService _instance =
  NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static const String _settingsTable = 'notification_settings';

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  final SupabaseClient _client = SupabaseService.client;

  bool _initialized = false;
  Future<void>? _initializingFuture;

  final Map<String, NotificationSettingsData> _settingsCache = {};

  bool get _enabled => !kIsWeb;

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _isIOS {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _isMacOS {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  }

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

      const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const iosInit = DarwinInitializationSettings();

      const settings = InitializationSettings(
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
      if (_isAndroid || _isIOS || _isMacOS) {
        final dynamic timeZone =
        await FlutterTimezone.getLocalTimezone();

        final identifier = _extractTimezoneIdentifier(
          timeZone,
        );

        final normalized = _normalizeTimezoneIdentifier(
          identifier,
        );

        if (normalized == null) {
          tz.setLocalLocation(tz.UTC);
          return;
        }

        tz.setLocalLocation(
          tz.getLocation(normalized),
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

  String? _extractTimezoneIdentifier(dynamic timeZone) {
    if (timeZone == null) {
      return null;
    }

    if (timeZone is String) {
      return timeZone.trim();
    }

    try {
      final identifier = timeZone.identifier?.toString().trim();

      if (identifier != null && identifier.isNotEmpty) {
        return identifier;
      }
    } catch (_) {
      // ignore
    }

    final fallback = timeZone.toString().trim();

    return fallback.isEmpty ? null : fallback;
  }

  String? _normalizeTimezoneIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final timeZone = value.trim();

    if (timeZone == 'GMT' || timeZone == 'UTC') {
      return 'UTC';
    }

    return timeZone;
  }

  Future<void> _configurePermissions() async {
    if (!_enabled) {
      return;
    }

    if (_isAndroid) {
      final androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'main_channel',
            'Main notifications',
            description: 'General app notifications',
            importance: Importance.max,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'chat_channel',
            'Chat notifications',
            description: 'New chat message notifications',
            importance: Importance.max,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'project_updates_channel',
            'Project updates',
            description: 'Project changes and updates',
            importance: Importance.max,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'scheduled_channel',
            'Scheduled notifications',
            description: 'Deadline reminders',
            importance: Importance.max,
          ),
        );

        await androidPlugin.requestNotificationsPermission();
      }
    }

    if (_isIOS || _isMacOS) {
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
  // SETTINGS: PUBLIC GETTERS
  // =========================================================

  Future<NotificationSettingsData> getGlobalSettings({
    bool forceRefresh = false,
  }) async {
    return _getSettings(
      projectId: null,
      forceRefresh: forceRefresh,
    );
  }

  Future<NotificationSettingsData> getProjectSettings(
      String projectId, {
        bool forceRefresh = false,
      }) async {
    return _getSettings(
      projectId: projectId,
      forceRefresh: forceRefresh,
    );
  }

  Future<NotificationSettingsData> getEffectiveSettings({
    String? projectId,
    bool forceRefresh = false,
  }) async {
    final global = await getGlobalSettings(
      forceRefresh: forceRefresh,
    );

    if (projectId == null || projectId.trim().isEmpty) {
      return global;
    }

    final project = await getProjectSettings(
      projectId,
      forceRefresh: forceRefresh,
    );

    return global.mergeWithProject(project);
  }

  Future<bool> canShow({
    required NotificationCategory category,
    String? projectId,
  }) async {
    final settings = await getEffectiveSettings(
      projectId: projectId,
    );

    return settings.allows(category);
  }

  Future<bool> canShowChatNotification(String? projectId) {
    return canShow(
      category: NotificationCategory.chat,
      projectId: projectId,
    );
  }

  Future<bool> canShowProjectNotification(String? projectId) {
    return canShow(
      category: NotificationCategory.projectUpdates,
      projectId: projectId,
    );
  }

  Future<bool> canShowDeadlineNotification(String? projectId) {
    return canShow(
      category: NotificationCategory.deadline,
      projectId: projectId,
    );
  }

  // =========================================================
  // SETTINGS: PUBLIC SETTERS
  // =========================================================

  Future<void> setGlobalAllEnabled(bool value) async {
    await _saveSettings(
      projectId: null,
      allEnabled: value,
    );

    if (!value) {
      await cancelAll();
    }
  }

  Future<void> setGlobalChatEnabled(bool value) async {
    await _saveSettings(
      projectId: null,
      chatEnabled: value,
    );
  }

  Future<void> setGlobalProjectUpdatesEnabled(bool value) async {
    await _saveSettings(
      projectId: null,
      projectUpdatesEnabled: value,
    );

    if (!value) {
      await cancelAll();
    }
  }

  Future<void> setProjectAllEnabled({
    required String projectId,
    required bool value,
  }) async {
    await _saveSettings(
      projectId: projectId,
      allEnabled: value,
    );

    if (!value) {
      await cancel(
        _stableNotificationId(projectId),
      );
    }
  }

  Future<void> setProjectChatEnabled({
    required String projectId,
    required bool value,
  }) async {
    await _saveSettings(
      projectId: projectId,
      chatEnabled: value,
    );
  }

  Future<void> setProjectUpdatesEnabled({
    required String projectId,
    required bool value,
  }) async {
    await _saveSettings(
      projectId: projectId,
      projectUpdatesEnabled: value,
    );

    if (!value) {
      await cancel(
        _stableNotificationId(projectId),
      );
    }
  }

  void clearSettingsCache() {
    _settingsCache.clear();
  }

  // =========================================================
  // SETTINGS: INTERNAL
  // =========================================================

  String _cacheKey(String? projectId) {
    if (projectId == null || projectId.trim().isEmpty) {
      return 'global';
    }

    return 'project:${projectId.trim()}';
  }

  String? get _currentUserId {
    return _client.auth.currentUser?.id;
  }

  Future<NotificationSettingsData> _getSettings({
    required String? projectId,
    bool forceRefresh = false,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return const NotificationSettingsData.defaults();
    }

    final key = _cacheKey(projectId);

    if (!forceRefresh && _settingsCache.containsKey(key)) {
      return _settingsCache[key]!;
    }

    try {
      final raw = await _loadRawSettings(
        userId: userId,
        projectId: projectId,
      );

      final settings = NotificationSettingsData.fromJson(raw);

      _settingsCache[key] = settings;

      return settings;
    } catch (e, st) {
      AppLogger.error(
        'Load notification settings failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );

      return const NotificationSettingsData.defaults();
    }
  }

  Future<Map<String, dynamic>?> _loadRawSettings({
    required String userId,
    required String? projectId,
  }) async {
    var query = _client
        .from(_settingsTable)
        .select()
        .eq('user_id', userId);

    if (projectId == null || projectId.trim().isEmpty) {
      query = query.isFilter(
        'project_id',
        null,
      );
    } else {
      query = query.eq(
        'project_id',
        projectId.trim(),
      );
    }

    final response = await query.maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<void> _saveSettings({
    required String? projectId,
    bool? allEnabled,
    bool? chatEnabled,
    bool? projectUpdatesEnabled,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return;
    }

    final normalizedProjectId =
    projectId == null || projectId.trim().isEmpty
        ? null
        : projectId.trim();

    try {
      final current = await _getSettings(
        projectId: normalizedProjectId,
        forceRefresh: true,
      );

      final updated = current.copyWith(
        allEnabled: allEnabled,
        chatEnabled: chatEnabled,
        projectUpdatesEnabled: projectUpdatesEnabled,
      );

      final existing = await _loadRawSettings(
        userId: userId,
        projectId: normalizedProjectId,
      );

      final data = <String, dynamic>{
        'user_id': userId,
        'all_enabled': updated.allEnabled,
        'chat_enabled': updated.chatEnabled,
        'project_updates_enabled': updated.projectUpdatesEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (normalizedProjectId != null) {
        data['project_id'] = normalizedProjectId;
      }

      final existingId = existing?['id']?.toString();

      if (existingId != null && existingId.isNotEmpty) {
        await _client
            .from(_settingsTable)
            .update(data)
            .eq('id', existingId);
      } else {
        data['created_at'] =
            DateTime.now().toUtc().toIso8601String();

        await _client.from(_settingsTable).insert(data);
      }

      _settingsCache[_cacheKey(normalizedProjectId)] = updated;
    } catch (e, st) {
      AppLogger.error(
        'Save notification settings failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  // =========================================================
  // SIMPLE
  // =========================================================

  Future<void> showSimple(
      String title,
      String body, {
        String? payload,
        String? projectId,
        NotificationCategory category =
            NotificationCategory.projectUpdates,
        bool ignoreSettings = false,
      }) async {
    if (!_enabled) {
      return;
    }

    try {
      if (!ignoreSettings) {
        final allowed = await canShow(
          category: category,
          projectId: projectId,
        );

        if (!allowed) {
          AppLogger.info(
            'Notification skipped by settings',
            tag: 'NotificationService',
          );
          return;
        }
      }

      await _ensureInit();

      final details = _notificationDetailsForCategory(
        category,
      );

      final id =
      DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

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

  NotificationDetails _notificationDetailsForCategory(
      NotificationCategory category,
      ) {
    switch (category) {
      case NotificationCategory.chat:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_channel',
            'Chat notifications',
            channelDescription: 'New chat message notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        );

      case NotificationCategory.projectUpdates:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'project_updates_channel',
            'Project updates',
            channelDescription: 'Project changes and updates',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        );

      case NotificationCategory.deadline:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_channel',
            'Scheduled notifications',
            channelDescription: 'Deadline reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
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
    Duration reminderOffset = Duration.zero,
    String? payload,
    String? projectId,
    NotificationCategory category = NotificationCategory.deadline,
    bool ignoreSettings = false,
  }) async {
    if (!_enabled) {
      return;
    }

    try {
      if (!ignoreSettings) {
        final allowed = await canShow(
          category: category,
          projectId: projectId,
        );

        if (!allowed) {
          AppLogger.info(
            'Scheduled notification skipped by settings',
            tag: 'NotificationService',
          );
          return;
        }
      }

      await _ensureInit();

      final scheduleAt = scheduledTime.subtract(
        reminderOffset,
      );

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

      final details = _notificationDetailsForCategory(
        category,
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

    final allowed = await canShowDeadlineNotification(
      projectId,
    );

    if (!allowed) {
      await cancel(
        _stableNotificationId(projectId),
      );
      return;
    }

    final id = _stableNotificationId(projectId);

    await scheduleNotification(
      id: id,
      title: 'notifications.deadline_title'.tr(),
      body: '${'notifications.deadline_body'.tr()} $title',
      scheduledTime: deadline,
      reminderOffset: const Duration(hours: 1),
      payload: projectId,
      projectId: projectId,
      category: NotificationCategory.deadline,
    );
  }

  Future<void> scheduleProjects(
      List<ProjectModel> projects,
      ) async {
    if (!_enabled) {
      return;
    }

    await cancelAll();

    final globalSettings = await getGlobalSettings();

    if (!globalSettings.allows(
      NotificationCategory.deadline,
    )) {
      return;
    }

    for (final project in projects) {
      await scheduleProjectDeadline(
        projectId: project.id,
        title: project.title,
        deadline: project.deadline,
      );
    }
  }

  // =========================================================
  // CHAT NOTIFICATION
  // =========================================================

  Future<void> showChatNotification({
    required String projectId,
    required String projectTitle,
    required String senderName,
    required String message,
    String? payload,
  }) async {
    await showSimple(
      projectTitle,
      '$senderName: $message',
      payload: payload ?? projectId,
      projectId: projectId,
      category: NotificationCategory.chat,
    );
  }

  // =========================================================
  // PROJECT UPDATE NOTIFICATION
  // =========================================================

  Future<void> showProjectUpdateNotification({
    required String projectId,
    required String title,
    required String body,
    String? payload,
  }) async {
    await showSimple(
      title,
      body,
      payload: payload ?? projectId,
      projectId: projectId,
      category: NotificationCategory.projectUpdates,
    );
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

  Future<void> cancelProjectDeadline(String projectId) async {
    await cancel(
      _stableNotificationId(projectId),
    );
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