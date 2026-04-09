import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';
import '../data/mood_aggregator.dart';
import '../data/xp_engine.dart';
import '../features/mind/mood_catalog.dart';
import '../services/ai_service.dart';
import '../widgets/insight_card.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final allEntries = await DatabaseHelper.instance.getAllEntries();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final weekEntries = await DatabaseHelper.instance.getEntriesForWeek(
      DateFormat('yyyy-MM-dd').format(start),
    );

    final weeklyAverages = List<double>.filled(7, 0);
    final groupedByDate = <String, List<Map<String, dynamic>>>{};
    for (final entry in weekEntries) {
      final date = entry['date'] as String;
      groupedByDate.putIfAbsent(date, () => <Map<String, dynamic>>[]).add(entry);
    }

    for (var index = 0; index < 7; index++) {
      final date = start.add(Duration(days: index));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final items = groupedByDate[key] ?? const <Map<String, dynamic>>[];
      if (items.isEmpty) {
        weeklyAverages[index] = 0;
        continue;
      }

      final total = items
          .map((entry) => entry['intensity'] as int)
          .reduce((a, b) => a + b);
      weeklyAverages[index] = total / items.length;
    }

    final dominantMoodId = _dominantMoodForEntries(weekEntries);
    final badgeIds = _unlockBadges(
      entries: allEntries,
      level: XPEngine.calculateLevel(prefs.getInt('total_xp') ?? 0),
      maxStreak: prefs.getInt('max_streak') ?? 0,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _totalXp = prefs.getInt('total_xp') ?? 0;
      _level = XPEngine.calculateLevel(_totalXp);
      _streak = prefs.getInt('streak_days') ?? 0;
      _totalEntries = allEntries.length;
      _dominantMoodId = dominantMoodId;
      _weeklyAverages = weeklyAverages;
      _badgeIds = badgeIds;
      _isLoading = false;
    });
  }

  String _dominantMoodForEntries(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return 'calm';
    }

    final counts = <String, int>{};
    for (final entry in entries) {
      final moodId = entry['mood_id'] as String? ?? 'calm';
      counts[moodId] = (counts[moodId] ?? 0) + 1;
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Set<String> _unlockBadges({
    required List<Map<String, dynamic>> entries,
    required int level,
    required int maxStreak,
  }) {
    final dayCounts = <String, int>{};
    var nightOwl = false;
    var earlyBird = false;

    for (final entry in entries) {
      final timestamp = DateTime.tryParse(entry['timestamp'] as String? ?? '');
      if (timestamp != null) {
        if (timestamp.hour >= 22) {
          nightOwl = true;
        }
        if (timestamp.hour < 7) {
          earlyBird = true;
        }
      }

      final date = entry['date'] as String;
      dayCounts[date] = (dayCounts[date] ?? 0) + 1;
    }

    final consistent = dayCounts.values.any((count) => count >= 3);
    final ids = <String>{};

    if (entries.isNotEmpty) ids.add('first_log');
    if (maxStreak >= 3) ids.add('streak_3');
    if (maxStreak >= 7) ids.add('streak_7');
    if (maxStreak >= 30) ids.add('streak_30');
    if (level >= 5) ids.add('level_5');
    if (level >= 10) ids.add('level_10');
    if (nightOwl) ids.add('night_owl');
    if (earlyBird) ids.add('early_bird');
    if (consistent) ids.add('consistent');

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
    final mood = moodOptionById(_dominantMoodId);
    final nextLevelXp = XPEngine.xpForNextLevel(_level);
    final progress = nextLevelXp <= 0 ? 0.0 : (_totalXp / nextLevelXp).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 132,
                        width: 132,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 132,
                              width: 132,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                color: mood.color,
                                backgroundColor:
                                    mood.color.withValues(alpha: 0.12),
                              ),
                            ),
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: mood.color.withValues(alpha: 0.12),
                              child: Text(
                                '$_level',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$_totalXp / $nextLevelXp XP',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
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
                const SizedBox(height: 24),
                Text(
                  'Weekly intensity',
                  style: Theme.of(context).textTheme.titleLarge,
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
                              final date = DateTime.now()
                                  .subtract(Duration(days: 6 - value.toInt()));
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('EEE').format(date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Milestones',
                  style: Theme.of(context).textTheme.titleLarge,
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    _InsightTriggerCard(
                      title: 'Weekly Summary',
                      subtitle: 'Get an AI analysis of your emotional patterns over the last 7 days.',
                      icon: Icons.calendar_view_week_rounded,
                      state: _weeklyState,
                      insightText: _weeklyText,
                      onTrigger: _fetchWeeklyInsight,
                      onDismiss: () => setState(() => _weeklyState = InsightState.idle),
                    ),
                    const SizedBox(height: 16),
                    _InsightTriggerCard(
                      title: 'Monthly Theme',
                      subtitle: 'Identify the driving themes of your inner weather for the last 30 days.',
                      icon: Icons.brightness_auto_rounded,
                      state: _monthlyState,
                      insightText: _monthlyText,
                      onTrigger: _fetchMonthlyInsight,
                      onDismiss: () => setState(() => _monthlyState = InsightState.idle),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
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

    return Card(
      child: InkWell(
        onTap: onTrigger,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
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
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: [
            if (icon != null)
              Icon(icon, color: color)
            else
              Text(
                emoji ?? '',
                style: const TextStyle(fontSize: 22),
              ),
            const SizedBox(height: 8),
            if (value.isNotEmpty)
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
    final color = unlocked
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.32);
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(badge.icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                badge.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
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
