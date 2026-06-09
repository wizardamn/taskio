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
      projectUpdatesEnabled: json['project_updates_enabled'] != false,
    );
  }
}

class ProjectNotificationData {
  final String id;
  final String? projectId;
  final String recipientId;
  final String? senderId;
  final String type;
  final String title;
  final String body;
  final String? projectTitle;
  final bool isRead;
  final DateTime createdAt;

  const ProjectNotificationData({
    required this.id,
    required this.projectId,
    required this.recipientId,
    required this.senderId,
    required this.type,
    required this.title,
    required this.body,
    required this.projectTitle,
    required this.isRead,
    required this.createdAt,
  });

  static String _stringValue(
      Map<String, dynamic> json,
      String key,
      ) {
    return json[key]?.toString().trim() ?? '';
  }

  static String? _nullableStringValue(
      Map<String, dynamic> json,
      String key,
      ) {
    final value = json[key]?.toString().trim();

    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }

    return value;
  }

  factory ProjectNotificationData.fromJson(
      Map<String, dynamic> json,
      ) {
    return ProjectNotificationData(
      id: _stringValue(json, 'id'),
      projectId: _nullableStringValue(json, 'project_id'),
      recipientId: _stringValue(json, 'recipient_id'),
      senderId: _nullableStringValue(json, 'sender_id'),
      type: _stringValue(json, 'type'),
      title: _stringValue(json, 'title'),
      body: _stringValue(json, 'body'),
      projectTitle: _nullableStringValue(json, 'project_title'),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      ) ??
          DateTime.now(),
    );
  }
}

class NotificationService {
  static final NotificationService _instance =
  NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static const String _settingsTable = 'notification_settings';
  static const String _notificationsTable = 'project_notifications';

  static const String _mainChannelId = 'main_channel';
  static const String _chatChannelId = 'chat_channel';
  static const String _projectUpdatesChannelId =
      'project_updates_channel';
  static const String _scheduledChannelId = 'scheduled_channel';

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

