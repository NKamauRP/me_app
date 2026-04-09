import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'theme_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 4101;
  static const String _channelId = 'mood_reminder';
  static const String _channelName = 'Mood reminder';
  static const String _lastTipKey = 'last_generated_ai_tip';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initializationSettings);
    _initialized = true;
    await syncWithPreferences();
  }

  Future<void> syncWithPreferences() async {
    if (!_initialized || !Platform.isAndroid) {
      return;
    }

    if (!ThemeService.instance.dailyReminderEnabled) {
      await cancelAllScheduled();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastTip = prefs.getString(_lastTipKey);
    await scheduleDailyReminder(customMessage: lastTip);
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final notificationPermission =
        await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();

    return notificationPermission ?? true;
  }

  Future<void> scheduleDailyReminder({String? customMessage}) async {
    if (!_initialized || !Platform.isAndroid) {
      return;
    }

    if (customMessage != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastTipKey, customMessage);
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Your Daily Reflection',
      customMessage ?? 'Take a moment to log how you feel today.',
      _nextNinePm(),
      const NotificationDetails(android: androidDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAllScheduled() async {
    if (!_initialized || !Platform.isAndroid) {
      return;
    }

    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextNinePm() {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 21);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }
}
