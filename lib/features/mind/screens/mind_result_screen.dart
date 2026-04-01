import 'package:flutter/material.dart';

import '../../../core/date_utils.dart';
import '../../../models/checkin_result.dart';
import '../daily_insight.dart';
import '../micro_interactions.dart';
import '../mood_catalog.dart';

class MindResultScreen extends StatelessWidget {
  const MindResultScreen({
    super.key,
    required this.mood,
    required this.result,
  });

  final MoodOption mood;
  final CheckInResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelFlavor = levelFlavorFor(result.stats.level);
    final streakFlavor = streakFlavorFor(result.stats.streak);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAF0E4),
              Color(0xFFF7F8F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: mood.color.withValues(alpha: 0.18),
                        child: Text(
                          mood.emoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        result.alreadyCheckedIn
                            ? 'Today\'s check-in was updated'
                            : 'You showed up today',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.alreadyCheckedIn
                            ? 'You already earned today\'s rewards, but your reflection was saved.'
                            : 'Your ${mood.label.toLowerCase()} reflection is saved for ${AppDateUtils.readableDate(result.log.date)}.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Intensity ${result.log.intensity}/10',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: mood.color,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '+${result.totalXp} XP',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: const Color(0xFF1D7A72),
                        ),
                      ),
                      if (result.streakBonusXp > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+${result.streakBonusXp} streak bonus',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFF09A20),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F1EA),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Streak: ${result.stats.streak} days \u{1F525}',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              streakFlavor.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFFE77752),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Level ${result.stats.level} • ${result.stats.xp} total XP',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                levelFlavor.title,
                                key: ValueKey<String>(levelFlavor.title),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF1D7A72),
                                ),
                              ),
                            ),
                            if (result.leveledUp) ...[
                              const SizedBox(height: 8),
                              RevealOnBuild(
                                child: Text(
                                  'Level up unlocked',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF1D7A72),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DailyInsightCard(insight: result.dailyInsight),
                    ],
                  ),
                ),
                const Spacer(),
                AnimatedActionButton(
                  label: 'Back to dashboard',
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