  String? get _currentUserId {
    return _client.auth.currentUser?.id;
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
        final dynamic timeZone = await FlutterTimezone.getLocalTimezone();

        final identifier = _extractTimezoneIdentifier(
          timeZone,
        );

        final normalized = _normalizeTimezoneIdentifier(
          identifier,
        );

        if (normalized == null || normalized == 'UTC') {
          tz.setLocalLocation(tz.UTC);
          return;
        }

        try {
          tz.setLocalLocation(
            tz.getLocation(normalized),
          );
        } catch (_) {
          tz.setLocalLocation(tz.UTC);
        }
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

    if (timeZone == 'GMT' ||
        timeZone == 'UTC' ||
        timeZone == 'Etc/UTC' ||
        timeZone == 'Etc/GMT') {
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
            _mainChannelId,
            'Main notifications',
            description: 'General app notifications',
            importance: Importance.max,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _chatChannelId,
            'Chat notifications',
            description: 'New chat message notifications',
            importance: Importance.max,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _projectUpdatesChannelId,
            'Project updates',
            description: 'Project changes and updates',
            importance: Importance.max,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _scheduledChannelId,
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
  // LOCALIZED TEXT HELPERS
  // =========================================================

  String _safeTr(
      String key, {
        Map<String, String>? namedArgs,
        String? fallback,
      }) {
    try {
      final translated = key.tr(
        namedArgs: namedArgs,
      );

      if (translated.trim().isEmpty || translated == key) {
        return fallback ?? key;
      }

      return translated;
    } catch (_) {
      return fallback ?? key;
    }
  }

  String _projectTitleOrFallback(String? projectTitle) {
    final title = projectTitle?.trim();

    if (title != null && title.isNotEmpty) {
      return title;
    }

    return _safeTr(
      'notifications.project',
      fallback: 'Project',
    );
  }

  String localizedTitleForType(
      String type, {
        String? fallback,
      }) {
    switch (type.trim()) {
      case 'project_created':
        return _safeTr(
          'notifications.project_created_title',
          fallback: fallback ?? 'Project created',
        );

      case 'project_updated':
        return _safeTr(
          'notifications.project_updated_title',
          fallback: fallback ?? 'Project updated',
        );

      case 'project_deleted':
        return _safeTr(
          'notifications.project_deleted_title',
          fallback: fallback ?? 'Project deleted',
        );

      case 'project_completed':
        return _safeTr(
          'notifications.project_completed_title',
          fallback: fallback ?? 'Project completed',
        );

      case 'project_graded':
        return _safeTr(
          'notifications.project_graded_title',
          fallback: fallback ?? 'Grade assigned',
        );

      case 'member_invited':
        return _safeTr(
          'notifications.member_invited_title',
          fallback: fallback ?? 'Project invitation',
        );

      case 'member_invite_accepted':
        return _safeTr(
          'notifications.member_invite_accepted_title',
          fallback: fallback ?? 'Invitation accepted',
        );

      case 'member_invite_declined':
        return _safeTr(
          'notifications.member_invite_declined_title',
          fallback: fallback ?? 'Invitation declined',
        );

      case 'file_uploaded':
      case 'file_added':
        return _safeTr(
          'notifications.file_added_title',
          fallback: fallback ?? 'File added',
        );

      case 'deadline':
      case 'deadline_soon':
        return _safeTr(
          'notifications.deadline_title',
          fallback: fallback ?? 'Deadline soon',
        );

      case 'new_message':
      case 'chat_message':
        return _safeTr(
          'notifications.new_message_title',
          fallback: fallback ?? 'New message',
        );

      case 'task_created':
        return _safeTr(
          'notifications.task_created_title',
          fallback: fallback ?? 'New task',
        );

      case 'task_completed':
        return _safeTr(
          'notifications.task_completed_title',
          fallback: fallback ?? 'Task completed',
        );

      default:
        return fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : _safeTr(
          'notifications.title',
          fallback: 'Notifications',
        );
    }
  }

  String localizedBodyForType(
      String type, {
        String? projectTitle,
        String? grade,
        String? fallback,
      }) {
    final project = _projectTitleOrFallback(projectTitle);

    switch (type.trim()) {
      case 'project_created':
        return _safeTr(
          'notifications.project_created_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'Project "$project" created',
        );

      case 'project_updated':
        return _safeTr(
          'notifications.project_updated_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'Project "$project" was updated',
        );

      case 'project_deleted':
        return _safeTr(
          'notifications.project_deleted_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'Project "$project" deleted',
        );

      case 'project_completed':
        return _safeTr(
          'notifications.project_completed_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'Project "$project" has been completed',
        );

      case 'project_graded':
        return _safeTr(
          'notifications.project_graded_body',
          namedArgs: {
            'project': project,
            'grade': grade ?? '',
          },
          fallback: fallback ?? 'Project "$project" received grade: $grade',
        );

      case 'member_invited':
        return _safeTr(
          'notifications.member_invited_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'You have been invited to project "$project"',
        );

      case 'member_invite_accepted':
        return _safeTr(
          'notifications.member_invite_accepted_body',
          namedArgs: {
            'project': project,
          },
          fallback:
          fallback ?? 'A user accepted the invitation to project "$project"',
        );

      case 'member_invite_declined':
        return _safeTr(
          'notifications.member_invite_declined_body',
          namedArgs: {
            'project': project,
          },
          fallback:
          fallback ?? 'A user declined the invitation to project "$project"',
        );

      case 'file_uploaded':
      case 'file_added':
        return _safeTr(
          'notifications.file_added_body',
          fallback: fallback ?? 'A file was added to the project',
        );

      case 'deadline':
      case 'deadline_soon':
        return '${_safeTr(
          'notifications.deadline_body',
          fallback: 'Project is ending:',
        )} $project';

      case 'new_message':
      case 'chat_message':
        return _safeTr(
          'notifications.new_message_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'New message in project "$project"',
        );

      case 'task_created':
        return _safeTr(
          'notifications.task_created_body',
          namedArgs: {
            'project': project,
          },
          fallback: fallback ?? 'A new task was added to project "$project"',
        );

      case 'task_completed':
        return _safeTr(
          'notifications.task_completed_body',
          namedArgs: {
            'project': project,
          },
          fallback:
          fallback ?? 'A task in project "$project" was marked as completed',
        );

      default:
        return fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : _safeTr(
          'notifications.title',
          fallback: 'Notifications',
        );
    }
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

  Future<void> setProjectNotificationsEnabled({
    required String projectId,
    required bool value,
  }) async {
    final normalizedProjectId = projectId.trim();

    if (normalizedProjectId.isEmpty) {
      return;
    }

    await _saveSettings(
      projectId: normalizedProjectId,
      allEnabled: value,
      chatEnabled: value,
      projectUpdatesEnabled: value,
    );

    if (!value) {
      await cancelProjectDeadline(normalizedProjectId);
      await cancel(
        _stableNotificationId(normalizedProjectId),
      );
    }
  }

  Future<void> setProjectAllEnabled({
    required String projectId,
    required bool value,
  }) async {
    await setProjectNotificationsEnabled(
      projectId: projectId,
      value: value,
    );
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
      await cancelProjectDeadline(projectId);
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

      final now = DateTime.now().toUtc().toIso8601String();

      final data = <String, dynamic>{
        'user_id': userId,
        'project_id': normalizedProjectId,
        'all_enabled': updated.allEnabled,
        'chat_enabled': updated.chatEnabled,
        'project_updates_enabled': updated.projectUpdatesEnabled,
        'updated_at': now,
      };

      final existingId = existing?['id']?.toString();

      if (existingId != null && existingId.isNotEmpty) {
        await _client
            .from(_settingsTable)
            .update(data)
            .eq('id', existingId);
      } else {
        data['created_at'] = now;

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
  // DATABASE NOTIFICATIONS
  // =========================================================

  Future<List<ProjectNotificationData>> getMyNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      var query = _client
          .from(_notificationsTable)
          .select()
          .eq('recipient_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response)
          .map(ProjectNotificationData.fromJson)
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'Load project notifications failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );

      return [];
    }
  }

  Future<int> getUnreadNotificationsCount() async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return 0;
    }

    try {
      final response = await _client
          .from(_notificationsTable)
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false);

      return List<dynamic>.from(response).length;
    } catch (e, st) {
      AppLogger.error(
        'Load unread notifications count failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );

      return 0;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final userId = _currentUserId;

    if (userId == null ||
        userId.isEmpty ||
        notificationId.trim().isEmpty) {
      return;
    }

    try {
      await _client
          .from(_notificationsTable)
          .update({
        'is_read': true,
      })
          .eq('id', notificationId.trim())
          .eq('recipient_id', userId);
    } catch (e, st) {
      AppLogger.error(
        'Mark notification as read failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  Future<void> markAllProjectNotificationsAsRead() async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await _client
          .from(_notificationsTable)
          .update({
        'is_read': true,
      })
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (e, st) {
      AppLogger.error(
        'Mark all notifications as read failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  Future<void> createProjectNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    String? projectId,
    String? projectTitle,
    String? senderId,
    bool showLocalIfCurrentUser = false,
    NotificationCategory category = NotificationCategory.projectUpdates,
  }) async {
    final normalizedRecipientId = recipientId.trim();
    final normalizedType = type.trim();

    if (normalizedRecipientId.isEmpty || normalizedType.isEmpty) {
      return;
    }

    final currentUserId = _currentUserId;

    final normalizedProjectId =
    projectId == null || projectId.trim().isEmpty
        ? null
        : projectId.trim();

    final normalizedSenderId =
    senderId == null || senderId.trim().isEmpty
        ? null
        : senderId.trim();

    final normalizedProjectTitle =
    projectTitle == null || projectTitle.trim().isEmpty
        ? null
        : projectTitle.trim();

    final notificationTitle = title.trim().isNotEmpty
        ? title.trim()
        : localizedTitleForType(
      normalizedType,
      fallback: title,
    );

    final notificationBody = body.trim().isNotEmpty
        ? body.trim()
        : localizedBodyForType(
      normalizedType,
      projectTitle: normalizedProjectTitle,
      fallback: body,
    );

    try {
      await _client.from(_notificationsTable).insert({
        'project_id': normalizedProjectId,
        'recipient_id': normalizedRecipientId,
        'sender_id': normalizedSenderId,
        'type': normalizedType,
        'title': notificationTitle,
        'body': notificationBody,
        'project_title': normalizedProjectTitle,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final isCurrentUser =
          currentUserId != null && currentUserId == normalizedRecipientId;

      if (showLocalIfCurrentUser && isCurrentUser) {
        await showSimple(
          notificationTitle,
          notificationBody,
          payload: normalizedProjectId,
          projectId: normalizedProjectId,
          category: category,
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Create project notification failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  Future<void> createProjectNotificationsForUsers({
    required Iterable<String> recipientIds,
    required String type,
    required String title,
    required String body,
    String? projectId,
    String? projectTitle,
    String? senderId,
    String? excludeUserId,
    NotificationCategory category = NotificationCategory.projectUpdates,
  }) async {
    final currentUserId = _currentUserId;
    final normalizedType = type.trim();

    if (normalizedType.isEmpty) {
      return;
    }

    final uniqueIds = recipientIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .where((id) => excludeUserId == null || id != excludeUserId)
        .toSet()
        .toList();

    if (uniqueIds.isEmpty) {
      return;
    }

    final normalizedProjectId =
    projectId == null || projectId.trim().isEmpty
        ? null
        : projectId.trim();

    final normalizedSenderId =
    senderId == null || senderId.trim().isEmpty
        ? null
        : senderId.trim();

    final normalizedProjectTitle =
    projectTitle == null || projectTitle.trim().isEmpty
        ? null
        : projectTitle.trim();

    final notificationTitle = title.trim().isNotEmpty
        ? title.trim()
        : localizedTitleForType(
      normalizedType,
      fallback: title,
    );

    final notificationBody = body.trim().isNotEmpty
        ? body.trim()
        : localizedBodyForType(
      normalizedType,
      projectTitle: normalizedProjectTitle,
      fallback: body,
    );

    final now = DateTime.now().toUtc().toIso8601String();

    final rows = uniqueIds.map((recipientId) {
      return {
        'project_id': normalizedProjectId,
        'recipient_id': recipientId,
        'sender_id': normalizedSenderId,
        'type': normalizedType,
        'title': notificationTitle,
        'body': notificationBody,
        'project_title': normalizedProjectTitle,
        'is_read': false,
        'created_at': now,
      };
    }).toList();

    try {
      await _client.from(_notificationsTable).insert(rows);

      if (currentUserId != null && uniqueIds.contains(currentUserId)) {
        await showSimple(
          notificationTitle,
          notificationBody,
          payload: normalizedProjectId,
          projectId: normalizedProjectId,
          category: category,
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Create project notifications for users failed',
        error: e,
        stackTrace: st,
        tag: 'NotificationService',
      );
    }
  }

  List<String> _projectMemberIds(ProjectModel project) {
    final ids = <String>{};

    if (project.ownerId.trim().isNotEmpty) {
      ids.add(project.ownerId.trim());
    }

    for (final participant in project.participantsData) {
      final id = participant.id.trim();

      if (id.isNotEmpty) {
        ids.add(id);
      }
    }

    return ids.toList();
  }

  // =========================================================
  // PROJECT NOTIFICATIONS
  // =========================================================

  Future<void> notifyProjectCreated({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'project_created',
      title: localizedTitleForType('project_created'),
      body: localizedBodyForType(
        'project_created',
        projectTitle: project.title,
      ),
    );
  }

  Future<void> notifyProjectUpdatedForMembers({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'project_updated',
      title: localizedTitleForType('project_updated'),
      body: localizedBodyForType(
        'project_updated',
        projectTitle: project.title,
      ),
    );
  }

  Future<void> notifyProjectDeletedForMembers({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: null,
      projectTitle: project.title,
      type: 'project_deleted',
      title: localizedTitleForType('project_deleted'),
      body: localizedBodyForType(
        'project_deleted',
        projectTitle: project.title,
      ),
    );
  }

  Future<void> notifyProjectCompletedForMembers({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'project_completed',
      title: localizedTitleForType('project_completed'),
      body: localizedBodyForType(
        'project_completed',
        projectTitle: project.title,
      ),
    );
  }

  Future<void> notifyProjectGradedForMembers({
    required ProjectModel project,
    required int grade,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'project_graded',
      title: localizedTitleForType('project_graded'),
      body: localizedBodyForType(
        'project_graded',
        projectTitle: project.title,
        grade: grade.toString(),
      ),
    );
  }

  Future<void> notifyProjectInvitation({
    required String projectId,
    required String projectTitle,
    required String invitedUserId,
    required String invitedBy,
  }) async {
    await createProjectNotification(
      recipientId: invitedUserId,
      senderId: invitedBy,
      projectId: projectId,
      projectTitle: projectTitle,
      type: 'member_invited',
      title: localizedTitleForType('member_invited'),
      body: localizedBodyForType(
        'member_invited',
        projectTitle: projectTitle,
      ),
    );
  }

  Future<void> notifyProjectInvitationAccepted({
    required String projectId,
    required String projectTitle,
    required String recipientId,
    String? senderId,
  }) async {
    await createProjectNotification(
      recipientId: recipientId,
      senderId: senderId,
      projectId: projectId,
      projectTitle: projectTitle,
      type: 'member_invite_accepted',
      title: localizedTitleForType('member_invite_accepted'),
      body: localizedBodyForType(
        'member_invite_accepted',
        projectTitle: projectTitle,
      ),
    );
  }

  Future<void> notifyProjectInvitationDeclined({
    required String projectId,
    required String projectTitle,
    required String recipientId,
    String? senderId,
  }) async {
    await createProjectNotification(
      recipientId: recipientId,
      senderId: senderId,
      projectId: projectId,
      projectTitle: projectTitle,
      type: 'member_invite_declined',
      title: localizedTitleForType('member_invite_declined'),
      body: localizedBodyForType(
        'member_invite_declined',
        projectTitle: projectTitle,
      ),
    );
  }

  Future<void> notifyFileAddedForMembers({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'file_added',
      title: localizedTitleForType('file_added'),
      body: localizedBodyForType(
        'file_added',
        projectTitle: project.title,
      ),
    );
  }

  Future<void> notifyTaskCreatedForMembers({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'task_created',
      title: localizedTitleForType('task_created'),
      body: localizedBodyForType(
        'task_created',
        projectTitle: project.title,
      ),
    );
  }

  Future<void> notifyTaskCompletedForMembers({
    required ProjectModel project,
    String? senderId,
  }) async {
    await createProjectNotificationsForUsers(
      recipientIds: _projectMemberIds(project),
      excludeUserId: senderId,
      senderId: senderId,
      projectId: project.id,
      projectTitle: project.title,
      type: 'task_completed',
      title: localizedTitleForType('task_completed'),
      body: localizedBodyForType(
        'task_completed',
        projectTitle: project.title,
      ),
    );
  }

  // =========================================================
  // SIMPLE LOCAL NOTIFICATION
  // =========================================================

  Future<void> showSimple(
      String title,
      String body, {
        String? payload,
        String? projectId,
        NotificationCategory category = NotificationCategory.projectUpdates,
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

      final id = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

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
            _chatChannelId,
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
            _projectUpdatesChannelId,
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
            _scheduledChannelId,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      title: localizedTitleForType('deadline_soon'),
      body: localizedBodyForType(
        'deadline_soon',
        projectTitle: title,
      ),
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
    final title = localizedTitleForType('new_message');

    final body = message.trim().isEmpty
        ? localizedBodyForType(
      'new_message',
      projectTitle: projectTitle,
    )
        : '$projectTitle • $senderName: $message';

    await showSimple(
      title,
      body,
      payload: payload ?? projectId,
      projectId: projectId,
      category: NotificationCategory.chat,
    );
  }

  Future<void> createChatNotificationForUsers({
    required Iterable<String> recipientIds,
    required String projectId,
    required String projectTitle,
    required String senderName,
    required String message,
    String? senderId,
    String? excludeUserId,
  }) async {
    final title = localizedTitleForType('new_message');

    final body = message.trim().isEmpty
        ? localizedBodyForType(
      'new_message',
      projectTitle: projectTitle,
    )
        : '$senderName: $message';

    await createProjectNotificationsForUsers(
      recipientIds: recipientIds,
      excludeUserId: excludeUserId ?? senderId,
      senderId: senderId,
      projectId: projectId,
      projectTitle: projectTitle,
      type: 'new_message',
      title: title,
      body: body,
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

      await _plugin.cancel(
        id: id,
      );
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