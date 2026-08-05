import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationRouteHandler = void Function(String route);

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 1001;
  static const String _dailyChannelId = 'daily_study_reminders';
  static const String _generalChannelId = 'general_notifications';
  static const String _deviceIdKey = 'notificationDeviceId';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  NotificationRouteHandler? onRoute;
  String? _pendingInitialRoute;
  String _timeZoneId = 'UTC';
  bool _initialized = false;

  String get timeZoneId => _timeZoneId;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      _timeZoneId = zone.identifier;
      tz.setLocalLocation(tz.getLocation(_timeZoneId));
    } catch (_) {
      _timeZoneId = 'UTC';
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        _openRoute(response.payload);
      },
    );

    await _createAndroidChannels();
    final launchDetails = await _local.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingInitialRoute = _safeRoute(
        launchDetails?.notificationResponse?.payload,
      );
    }

    if (FirebaseBootstrap.isAvailable) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(_showRemoteMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _openRoute(message.data['route']);
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          unawaited(_saveDeviceRegistration(token: token));
        }),
      );
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _pendingInitialRoute = _safeRoute(initialMessage.data['route']);
      }
    }
    _initialized = true;
  }

  String? takeInitialRoute() {
    final route = _pendingInitialRoute;
    _pendingInitialRoute = null;
    return route;
  }

  Future<bool> hasPermission() async {
    if (!_initialized) return false;
    if (FirebaseBootstrap.isAvailable) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _local
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return false;
  }

  Future<bool> enableDailyReminder({
    required int hour,
    required int minute,
    required String languageCode,
  }) async {
    if (!_initialized) return false;
    final permission = FirebaseBootstrap.isAvailable
        ? await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : null;
    var granted = permission == null
        ? await _requestLocalPermission()
        : permission.authorizationStatus == AuthorizationStatus.authorized ||
              permission.authorizationStatus == AuthorizationStatus.provisional;
    if (granted && defaultTargetPlatform == TargetPlatform.android) {
      granted = await _requestLocalPermission();
    }
    if (!granted) return false;
    await scheduleDailyReminder(
      hour: hour,
      minute: minute,
      languageCode: languageCode,
    );
    await setRemoteEnabled(true);
    return true;
  }

  Future<void> disableNotifications() async {
    if (!_initialized) return;
    await _local.cancel(id: _dailyReminderId);
    await setRemoteEnabled(false);
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String languageCode,
  }) async {
    if (!_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    final korean = languageCode == 'ko';
    await _local.zonedSchedule(
      id: _dailyReminderId,
      title: korean ? '오늘의 일본어를 복습할 시간이에요' : 'Time for your Japanese review',
      body: korean
          ? '짧은 복습으로 학습 흐름을 이어가세요.'
          : 'Keep your momentum going with a quick review.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          'Daily study reminders',
          channelDescription: 'Your selected daily Japanese study reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/review',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> setRemoteEnabled(bool enabled) async {
    if (!_initialized || !FirebaseBootstrap.isAvailable) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveDeviceRegistration(token: token, enabled: enabled);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('FCM registration unavailable: $error');
    }
  }

  Future<bool> _requestLocalPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _local
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<void> _createAndroidChannels() async {
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _dailyChannelId,
        'Daily study reminders',
        description: 'Your selected daily Japanese study reminder',
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId,
        'General notifications',
        description: 'Announcements and account notifications',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null && body == null) return;
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannelId,
          'General notifications',
          channelDescription: 'Announcements and account notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _safeRoute(message.data['route']) ?? '/home',
    );
  }

  Future<void> _saveDeviceRegistration({
    required String token,
    bool? enabled,
  }) async {
    final userId = FirebaseBootstrap.userId;
    if (!FirebaseBootstrap.isAvailable || userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    final notificationsEnabled =
        enabled ?? preferences.getBool('notificationsEnabled') ?? false;
    final deviceId = await _deviceId(preferences);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .set({
          'token': token,
          'platform': switch (defaultTargetPlatform) {
            TargetPlatform.iOS => 'ios',
            TargetPlatform.android => 'android',
            _ => defaultTargetPlatform.name.toLowerCase(),
          },
          'enabled': notificationsEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<String> _deviceId(SharedPreferences preferences) async {
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    await preferences.setString(_deviceIdKey, generated);
    return generated;
  }

  void _openRoute(String? candidate) {
    final route = _safeRoute(candidate);
    if (route == null) return;
    final handler = onRoute;
    if (handler == null) {
      _pendingInitialRoute = route;
    } else {
      handler(route);
    }
  }

  String? _safeRoute(String? candidate) {
    if (candidate == null || !candidate.startsWith('/')) return null;
    return candidate;
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
