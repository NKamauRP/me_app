import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../models/checkin_result.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../daily_insight.dart';
import '../micro_interactions.dart';
import '../mood_catalog.dart';

class MindResultScreen extends StatefulWidget {
  const MindResultScreen({
    super.key,
    required this.mood,
    required this.result,
  });

  final MoodOption mood;
  final CheckInResult result;

  @override
  State<MindResultScreen> createState() => _MindResultScreenState();
}

class _MindResultScreenState extends State<MindResultScreen> {
  bool _showXpFloat = false;
  bool _showGlow = false;
  Timer? _xpTimer;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      setState(() => _showXpFloat = true);
      _xpTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showXpFloat = false);
        }
      });

      if (widget.result.leveledUp) {
        MindHaptics.celebrate();
        await SoundService.instance.playReward();
        if (!mounted) {
          return;
        }
        setState(() => _showGlow = true);
        _glowTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _showGlow = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _xpTimer?.cancel();
    _glowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelFlavor = levelFlavorFor(widget.result.stats.level);
    final streakFlavor = streakFlavorFor(widget.result.stats.streak);
    final palette =
        context.select((ThemeService settings) => AppTheme.paletteOf(settings.currentTheme));

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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 420),
                      scale: _showGlow ? 1.02 : 1,
                      child: GlassPanel(
                        tint: widget.mood.color.withValues(alpha: 0.14),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 420),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (_showGlow)
                                    BoxShadow(
                                      color: palette.accent.withValues(alpha: 0.44),
                                      blurRadius: 36,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    widget.mood.color.withValues(alpha: 0.18),
                                child: Text(
                                  widget.mood.emoji,
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              widget.result.alreadyCheckedIn
                                  ? 'Today\'s check-in was updated'
                                  : 'You showed up today',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.result.alreadyCheckedIn
                                  ? 'You already earned today\'s rewards, but your reflection was saved.'
                                  : 'Your ${widget.mood.label.toLowerCase()} reflection is saved for ${AppDateUtils.readableDate(widget.result.log.date)}.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Intensity ${widget.result.log.intensity}/10',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: widget.mood.color,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '+${widget.result.totalXp} XP',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: palette.seed,
                              ),
                            ),
                            if (widget.result.streakBonusXp > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '+${widget.result.streakBonusXp} streak bonus',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: palette.accent,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            GlassPanel(
                              tint: palette.seed.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Streak: ${widget.result.stats.streak} days \u{1F525}',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    streakFlavor.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: widget.mood.color,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Level ${widget.result.stats.level} | ${widget.result.stats.xp} total XP',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      levelFlavor.title,
                                      key: ValueKey<String>(levelFlavor.title),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: palette.seed,
                                      ),
                                    ),
                                  ),
                                  if (widget.result.leveledUp) ...[
                                    const SizedBox(height: 8),
                                    RevealOnBuild(
                                      child: Text(
                                        'Level up unlocked',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: palette.seed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            DailyInsightCard(insight: widget.result.dailyInsight),
                          ],
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: AnimatedPositioned(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        right: 20,
                        top: _showXpFloat ? -16 : 18,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showXpFloat ? 1 : 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+${widget.result.totalXp} XP',
                              style: const TextStyle(
                                color: Color(0xFF171717),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
