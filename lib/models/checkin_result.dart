import 'mood_log.dart';
import 'user_stats.dart';
import '../features/mind/daily_insight.dart';

class CheckInResult {
  const CheckInResult({
    required this.log,
    required this.stats,
    required this.baseXp,
    required this.streakBonusXp,
    required this.continuedStreak,
    required this.leveledUp,
    required this.alreadyCheckedIn,
    required this.dailyInsight,
  });

  final MoodLog log;
  final UserStats stats;
  final int baseXp;
  final int streakBonusXp;
  final bool continuedStreak;
  final bool leveledUp;
  final bool alreadyCheckedIn;
  final DailyInsight dailyInsight;

  int get totalXp => baseXp + streakBonusXp;

  factory CheckInResult.alreadyCheckedIn({
    required MoodLog log,
    required UserStats stats,
    required DailyInsight dailyInsight,
  }) {
    return CheckInResult(
      log: log,
      stats: stats,
      baseXp: 0,
      streakBonusXp: 0,
      continuedStreak: false,
      leveledUp: false,
      alreadyCheckedIn: true,
      dailyInsight: dailyInsight,
    );
  }
}
