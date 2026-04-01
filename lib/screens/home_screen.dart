import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../core/date_utils.dart';
import '../features/mind/daily_insight.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../features/mind/screens/mood_selection_screen.dart';
import '../features/mind/weekly_graph.dart';
import '../services/update_service.dart';
import '../shared/widgets/stat_card.dart';
import '../widgets/module_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didCheckForUpdates = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didCheckForUpdates) {
      return;
    }

    _didCheckForUpdates = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      UpdateService.instance.checkForUpdates(context);
    });
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming Soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MindMeProvider>(
      builder: (context, provider, _) {
        final stats = provider.stats;
        final levelFlavor = levelFlavorFor(stats.level);
        final streakFlavor = streakFlavorFor(stats.streak);
        final todayMood = provider.todayLog == null
            ? null
            : moodOptionById(provider.todayLog!.mood);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF6EEE6),
                  Color(0xFFF7F8F4),
                ],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Text(
                      'ME',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: const Color(0xFF102321),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A tiny daily ritual for your mind.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1E766F),
                            Color(0xFF285B7D),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              provider.hasLoggedToday
                                  ? 'Checked in today'
                                  : 'Ready for today\'s check-in',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Level ${stats.level}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              levelFlavor.title,
                              key: ValueKey<String>(levelFlavor.title),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            levelFlavor.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${stats.xpIntoCurrentLevel}/50 XP toward the next level',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 12,
                              value: stats.progressToNextLevel,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFF4C255),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current streak',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '${stats.streak} days',
                                    key: ValueKey<int>(stats.streak),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  streakFlavor.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: const Color(0xFFFBD787)),
                                ),
                              ],
                            ),
                          ),
                          if (todayMood != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Today\'s mood: ${todayMood.emoji} ${todayMood.label} • ${provider.todayLog!.intensity}/10',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Last check-in',
                            value: stats.lastCheckinDate == null
                                ? 'Not yet'
                                : AppDateUtils.readableDate(
                                    stats.lastCheckinDate!,
                                  ),
                            icon: Icons.calendar_today_rounded,
                            accentColor: const Color(0xFF5A87F2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: StatCard(
                            label: 'Streak flavor',
                            value: streakFlavor.subtitle,
                            icon: Icons.local_fire_department_rounded,
                            accentColor: const Color(0xFFF49A35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    WeeklyMoodGraph(logs: provider.weeklyLogs),
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Your modules',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    ModuleCard(
                      title: 'Mind Me',
                      subtitle:
                          'Track your mood, earn XP, and protect your streak.',
                      badgeLabel: 'Active',
                      accentColor: const Color(0xFF1D7A72),
                      icon: Icons.psychology_alt_rounded,
                      enabled: true,
                      onTap: () {
                        Navigator.of(context).push(
                          buildAppRoute(const MoodSelectionScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    ModuleCard(
                      title: 'Healthy Me',
                      subtitle: 'Small wellness rituals are on the way.',
                      badgeLabel: 'Coming Soon',
                      accentColor: const Color(0xFF90A89F),
                      icon: Icons.favorite_rounded,
                      enabled: false,
                      onTap: _showComingSoon,
                    ),
                    const SizedBox(height: 14),
                    ModuleCard(
                      title: 'Work Me',
                      subtitle: 'Focus support and reflection are coming next.',
                      badgeLabel: 'Coming Soon',
                      accentColor: const Color(0xFF90A89F),
                      icon: Icons.work_history_rounded,
                      enabled: false,
                      onTap: _showComingSoon,
                    ),
                    const SizedBox(height: 14),
                    ModuleCard(
                      title: 'Habit Me',
                      subtitle:
                          'Habit loops and consistency tracking are coming soon.',
                      badgeLabel: 'Coming Soon',
                      accentColor: const Color(0xFF90A89F),
                      icon: Icons.track_changes_rounded,
                      enabled: false,
                      onTap: _showComingSoon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
