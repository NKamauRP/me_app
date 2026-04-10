import 'dart:math' as math;

import '../core/date_utils.dart';
import '../models/user_stats.dart';

class RewardOutcome {
  const RewardOutcome({
    required this.baseXp,
    required this.streakBonusXp,
    required this.newXp,
    required this.newLevel,
    required this.newStreak,
    required this.continuedStreak,
    required this.leveledUp,
  });

  final int baseXp;
  final int streakBonusXp;
  final int newXp;
  final int newLevel;
  final int newStreak;
  final bool continuedStreak;
  final bool leveledUp;
}

class XpEngine {
  static const int baseMoodXp = 5;
  static const int streakBonusXp = 10;
  static const int xpPerLevel = 50;

  RewardOutcome calculate({
    required UserStats currentStats,
    required DateTime today,
  }) {
    final todayKey = AppDateUtils.toStorageDate(today);

    if (currentStats.lastCheckinDate == todayKey) {
      return RewardOutcome(
        baseXp: 0,
        streakBonusXp: 0,
        newXp: currentStats.xp,
        newLevel: currentStats.level,
        newStreak: currentStats.streak,
        continuedStreak: false,
        leveledUp: false,
      );
    }

    final continuedStreak = AppDateUtils.isYesterday(
      currentStats.lastCheckinDate,
      today,
    );
    final awardedBonusXp = continuedStreak ? streakBonusXp : 0;
    final awardedXp = baseMoodXp + awardedBonusXp;
    final nextXp = currentStats.xp + awardedXp;
    final nextLevel = _levelFromXp(nextXp);

    return RewardOutcome(
      baseXp: baseMoodXp,
      streakBonusXp: awardedBonusXp,
      newXp: nextXp,
      newLevel: nextLevel,
      newStreak: continuedStreak ? currentStats.streak + 1 : 1,
      continuedStreak: continuedStreak,
      leveledUp: nextLevel > currentStats.level,
    );
  }

  int _levelFromXp(int xp) => math.sqrt(xp / xpPerLevel).floor();
}
