import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/date_utils.dart';
import '../core/services/theme_service.dart';
import '../features/mind/daily_insight.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../features/mind/screens/mood_selection_screen.dart';
import '../features/mind/weekly_graph.dart';
import '../features/settings/settings_screen.dart';
import '../models/user_stats.dart';
import '../services/update_service.dart';
import '../shared/widgets/glass_panel.dart';
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
    return Consumer2<MindMeProvider, ThemeService>(
      builder: (context, provider, settings, _) {
        final stats = provider.stats;
        final levelFlavor = levelFlavorFor(stats.level);
        final streakFlavor = streakFlavorFor(stats.streak);
        final identity = moodIdentityFor(stats.streak);
        final todayMood = provider.todayLog == null
            ? null
            : moodOptionById(provider.todayLog!.mood);
        final palette = AppTheme.paletteOf(settings.currentTheme);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.backgroundTop,
                  palette.backgroundBottom,
                ],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ME',
                                style:
                                    Theme.of(context).textTheme.displaySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A tiny daily ritual for your mind.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () {
                            Navigator.of(context).push(
                              buildAppRoute(const SettingsScreen()),
                            );
                          },
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      tint: palette.seed.withValues(alpha: 0.22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
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
                            identity.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            child: Text(
                              identity.subtitle,
                              key: ValueKey<String>(identity.title),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _AnimatedXpHeroCard(
                            stats: stats,
                            levelFlavor: levelFlavor,
                            streakFlavor: streakFlavor,
                            todayMood: todayMood,
                            intensity: provider.todayLog?.intensity,
                            palette: palette,
                          ),
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
                            accentColor: palette.seed,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: StatCard(
                            label: 'Streak flavor',
                            value: streakFlavor.subtitle,
                            icon: Icons.local_fire_department_rounded,
                            accentColor: palette.accent,
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
                      accentColor: palette.seed,
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
                      accentColor: palette.textMuted,
                      icon: Icons.favorite_rounded,
                      enabled: false,
                      onTap: _showComingSoon,
                    ),
                    const SizedBox(height: 14),
                    ModuleCard(
                      title: 'Work Me',
                      subtitle: 'Focus support and reflection are coming next.',
                      badgeLabel: 'Coming Soon',
                      accentColor: palette.textMuted,
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
                      accentColor: palette.textMuted,
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

class _AnimatedXpHeroCard extends StatefulWidget {
  const _AnimatedXpHeroCard({
    required this.stats,
    required this.levelFlavor,
    required this.streakFlavor,
    required this.todayMood,
    required this.intensity,
    required this.palette,
  });

  final UserStats stats;
  final ProgressFlavor levelFlavor;
  final ProgressFlavor streakFlavor;
  final MoodOption? todayMood;
  final int? intensity;
  final AppThemePalette palette;

  @override
  State<_AnimatedXpHeroCard> createState() => _AnimatedXpHeroCardState();
}

class _AnimatedXpHeroCardState extends State<_AnimatedXpHeroCard> {
  late double _fromProgress;
  late int _lastXp;
  late int _lastLevel;
  int _xpBurst = 0;
  bool _showXpBurst = false;
  bool _showLevelGlow = false;
  Timer? _xpTimer;
  Timer? _levelTimer;

  @override
  void initState() {
    super.initState();
    _fromProgress = widget.stats.progressToNextLevel;
    _lastXp = widget.stats.xp;
    _lastLevel = widget.stats.level;
  }

  @override
  void didUpdateWidget(covariant _AnimatedXpHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.stats.xp != _lastXp) {
      _fromProgress = oldWidget.stats.progressToNextLevel;
      final gainedXp = widget.stats.xp - _lastXp;
      _lastXp = widget.stats.xp;

      if (gainedXp > 0) {
        setState(() {
          _xpBurst = gainedXp;
          _showXpBurst = true;
        });
        _xpTimer?.cancel();
        _xpTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) {
            setState(() => _showXpBurst = false);
          }
        });
      }
    }

    if (widget.stats.level != _lastLevel) {
      _lastLevel = widget.stats.level;
      setState(() => _showLevelGlow = true);
      _levelTimer?.cancel();
      _levelTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _showLevelGlow = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _xpTimer?.cancel();
    _levelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 420),
          scale: _showLevelGlow ? 1.02 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                if (_showLevelGlow)
                  BoxShadow(
                    color: widget.palette.accent.withValues(alpha: 0.42),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${widget.stats.level}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    widget.levelFlavor.title,
                    key: ValueKey<String>(widget.levelFlavor.title),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.levelFlavor.subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.stats.xpIntoCurrentLevel}/50 XP toward the next level',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: _fromProgress,
                      end: widget.stats.progressToNextLevel,
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        minHeight: 12,
                        value: value,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.palette.accent,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
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
                              '${widget.stats.streak} days',
                              key: ValueKey<int>(widget.stats.streak),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.streakFlavor.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: widget.palette.accent),
                          ),
                        ],
                      ),
                    ),
                    if (widget.todayMood != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Today',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.todayMood!.emoji} ${widget.todayMood!.label}',
                              textAlign: TextAlign.right,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.intensity ?? 0}/10 intensity',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            right: 18,
            top: _showXpBurst ? -18 : 10,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 320),
              opacity: _showXpBurst ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.palette.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$_xpBurst XP',
                  style: const TextStyle(
                    color: Color(0xFF1B1B1B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
