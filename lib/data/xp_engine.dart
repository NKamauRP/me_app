import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';

class XPEngine {
  static const int dailyCap = 80;

  static int calculateEntryXP({
    required int intensity,
    required bool hasNote,
    required int streakDays,
    required int dailyXPSoFar,
  }) {
    const base = 10;
    final noteBonus = hasNote ? 5 : 0;
    final streakMultiplier = 1.0 + (streakDays * 0.05).clamp(0.0, 2.0);
    final rawXp = ((base + intensity + noteBonus) * streakMultiplier).round();
    final remaining = dailyCap - dailyXPSoFar;
    return max(0, min(rawXp, remaining));
  }

  static int calculateLevel(int totalXP) {
    if (totalXP <= 0) {
      return 1;
    }
    return max(1, sqrt(totalXP / 50).floor());
  }

  static int xpForNextLevel(int currentLevel) {
    return ((currentLevel + 1) * (currentLevel + 1)) * 50;
  }

  static int xpForCurrentLevel(int currentLevel) {
    return (currentLevel * currentLevel) * 50;
  }

  static Future<int> processEntry({
    required int intensity,
    required bool hasNote,
    required String date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final streakDays = prefs.getInt('streak_days') ?? 0;
    final dailyXPSoFar = await DatabaseHelper.instance.getDailyXP(date);

    final xpGained = calculateEntryXP(
      intensity: intensity,
      hasNote: hasNote,
      streakDays: streakDays,
      dailyXPSoFar: dailyXPSoFar,
    );

    if (xpGained > 0) {
      await DatabaseHelper.instance.updateDailyXP(date, xpGained);
      final totalXP = (prefs.getInt('total_xp') ?? 0) + xpGained;
      await prefs.setInt('total_xp', totalXP);
    }

    return xpGained;
  }

  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final lastLogged = prefs.getString('last_logged_date') ?? '';

    if (lastLogged == todayStr) {
      return;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    var streak = prefs.getInt('streak_days') ?? 0;
    if (lastLogged == yesterdayStr) {
      streak += 1;
    } else {
      streak = 1;
    }

    final maxStreak = max(streak, prefs.getInt('max_streak') ?? 0);

    await prefs.setInt('streak_days', streak);
    await prefs.setInt('max_streak', maxStreak);
    await prefs.setString('last_logged_date', todayStr);
  }
}
