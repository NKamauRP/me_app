import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Notification IDs — each ID must be unique and stable
  static const int _idMorning    = 1; // 08:00 check-in
  static const int _idNoon       = 2; // 12:00 reminder
  static const int _idAfternoon  = 3; // 15:00 reminder  
  static const int _idEvening    = 4; // 21:00 daily summary
  static const int _idStreak     = 5; // streak at risk
  static const int _idWeekly     = 6; // weekly summary (Sunday 10:00)
  static const int _idLevelUp    = 7; // one-shot level-up congratulation

  // ── Init ──────────────────────────────────────────────────────

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createChannels();
    // Permissions are requested on-demand or during schedule if needed, 
    // but we can trigger it here for early onboarding.
    await _requestPermissions();
  }

  // Backward compatibility alias for legacy init
  Future<void> initialize() => init();

  Future<void> _createChannels() async {
    const reminder = AndroidNotificationChannel(
      'mood_reminder',
      'Mood Reminders',
      description: 'Daily mood logging reminders',
      importance: Importance.defaultImportance,
      playSound: true,
    );
    const achievement = AndroidNotificationChannel(
      'achievements',
      'Achievements',
      description: 'Level-up and streak notifications',
      importance: Importance.high,
      playSound: true,
    );
    const weekly = AndroidNotificationChannel(
      'weekly_summary',
      'Weekly Summary',
      description: 'Your weekly mood summary',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(reminder);
    await androidPlugin?.createNotificationChannel(achievement);
    await androidPlugin?.createNotificationChannel(weekly);
  }

  Future<void> _requestPermissions() async {
    // Android 13+ requires POST_NOTIFICATIONS permission
    await Permission.notification.request();

    // Android 12+ requires SCHEDULE_EXACT_ALARM
    final exactAlarm = await Permission.scheduleExactAlarm.status;
    if (!exactAlarm.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<bool> requestPermissionIfNeeded() async {
    await _requestPermissions();
    return await Permission.notification.isGranted;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle tap — navigate to relevant screen logic can be added here
  }

  // ── Schedule all daily notifications ─────────────────────────

  Future<void> scheduleAllDailyNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final nameGreeting = name.isNotEmpty ? ', $name' : '';

    await _cancelDailyNotifications();

    // 08:00 — Morning check-in
    if (prefs.getBool('notif_morning') ?? true) {
      await _scheduleDailyAt(
        id: _idMorning,
        hour: 8,
        minute: 0,
        title: 'Good morning$nameGreeting 🌅',
        body: 'How are you feeling today? Take a moment to check in.',
        channel: 'mood_reminder',
      );
    }

    // 12:00 — Noon reminder
    if (prefs.getBool('notif_noon') ?? true) {
      await _scheduleDailyAt(
        id: _idNoon,
        hour: 12,
        minute: 0,
        title: 'Midday check-in ☀️',
        body: 'Halfway through the day — how\'s your mood holding up?',
        channel: 'mood_reminder',
      );

      // 15:00 — Afternoon reminder (tied to noon toggle in user's logic)
      await _scheduleDailyAt(
        id: _idAfternoon,
        hour: 15,
        minute: 0,
        title: 'Afternoon check-in 🌤️',
        body: 'Log how you\'re feeling this afternoon.',
        channel: 'mood_reminder',
      );
    }

    final tip = prefs.getString('last_generated_ai_tip');
    final eveningBody = tip != null 
        ? 'How was your day$nameGreeting? $tip'
        : 'How was your day$nameGreeting? Log your final mood and get your daily AI insight.';

    // 21:00 — Evening summary
    if (prefs.getBool('notif_evening') ?? true) {
      await _scheduleDailyAt(
        id: _idEvening,
        hour: 21,
        minute: 0,
        title: 'Evening reflection 🌙',
        body: eveningBody,
        channel: 'mood_reminder',
      );
    }

    // Streak at risk — 20:00 if no mood logged today
    if (prefs.getBool('notif_streak') ?? true) {
      await _scheduleDailyAt(
        id: _idStreak,
        hour: 20,
        minute: 0,
        title: 'Your streak is at risk 🔥',
        body: 'You haven\'t logged today. One quick entry keeps your streak alive!',
        channel: 'mood_reminder',
      );
    }

    // Weekly summary — every Sunday at 10:00
    if (prefs.getBool('notif_weekly') ?? true) {
      await _scheduleWeeklyAt(
        id: _idWeekly,
        weekday: DateTime.sunday,
        hour: 10,
        minute: 0,
        title: 'Your weekly mood summary 📊',
        body: 'See how your week looked emotionally. Your AI companion has insights for you.',
        channel: 'weekly_summary',
      );
    }
  }

  // Bridge for legacy AI tip scheduling
  Future<void> scheduleDailyReminder({String? customMessage}) async {
    if (customMessage != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_generated_ai_tip', customMessage);
    }
    await scheduleAllDailyNotifications();
  }

  // ── Level-up one-shot notification ────────────────────────────

  Future<void> showLevelUpNotification(int level) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final nameText = name.isNotEmpty ? ' $name' : '';

    await _plugin.show(
      _idLevelUp,
      '🎉 Level $level reached$nameText!',
      'You\'re building a powerful self-awareness habit. Keep it up!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          'Achievements',
          channelDescription: 'Level-up and streak notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Future<void> _scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channel,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == 'mood_reminder'
              ? 'Mood Reminders'
              : 'Weekly Summary',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _scheduleWeeklyAt({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channel,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          'Weekly Summary',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _cancelDailyNotifications() async {
    await _plugin.cancel(_idMorning);
    await _plugin.cancel(_idNoon);
    await _plugin.cancel(_idAfternoon);
    await _plugin.cancel(_idEvening);
    await _plugin.cancel(_idStreak);
    await _plugin.cancel(_idWeekly);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // Alias for compatibility if needed
  Future<void> cancelAllScheduled() => cancelAll();

  // ── Per-notification toggles ───────────────────────────────────

  Future<void> setMorningEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_morning', enabled);
    if (!enabled) await _plugin.cancel(_idMorning);
    else await scheduleAllDailyNotifications();
  }

  Future<void> setNoonEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_noon', enabled);
    if (!enabled) {
      await _plugin.cancel(_idNoon);
      await _plugin.cancel(_idAfternoon);
    } else await scheduleAllDailyNotifications();
  }

  Future<void> setEveningEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_evening', enabled);
    if (!enabled) await _plugin.cancel(_idEvening);
    else await scheduleAllDailyNotifications();
  }

  Future<void> setStreakEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_streak', enabled);
    if (!enabled) await _plugin.cancel(_idStreak);
    else await scheduleAllDailyNotifications();
  }

  Future<void> setWeeklyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_weekly', enabled);
    if (!enabled) await _plugin.cancel(_idWeekly);
    else await scheduleAllDailyNotifications();
  }
}
