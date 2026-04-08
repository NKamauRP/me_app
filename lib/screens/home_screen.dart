import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/services/theme_service.dart';
import '../data/database_helper.dart';
import '../data/mood_aggregator.dart';
import '../features/mind/daily_insight.dart';
import '../features/mind/micro_interactions.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../features/mind/screens/mood_history_screen.dart';
import '../features/mind/screens/mood_selection_screen.dart';
import '../services/gemma_service.dart';
import '../features/settings/settings_screen.dart';
import '../services/update_service.dart';
import '../widgets/entry_timeline.dart';
import '../widgets/insight_card.dart';
import 'profile_screen.dart';
import '../shared/widgets/glass_panel.dart';
import '../shared/widgets/main_cta.dart';
import '../shared/widgets/progress_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didCheckForUpdates = false;
  List<Map<String, dynamic>> _todayEntries = const [];
  InsightState _insightState = InsightState.idle;
  String? _insightText;
  bool _loadingExtras = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardExtras();
    });
  }

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

  void _openMindMe() {
    Navigator.of(context)
        .push(
      buildAppRoute(const MoodSelectionScreen()),
    )
        .then((_) => _loadDashboardExtras());
  }

  Future<void> _loadDashboardExtras() async {
    if (_loadingExtras) {
      return;
    }

    _loadingExtras = true;
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final entries = await DatabaseHelper.instance.getEntriesForDate(today);
      final prefs = await SharedPreferences.getInstance();
      final settings = ThemeService.instance;
      final savedInsight = await DatabaseHelper.instance.getInsight(today);

      if (!mounted) {
        return;
      }

      setState(() {
        _todayEntries = entries;
        if (settings.insightMode == InsightMode.daily &&
            settings.aiInsightsEnabled &&
            (savedInsight?['daily_insight'] as String?)?.trim().isNotEmpty ==
                true) {
          _insightState = InsightState.done;
          _insightText = savedInsight?['daily_insight'] as String?;
        } else {
          _insightState = InsightState.idle;
          _insightText = null;
        }
      });

      if (!prefs.containsKey('total_xp')) {
        await prefs.setInt('total_xp', 0);
      }
    } finally {
      _loadingExtras = false;
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming Soon')),
    );
  }

  Future<void> _getTodaysInsight() async {
    final settings = ThemeService.instance;
    if (!settings.aiInsightsEnabled) {
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() => _insightState = InsightState.loading);

    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt('streak_days') ?? 0;
    final aggregate = await MoodAggregator.aggregateDay(today);

    if (aggregate == null) {
      if (!mounted) {
        return;
      }
      setState(() => _insightState = InsightState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one mood first.')),
      );
      return;
    }

    final insight = await GemmaService.instance.dailyInsight(
      aggregate: aggregate,
      streakDays: streak,
    );
    await DatabaseHelper.instance.saveInsight(today, daily: insight);

    if (!mounted) {
      return;
    }

    setState(() {
      _insightState = InsightState.done;
      _insightText = insight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MindMeProvider, ThemeService>(
      builder: (context, provider, settings, _) {
        final stats = provider.stats;
        final levelFlavor = levelFlavorFor(stats.level);
        final todayMood = provider.todayLog == null
            ? null
            : moodOptionById(provider.todayLog!.mood);
        final palette = AppTheme.paletteOf(settings.currentTheme);
        final moodMap = _buildMoodMap();

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
                onRefresh: () async {
                  await provider.refresh();
                  await _loadDashboardExtras();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    RevealOnBuild(
                      offset: const Offset(0, 16),
                      child: _DashboardHeader(
                        streak: stats.streak,
                        title: levelFlavor.title,
                        subtitle: todayMood == null
                            ? 'Welcome back'
                            : 'Welcome back - ${todayMood.emoji} ${todayMood.label}',
                        onOpenHistory: () {
                          Navigator.of(context).push(
                            buildAppRoute(const MoodHistoryScreen()),
                          );
                        },
                        onOpenSettings: () {
                          Navigator.of(context).push(
                            buildAppRoute(const SettingsScreen()),
                          ).then((_) => _loadDashboardExtras());
                        },
                        onOpenProfile: () {
                          Navigator.of(context).push(
                            buildAppRoute(const ProfileScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    RevealOnBuild(
                      offset: const Offset(0, 10),
                      duration: const Duration(milliseconds: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          EntryTimeline(
                            entries: _todayEntries,
                            moodMap: moodMap,
                          ),
                        ],
                      ),
                    ),
                    if (settings.insightMode == InsightMode.daily &&
                        settings.aiInsightsEnabled) ...[
                      const SizedBox(height: 18),
                      InsightCard(
                        state: _insightState,
                        insightText: _insightText,
                        moodColor: todayMood?.color ?? palette.accent,
                        onDismiss: () {
                          setState(() => _insightState = InsightState.idle);
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed:
                              _insightState == InsightState.loading ? null : _getTodaysInsight,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Get today\'s insight'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    RevealOnBuild(
                      offset: const Offset(0, 18),
                      duration: const Duration(milliseconds: 520),
                      child: MainCta(
                        title: provider.hasLoggedToday
                            ? 'Update Today\'s Mood'
                            : 'Log Your Mood',
                        subtitle: provider.hasLoggedToday
                            ? 'Refine today\'s reflection and keep your awareness sharp.'
                            : 'One quick check-in keeps your streak moving.',
                        badgeLabel: provider.hasLoggedToday
                            ? 'Mind Me is ready'
                            : 'What should I do right now?',
                        accentColor: palette.accent,
                        onTap: _openMindMe,
                      ),
                    ),
                    const SizedBox(height: 24),
                    RevealOnBuild(
                      offset: const Offset(0, 18),
                      duration: const Duration(milliseconds: 560),
                      child: ProgressCard(
                        stats: stats,
                        levelFlavor: levelFlavor,
                        weeklyLogs: provider.weeklyLogs,
                        accentColor: palette.accent,
                        seedColor: palette.seed,
                      ),
                    ),
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 28),
                    RevealOnBuild(
                      offset: const Offset(0, 16),
                      duration: const Duration(milliseconds: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your modules',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Mind Me stays front and center. Everything else can wait.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.96,
                            children: [
                              _DashboardModuleTile(
                                title: 'Mind Me',
                                subtitle: 'Daily check-in',
                                badge: 'Active',
                                icon: Icons.psychology_alt_rounded,
                                accentColor: palette.seed,
                                enabled: true,
                                highlighted: true,
                                onTap: _openMindMe,
                              ),
                              _DashboardModuleTile(
                                title: 'Healthy Me',
                                subtitle: 'Coming Soon',
                                badge: 'Soon',
                                icon: Icons.favorite_rounded,
                                accentColor: palette.textMuted,
                                enabled: false,
                                highlighted: false,
                                onTap: _showComingSoon,
                              ),
                              _DashboardModuleTile(
                                title: 'Work Me',
                                subtitle: 'Coming Soon',
                                badge: 'Soon',
                                icon: Icons.work_history_rounded,
                                accentColor: palette.textMuted,
                                enabled: false,
                                highlighted: false,
                                onTap: _showComingSoon,
                              ),
                              _DashboardModuleTile(
                                title: 'Habit Me',
                                subtitle: 'Coming Soon',
                                badge: 'Soon',
                                icon: Icons.track_changes_rounded,
                                accentColor: palette.textMuted,
                                enabled: false,
                                highlighted: false,
                                onTap: _showComingSoon,
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.streak,
    required this.title,
    required this.subtitle,
    required this.onOpenHistory,
    required this.onOpenSettings,
    required this.onOpenProfile,
  });

  final int streak;
  final String title;
  final String subtitle;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 30,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeaderChip(
                    label: '🔥 $streak days',
                    emphasis: true,
                  ),
                  _HeaderChip(
                    label: title,
                    emphasis: false,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            IconButton.filledTonal(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history_rounded),
            ),
            const SizedBox(height: 8),
            IconButton.filledTonal(
              onPressed: onOpenProfile,
              icon: const Icon(Icons.person_rounded),
            ),
            const SizedBox(height: 8),
            IconButton.filledTonal(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

Map<String, Map<String, dynamic>> _buildMoodMap() {
  return {
    for (final mood in mindMoodOptions)
      mood.id: {
        'emoji': mood.emoji,
        'label': mood.label,
        'color': mood.color,
      },
  };
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.emphasis,
  });

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: emphasis
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasis
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
      ),
    );
  }
}

class _DashboardModuleTile extends StatelessWidget {
  const _DashboardModuleTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = GlassPanel(
      tint: accentColor.withValues(alpha: highlighted ? 0.18 : 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: TapScale(
        onTap: () {
          MindHaptics.cardTap();
          onTap();
        },
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: enabled ? 0 : 0.8,
            sigmaY: enabled ? 0 : 0.8,
          ),
          child: tile,
        ),
      ),
    );
  }
}
