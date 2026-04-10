import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../data/mood_aggregator.dart';
import '../models/mood_log.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../features/mind/mood_catalog.dart';
import '../services/ai_service.dart';
import '../services/xp_engine.dart';
import '../widgets/insight_card.dart';
import '../core/app_theme.dart';
import '../shared/widgets/halftone_overlay.dart';
import '../core/services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _totalXp = 0;
  int _level = 1;
  int _streak = 0;
  int _totalEntries = 0;
  String _dominantMoodId = 'calm';
  List<double> _weeklyAverages = List<double>.filled(7, 0);
  Set<String> _badgeIds = const {};

  InsightState _weeklyState = InsightState.idle;
  String? _weeklyText;
  InsightState _monthlyState = InsightState.idle;
  String? _monthlyText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final provider = Provider.of<MindMeProvider>(context, listen: false);
    final allEntries = await AppDatabase.instance.fetchAllMoodLogs();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final weekEntries = await AppDatabase.instance.fetchMoodLogsBetween(
      startDate: DateFormat('yyyy-MM-dd').format(start),
      endDate: DateFormat('yyyy-MM-dd').format(now),
    );

    final weeklyAverages = List<double>.filled(7, 0);
    final groupedByDate = <String, MoodLog>{};
    for (final entry in weekEntries) {
      groupedByDate[entry.date] = entry;
    }

    for (var index = 0; index < 7; index++) {
      final date = start.add(Duration(days: index));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final item = groupedByDate[key];
      if (item == null) {
        weeklyAverages[index] = 0;
      } else {
        weeklyAverages[index] = item.intensity.toDouble();
      }
    }

    final dominantMoodId = _dominantMoodForEntries(weekEntries);
    final badgeIds = _unlockBadges(
      entries: allEntries,
      level: provider.stats.level,
      maxStreak: provider.stats.streak,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _totalXp = provider.stats.xp;
      _level = provider.stats.level;
      _streak = provider.stats.streak;
      _totalEntries = allEntries.length;
      _dominantMoodId = dominantMoodId;
      _weeklyAverages = weeklyAverages;
      _badgeIds = badgeIds;
      _isLoading = false;
    });
  }

  String _dominantMoodForEntries(List<MoodLog> entries) {
    if (entries.isEmpty) {
      return 'calm';
    }

    final counts = <String, int>{};
    for (final entry in entries) {
      final moodId = entry.mood;
      counts[moodId] = (counts[moodId] ?? 0) + 1;
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Set<String> _unlockBadges({
    required List<MoodLog> entries,
    required int level,
    required int maxStreak,
  }) {
    final ids = <String>{};

    if (entries.isNotEmpty) ids.add('first_log');
    if (maxStreak >= 3) ids.add('streak_3');
    if (maxStreak >= 7) ids.add('streak_7');
    if (maxStreak >= 30) ids.add('streak_30');
    if (level >= 5) ids.add('level_5');
    if (level >= 10) ids.add('level_10');
    if (entries.length >= 3) ids.add('consistent');

    return ids;
  }

  Future<void> _fetchWeeklyInsight() async {
    setState(() => _weeklyState = InsightState.loading);
    try {
      final aggregate = await MoodAggregator.aggregateRange(7);
      if (aggregate == null) {
        setState(() => _weeklyState = InsightState.idle);
        return;
      }
      final result = await AiService.instance.weeklyInsight(aggregate: aggregate);
      setState(() {
        _weeklyState = InsightState.done;
        _weeklyText = result;
      });
    } catch (e) {
      setState(() => _weeklyState = InsightState.error);
    }
  }

  Future<void> _fetchMonthlyInsight() async {
    setState(() => _monthlyState = InsightState.loading);
    try {
      final aggregate = await MoodAggregator.aggregateRange(30);
      if (aggregate == null) {
        setState(() => _monthlyState = InsightState.idle);
        return;
      }
      final result = await AiService.instance.monthlyInsight(aggregate: aggregate);
      setState(() {
        _monthlyState = InsightState.done;
        _monthlyText = result;
      });
    } catch (e) {
      setState(() => _monthlyState = InsightState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ThemeService>();
    final palette = AppTheme.paletteOf(settings.currentTheme);
    final theme = Theme.of(context);
    final mood = moodOptionById(_dominantMoodId);
    final nextLevelXp = _level * XpEngine.xpPerLevel;
    final progress = nextLevelXp <= 0
        ? 0.0
        : ((_totalXp % XpEngine.xpPerLevel) / XpEngine.xpPerLevel)
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: HalftoneOverlay(
        opacity: settings.currentTheme == AppThemePreset.night ||
                settings.currentTheme == AppThemePreset.focus
            ? 0.08
            : 0.04,
        child: Container(
          decoration: BoxDecoration(
            color: palette.scaffold,
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 140,
                            width: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  height: 140,
                                  width: 140,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 6,
                                    color: mood.color,
                                    backgroundColor:
                                        mood.color.withValues(alpha: 0.08),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor:
                                      mood.color.withValues(alpha: 0.04),
                                  child: Text(
                                    '$_level',
                                    style:
                                        theme.textTheme.displaySmall?.copyWith(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Lora',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final controller = TextEditingController(text: settings.userName);
                              final name = await showDialog<String>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    backgroundColor: palette.scaffold,
                                    title: Text(
                                      'Preferred Name',
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () => Navigator.of(context).pop(controller.text),
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (name != null) {
                                await ThemeService.instance.setUserName(name);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    settings.userName ?? 'Add your name',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: palette.seed,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.edit_rounded, size: 16, color: palette.seed),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_totalXp / $nextLevelXp XP',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department_rounded,
                            value: '$_streak',
                            label: 'day streak',
                            color: Colors.deepOrangeAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.library_books_rounded,
                            value: '$_totalEntries',
                            label: 'total logs',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: null,
                            emoji: mood.emoji,
                            value: '',
                            label: 'this week',
                            color: mood.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Weekly intensity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          minY: 0,
                          maxY: 10,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: _weeklyAverages
                              .asMap()
                              .entries
                              .map(
                                (entry) => BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value,
                                      width: 18,
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color(0xB37F77DD),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 2,
                                getTitlesWidget: (value, _) => Text(
                                  value.toInt().toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  final date = DateTime.now().subtract(
                                      Duration(days: 6 - value.toInt()));
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      DateFormat('EEE').format(date),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Milestones',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _badgeDefinitions.map((badge) {
                        final unlocked = _badgeIds.contains(badge.id);
                        return SizedBox(
                          width: (MediaQuery.of(context).size.width - 52) / 2,
                          child: _BadgeTile(
                            badge: badge,
                            unlocked: unlocked,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Long-term Clarity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _InsightTriggerCard(
                          title: 'Weekly Summary',
                          subtitle:
                              'Get an AI analysis of your emotional patterns over the last 7 days.',
                          icon: Icons.calendar_view_week_rounded,
                          state: _weeklyState,
                          insightText: _weeklyText,
                          onTrigger: _fetchWeeklyInsight,
                          onDismiss: () =>
                              setState(() => _weeklyState = InsightState.idle),
                        ),
                        const SizedBox(height: 16),
                        _InsightTriggerCard(
                          title: 'Monthly Theme',
                          subtitle:
                              'Identify the driving themes of your inner weather for the last 30 days.',
                          icon: Icons.brightness_auto_rounded,
                          state: _monthlyState,
                          insightText: _monthlyText,
                          onTrigger: _fetchMonthlyInsight,
                          onDismiss: () =>
                              setState(() => _monthlyState = InsightState.idle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InsightTriggerCard extends StatelessWidget {
  const _InsightTriggerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
    required this.insightText,
    required this.onTrigger,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final InsightState state;
  final String? insightText;
  final VoidCallback onTrigger;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (state != InsightState.idle) {
      return InsightCard(
        state: state,
        insightText: insightText,
        moodColor: Theme.of(context).colorScheme.primary,
        onDismiss: onDismiss,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTrigger,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded, 
                size: 14, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
    this.emoji,
  });

  final IconData? icon;
  final String? emoji;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 20)
          else
            Text(
              emoji ?? '',
              style: const TextStyle(fontSize: 22),
            ),
          const SizedBox(height: 10),
          if (value.isNotEmpty)
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.unlocked,
  });

  final _BadgeDefinition badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = unlocked
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.2);
        
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.08)),
              ),
              child: Icon(badge.icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeDefinition {
  const _BadgeDefinition({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const List<_BadgeDefinition> _badgeDefinitions = [
  _BadgeDefinition(id: 'first_log', label: 'First log', icon: Icons.star),
  _BadgeDefinition(
    id: 'streak_3',
    label: '3-day streak',
    icon: Icons.local_fire_department,
  ),
  _BadgeDefinition(
    id: 'streak_7',
    label: 'Week warrior',
    icon: Icons.emoji_events,
  ),
  _BadgeDefinition(
    id: 'streak_30',
    label: 'Monthly habit',
    icon: Icons.workspace_premium,
  ),
  _BadgeDefinition(id: 'level_5', label: 'Level 5', icon: Icons.trending_up),
  _BadgeDefinition(id: 'level_10', label: 'Level 10', icon: Icons.bolt),
  _BadgeDefinition(
    id: 'night_owl',
    label: 'Night owl',
    icon: Icons.nightlight,
  ),
  _BadgeDefinition(
    id: 'early_bird',
    label: 'Early bird',
    icon: Icons.wb_sunny,
  ),
  _BadgeDefinition(
    id: 'consistent',
    label: 'Consistent',
    icon: Icons.repeat,
  ),
];
