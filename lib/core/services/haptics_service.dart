import 'package:flutter/services.dart';

import 'theme_service.dart';

class HapticsService {
  HapticsService._();

  static final HapticsService instance = HapticsService._();

  bool get _enabled => ThemeService.instance.hapticsEnabled;

  Future<void> lightImpact() async {
    if (!_enabled) {
      return;
    }
    await HapticFeedback.lightImpact();
  }

  Future<void> selectionClick() async {
    if (!_enabled) {
      return;
    }
    await HapticFeedback.selectionClick();
  }

  Future<void> mediumImpact() async {
    if (!_enabled) {
      return;
    }
    await HapticFeedback.mediumImpact();
  }

  Future<void> heavyImpact() async {
    if (!_enabled) {
      return;
    }
    await HapticFeedback.heavyImpact();
  }
}
