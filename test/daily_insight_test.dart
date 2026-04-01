import 'package:flutter_test/flutter_test.dart';
import 'package:me_app/features/mind/daily_insight.dart';
import 'package:me_app/models/mood_log.dart';
import 'package:me_app/models/user_stats.dart';

void main() {
  test('buildDailyInsight celebrates streak consistency', () {
    final insight = buildDailyInsight(
      previousStats: const UserStats(
        id: 1,
        xp: 10,
        level: 1,
        streak: 2,
        lastCheckinDate: '2026-03-31',
      ),
      updatedStats: const UserStats(
        id: 1,
        xp: 25,
        level: 1,
        streak: 3,
        lastCheckinDate: '2026-04-01',
      ),
      weeklyLogs: const <MoodLog>[
        MoodLog(
          id: 1,
          date: '2026-03-30',
          mood: 'stress',
          intensity: 5,
          note: 'Busy day',
        ),
        MoodLog(
          id: 2,
          date: '2026-03-31',
          mood: 'tired',
          intensity: 4,
          note: 'Low energy',
        ),
        MoodLog(
          id: 3,
          date: '2026-04-01',
          mood: 'happy',
          intensity: 7,
          note: 'Better day',
        ),
      ],
      alreadyCheckedIn: false,
      leveledUp: false,
    );

    expect(insight.title, 'Consistency is building');
  });

  test('levelFlavorFor maps early levels to the requested labels', () {
    expect(levelFlavorFor(1).title, 'Getting Started \u{1F331}');
    expect(levelFlavorFor(2).title, 'Consistency Builder \u{1F525}');
    expect(levelFlavorFor(5).title, 'Mind Explorer \u{2B50}');
  });
}
