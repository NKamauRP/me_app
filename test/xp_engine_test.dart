import 'package:flutter_test/flutter_test.dart';
import 'package:me_app/models/user_stats.dart';
import 'package:me_app/services/xp_engine.dart';

void main() {
  group('XpEngine', () {
    test('awards base xp for a fresh daily check-in', () {
      final engine = XpEngine();
      final outcome = engine.calculate(
        currentStats: UserStats.initial(),
        today: DateTime(2026, 4, 1),
      );

      expect(outcome.baseXp, 5);
      expect(outcome.streakBonusXp, 0);
      expect(outcome.newXp, 5);
      expect(outcome.newStreak, 1);
      expect(outcome.newLevel, 1);
    });

    test('awards bonus xp when the streak continues', () {
      final engine = XpEngine();
      final outcome = engine.calculate(
        currentStats: const UserStats(
          id: 1,
          xp: 45,
          level: 1,
          streak: 3,
          lastCheckinDate: '2026-03-31',
        ),
        today: DateTime(2026, 4, 1),
      );

      expect(outcome.baseXp, 5);
      expect(outcome.streakBonusXp, 10);
      expect(outcome.newXp, 60);
      expect(outcome.newStreak, 4);
      expect(outcome.newLevel, 2);
      expect(outcome.leveledUp, isTrue);
    });
  });
}
