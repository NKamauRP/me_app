import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _themeKey = 'theme_preset';
  static const String _soundKey = 'sound_enabled';
  static const String _hapticsKey = 'haptics_enabled';
  static const String _backgroundMusicKey = 'background_music_enabled';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationFrequencyKey = 'notification_frequency';
  static const String _aiInsightsEnabledKey = 'ai_insights_enabled';
  static const String _insightModeKey = 'insight_mode';
  static const String _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const String _isFirstLaunchKey = 'is_first_launch';

  SharedPreferences? _preferences;
  AppThemePreset _currentTheme = AppThemePreset.calm;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _backgroundMusicEnabled = true;
  bool _notificationsEnabled = false;
  NotificationReminderFrequency _notificationFrequency =
      NotificationReminderFrequency.threeTimesDaily;
  bool _aiInsightsEnabled = true;
  InsightMode _insightMode = InsightMode.instant;
  bool _dailyReminderEnabled = false;
  bool _isFirstLaunch = true;

  AppThemePreset get currentTheme => _currentTheme;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get backgroundMusicEnabled => _backgroundMusicEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  NotificationReminderFrequency get notificationFrequency =>
      _notificationFrequency;
  bool get aiInsightsEnabled => _aiInsightsEnabled;
  InsightMode get insightMode => _insightMode;
  bool get dailyReminderEnabled => _dailyReminderEnabled;
  bool get isFirstLaunch => _isFirstLaunch;
  ThemeData get themeData => AppTheme.themeFor(_currentTheme);

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    await reloadPreferences(notify: false);
  }

  Future<void> reloadPreferences({bool notify = true}) async {
    _currentTheme = _themeFromName(
      _preferences?.getString(_themeKey) ?? AppThemePreset.calm.name,
    );
    _soundEnabled = _preferences?.getBool(_soundKey) ?? true;
    _hapticsEnabled = _preferences?.getBool(_hapticsKey) ?? true;
    _backgroundMusicEnabled =
        _preferences?.getBool(_backgroundMusicKey) ?? true;
    _notificationsEnabled =
        _preferences?.getBool(_notificationsEnabledKey) ?? false;
    _notificationFrequency = _notificationFrequencyFromName(
      _preferences?.getString(_notificationFrequencyKey) ??
          NotificationReminderFrequency.threeTimesDaily.name,
    );
    _aiInsightsEnabled = _preferences?.getBool(_aiInsightsEnabledKey) ?? true;
    _insightMode = _insightModeFromName(
      _preferences?.getString(_insightModeKey) ?? InsightMode.instant.name,
    );
    _dailyReminderEnabled =
        _preferences?.getBool(_dailyReminderEnabledKey) ?? false;
    _isFirstLaunch = _preferences?.getBool(_isFirstLaunchKey) ?? true;

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemePreset preset) async {
    if (_currentTheme == preset) {
      return;
    }

    _currentTheme = preset;
    notifyListeners();
    await _preferences?.setString(_themeKey, preset.name);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    if (_soundEnabled == enabled) {
      return;
    }

    _soundEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_soundKey, enabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) {
      return;
    }

    _hapticsEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_hapticsKey, enabled);
  }

  Future<void> setBackgroundMusicEnabled(bool enabled) async {
    if (_backgroundMusicEnabled == enabled) {
      return;
    }

    _backgroundMusicEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_backgroundMusicKey, enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) {
      return;
    }

    _notificationsEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_notificationsEnabledKey, enabled);
  }

  Future<void> setNotificationFrequency(
    NotificationReminderFrequency frequency,
  ) async {
    if (_notificationFrequency == frequency) {
      return;
    }

    _notificationFrequency = frequency;
    notifyListeners();
    await _preferences?.setString(_notificationFrequencyKey, frequency.name);
  }

  Future<void> setAiInsightsEnabled(bool enabled) async {
    if (_aiInsightsEnabled == enabled) {
      return;
    }

    _aiInsightsEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_aiInsightsEnabledKey, enabled);
  }

  Future<void> setInsightMode(InsightMode mode) async {
    if (_insightMode == mode) {
      return;
    }

    _insightMode = mode;
    notifyListeners();
    await _preferences?.setString(_insightModeKey, mode.name);
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (_dailyReminderEnabled == enabled) {
      return;
    }

    _dailyReminderEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_dailyReminderEnabledKey, enabled);
  }

  Future<void> completeOnboarding() async {
    if (!_isFirstLaunch) {
      return;
    }
    _isFirstLaunch = false;
    notifyListeners();
    await _preferences?.setBool(_isFirstLaunchKey, false);
  }

  AppThemePreset _themeFromName(String value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => AppThemePreset.calm,
    );
  }

  NotificationReminderFrequency _notificationFrequencyFromName(String value) {
    return NotificationReminderFrequency.values.firstWhere(
      (frequency) => frequency.name == value,
      orElse: () => NotificationReminderFrequency.threeTimesDaily,
    );
  }

  InsightMode _insightModeFromName(String value) {
    return InsightMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => InsightMode.instant,
    );
  }
}

enum NotificationReminderFrequency {
  hourly,
  threeTimesDaily,
  fiveTimesDaily,
}

enum InsightMode {
  instant,
  daily,
}
