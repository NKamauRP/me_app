import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/services/theme_service.dart';
import '../db/app_database.dart';
import '../data/mood_aggregator.dart';
import '../features/mind/daily_insight.dart';
import '../features/mind/micro_interactions.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../features/mind/screens/mood_history_screen.dart';
import '../features/mind/screens/mood_selection_screen.dart';
import '../services/ai_service.dart';
import '../features/settings/settings_screen.dart';
import '../services/update_service.dart';
import '../widgets/entry_timeline.dart';
import '../widgets/insight_card.dart';
import 'profile_screen.dart';
import '../shared/widgets/glass_panel.dart';
import '../shared/widgets/main_cta.dart';
import '../shared/widgets/progress_card.dart';
import '../shared/widgets/halftone_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didCheckForUpdates = false;
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
      final prefs = await SharedPreferences.getInstance();
      final settings = ThemeService.instance;
      final savedInsight = await AppDatabase.instance.getInsight(today);

      if (!mounted) {
        return;
      }

      setState(() {
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

      if (settings.userName == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _promptForName();
        });
      }
    } finally {
      _loadingExtras = false;
    }
  }

  Future<void> _promptForName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final palette = AppTheme.paletteOf(context.read<ThemeService>().currentTheme);
        return AlertDialog(
          backgroundColor: palette.scaffold,
          title: Text(
            'What should I call you?',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter your preferred name...',
              filled: true,
              fillColor: palette.seed.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text('Skip', style: TextStyle(color: palette.textMuted)),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name != null && name.trim().isNotEmpty) {
      await ThemeService.instance.setUserName(name);
    }
  }

  void _openMindCompanion() {
    Navigator.of(context).pushNamed('/chat_sessions');
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

    final provider = Provider.of<MindMeProvider>(context, listen: false);
    final streak = provider.stats.streak;
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

    final insight = await AiService.instance.dailyInsight(
      aggregate: aggregate,
      streakDays: streak,
    );
    await AppDatabase.instance.saveInsight(today, daily: insight);

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
          body: HalftoneOverlay(
            opacity: settings.currentTheme == AppThemePreset.night || settings.currentTheme == AppThemePreset.focus 
                ? 0.08 
                : 0.04,
            child: Container(
              decoration: BoxDecoration(
                color: palette.scaffold,
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
                        subtitle: todayMood != null
                            ? 'Welcome back - ${todayMood.emoji} ${todayMood.label}'
                            : stats.xp == 0 
                                ? 'Welcome to your mindful space'
                                : 'Welcome back',
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
                    if (stats.xp == 0 && !provider.hasLoggedToday) ...[
                      const SizedBox(height: 18),
                      RevealOnBuild(
                        offset: const Offset(0, 10),
                        child: GlassPanel(
                          tint: palette.accent.withValues(alpha: 0.1),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, color: palette.accent),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'First record the mood you are feeling right now to start your journey.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                            entries: provider.todayLog != null ? [provider.todayLog!] : [],
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
                                title: 'Mind Companion',
                                subtitle: 'On-device chat',
                                badge: 'New',
                                icon: Icons.chat_bubble_outline_rounded,
                                accentColor: palette.seed,
                                enabled: true,
                                highlighted: true,
                                onTap: _openMindCompanion,
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
    final provider = context.watch<MindMeProvider>();
    final settings = context.watch<ThemeService>();
    final palette = AppTheme.paletteOf(settings.currentTheme);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.userName != null 
                    ? 'Welcome back,\n${settings.userName}' 
                    : 'Welcome back',
                style: Theme.of(context).textTheme.displaySmall,
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
            _CircularIconButton(
              icon: Icons.history_rounded,
              onPressed: onOpenHistory,
              color: palette.seed,
            ),
            const SizedBox(height: 12),
            _CircularIconButton(
              icon: Icons.person_rounded,
              onPressed: onOpenProfile,
              color: palette.seed,
            ),
            const SizedBox(height: 12),
            _CircularIconButton(
              icon: Icons.tune_rounded,
              onPressed: onOpenSettings,
              color: palette.seed,
            ),
          ],
        ),
      ],
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 22),
        visualDensity: VisualDensity.compact,
      ),
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
