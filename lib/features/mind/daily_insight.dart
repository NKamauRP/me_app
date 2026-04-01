import '../../models/mood_log.dart';
import '../../models/user_stats.dart';
import 'package:flutter/material.dart';

import 'mood_catalog.dart';

class DailyInsight {
  const DailyInsight({
    required this.title,
    required this.message,
    required this.accentColor,
  });

  final String title;
  final String message;
  final int accentColor;
}

class ProgressFlavor {
  const ProgressFlavor({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class DailyInsightCard extends StatelessWidget {
  const DailyInsightCard({
    super.key,
    required this.insight,
  });

  final DailyInsight insight;

  @override
  Widget build(BuildContext context) {
    final accent = Color(insight.accentColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Insight',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            insight.message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}

DailyInsight buildDailyInsight({
  required UserStats previousStats,
  required UserStats updatedStats,
  required List<MoodLog> weeklyLogs,
  required bool alreadyCheckedIn,
  required bool leveledUp,
}) {
  if (alreadyCheckedIn) {
    return const DailyInsight(
      title: 'Reflection updated',
      message: 'You refined today\'s entry. Small edits still count as showing up.',
      accentColor: 0xFF5A87F2,
    );
  }

  if (leveledUp) {
    final flavor = levelFlavorFor(updatedStats.level);
    return DailyInsight(
      title: 'Level up: ${flavor.title}',
      message: 'Your steady check-ins moved you into a new chapter today.',
      accentColor: 0xFFF4B942,
    );
  }

  if (updatedStats.streak >= 3) {
    return DailyInsight(
      title: 'Consistency is building',
      message:
          'You\'ve logged ${updatedStats.streak} days in a row. Consistency builds clarity.',
      accentColor: 0xFFE77752,
    );
  }

  if (_trendIsImproving(weeklyLogs)) {
    return const DailyInsight(
      title: 'Your trend is lifting',
      message: 'Your mood pattern looks steadier this week. Keep following what helps.',
      accentColor: 0xFF1D7A72,
    );
  }

  if (updatedStats.xp > previousStats.xp) {
    return const DailyInsight(
      title: 'Momentum matters',
      message: 'One honest check-in today makes tomorrow easier to understand.',
      accentColor: 0xFF4F9B93,
    );
  }

  return const DailyInsight(
    title: 'You checked in',
    message: 'Naming how you feel is a quiet form of progress.',
    accentColor: 0xFF1D7A72,
  );
}

ProgressFlavor levelFlavorFor(int level) {
  if (level <= 1) {
    return const ProgressFlavor(
      title: 'Getting Started \u{1F331}',
      subtitle: 'A simple beginning is still real growth.',
    );
  }

  if (level <= 3) {
    return const ProgressFlavor(
      title: 'Consistency Builder \u{1F525}',
      subtitle: 'You are turning check-ins into a rhythm.',
    );
  }

  return const ProgressFlavor(
    title: 'Mind Explorer \u{2B50}',
    subtitle: 'You are noticing patterns, not just moments.',
  );
}

ProgressFlavor streakFlavorFor(int streak) {
  if (streak <= 1) {
    return const ProgressFlavor(
      title: 'Starting fresh',
      subtitle: 'Today is enough.',
    );
  }

  if (streak <= 4) {
    return const ProgressFlavor(
      title: 'Building heat',
      subtitle: 'Your habit is warming up.',
    );
  }

  return const ProgressFlavor(
    title: 'Locked in',
    subtitle: 'This pattern is becoming part of you.',
  );
}

bool _trendIsImproving(List<MoodLog> weeklyLogs) {
  if (weeklyLogs.length < 3) {
    return false;
  }

  final midpoint = weeklyLogs.length ~/ 2;
  final firstHalf = weeklyLogs.take(midpoint).toList();
  final secondHalf = weeklyLogs.skip(midpoint).toList();

  if (firstHalf.isEmpty || secondHalf.isEmpty) {
    return false;
  }

  final firstAverage = firstHalf
          .map(moodWellbeingScore)
          .reduce((value, element) => value + element) /
      firstHalf.length;
  final secondAverage = secondHalf
          .map(moodWellbeingScore)
          .reduce((value, element) => value + element) /
      secondHalf.length;

  return secondAverage - firstAverage >= 0.6;
}
