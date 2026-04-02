import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _themeKey = 'theme_preset';
  static const String _soundKey = 'sound_enabled';
  static const String _hapticsKey = 'haptics_enabled';

  SharedPreferences? _preferences;
  AppThemePreset _currentTheme = AppThemePreset.calm;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  AppThemePreset get currentTheme => _currentTheme;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  ThemeData get themeData => AppTheme.themeFor(_currentTheme);

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    _currentTheme = _themeFromName(
      _preferences?.getString(_themeKey) ?? AppThemePreset.calm.name,
    );
    _soundEnabled = _preferences?.getBool(_soundKey) ?? true;
    _hapticsEnabled = _preferences?.getBool(_hapticsKey) ?? true;
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

  AppThemePreset _themeFromName(String value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => AppThemePreset.calm,
    );
  }
}
