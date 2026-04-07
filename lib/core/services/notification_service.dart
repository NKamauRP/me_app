import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'theme_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _reminderNotificationId = 4101;
  static const String _channelId = 'mind_me_reminders';
  static const String _channelName = 'Mind Me reminders';
  static const String _channelDescription =
      'Gentle reminders to log your mood in ME.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings: initializationSettings);
    _initialized = true;
    await syncWithPreferences();
  }

  Future<void> syncWithPreferences() async {
    if (!_initialized || !Platform.isAndroid) {
      return;
    }

    if (!ThemeService.instance.notificationsEnabled) {
      await cancelMoodReminders();
      return;
    }

    await scheduleMoodReminders(
      ThemeService.instance.notificationFrequency,
    );
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted =
        await androidImplementation?.requestNotificationsPermission();

    return granted ?? true;
  }

  Future<void> scheduleMoodReminders(
    NotificationReminderFrequency frequency,
  ) async {
    if (!_initialized || !Platform.isAndroid) {
      return;
    }

    await cancelMoodReminders();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.periodicallyShowWithDuration(
      id: _reminderNotificationId,
      title: 'Mind Me reminder',
      body: _bodyForFrequency(frequency),
      repeatDurationInterval: _durationForFrequency(frequency),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelMoodReminders() async {
    if (!_initialized || !Platform.isAndroid) {
      return;
    }

    await _plugin.cancel(id: _reminderNotificationId);
  }

  Duration _durationForFrequency(NotificationReminderFrequency frequency) {
    switch (frequency) {
      case NotificationReminderFrequency.hourly:
        return const Duration(hours: 1);
      case NotificationReminderFrequency.threeTimesDaily:
        return const Duration(hours: 8);
      case NotificationReminderFrequency.fiveTimesDaily:
        return const Duration(hours: 4, minutes: 48);
    }
  }

  String _bodyForFrequency(NotificationReminderFrequency frequency) {
    switch (frequency) {
      case NotificationReminderFrequency.hourly:
        return 'Pause for a quick check-in whenever it feels right.';
      case NotificationReminderFrequency.threeTimesDaily:
        return 'A gentle reminder to notice your mood and log a short reflection.';
      case NotificationReminderFrequency.fiveTimesDaily:
        return 'Take a small moment for yourself and capture how you feel.';
    }
  }
}
