import 'package:flutter/material.dart';

import '../../models/mood_log.dart';
import '../../models/user_stats.dart';
import '../../shared/widgets/glass_panel.dart';
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

class MoodIdentity {
  const MoodIdentity({
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

    return GlassPanel(
      tint: accent.withValues(alpha: 0.16),
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
            style: Theme.of(context).textTheme.bodyLarge,
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

MoodIdentity moodIdentityFor(int streak) {
  if (streak <= 3) {
    return const MoodIdentity(
      title: 'Getting Started \u{1F331}',
      subtitle: 'You are building the habit one honest day at a time.',
    );
  }

  if (streak <= 7) {
    return const MoodIdentity(
      title: 'Self Observer \u{1F441}\u{FE0F}',
      subtitle: 'You are noticing patterns instead of rushing past them.',
    );
  }

  if (streak <= 14) {
    return const MoodIdentity(
      title: 'Mind Explorer \u{1F9E0}',
      subtitle: 'Your reflections are starting to map your inner weather.',
    );
  }

  return const MoodIdentity(
    title: 'Emotion Master \u{1F525}',
    subtitle: 'You have turned consistency into a powerful self-check ritual.',
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
