import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../models/checkin_result.dart';
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
  bool _showCardPulse = false;
  bool _showFullCelebration = false;

  Timer? _xpTimer;
  Timer? _pulseTimer;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (!widget.result.alreadyCheckedIn && widget.result.totalXp > 0) {
        _startXpFloat();
        _startCardPulse();
      }

      final rewardCue = _rewardCueForResult();
      if (rewardCue == null) {
        return;
      }

      if (rewardCue.cardPulse) {
        _startCardPulse();
      }

      if (rewardCue.showXpFloat) {
        _startXpFloat();
      }

      if (rewardCue.confettiStyle != FeedbackConfettiStyle.none) {
        setState(() {
          _showFullCelebration =
              rewardCue.confettiStyle == FeedbackConfettiStyle.levelUp;
        });
        _confettiController.play();
      }
    });
  }

  FeedbackCue? _rewardCueForResult() {
    if (widget.result.leveledUp) {
      return FeedbackService.instance.levelUp();
    }

    if (_isStreakMilestone(widget.result)) {
      return FeedbackService.instance.streakMilestone();
    }

    return null;
  }

  void _startXpFloat() {
    setState(() => _showXpFloat = true);
    _xpTimer?.cancel();
    _xpTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() => _showXpFloat = false);
      }
    });
  }

  void _startCardPulse() {
    setState(() => _showCardPulse = true);
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showCardPulse = false);
      }
    });
  }

  @override
  void dispose() {
    _xpTimer?.cancel();
    _pulseTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.select(
      (ThemeService settings) => AppTheme.paletteOf(settings.currentTheme),
    );

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        RevealOnBuild(
                          child: _ResultCard(
                            mood: widget.mood,
                            result: widget.result,
                            palette: palette,
                            showCardPulse: _showCardPulse,
                            showXpFloat: _showXpFloat,
                          ),
                        ),
                        IgnorePointer(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConfettiWidget(
                              confettiController: _confettiController,
                              blastDirectionality: BlastDirectionality.explosive,
                              shouldLoop: false,
                              emissionFrequency:
                                  _showFullCelebration ? 0.08 : 0.14,
                              numberOfParticles:
                                  _showFullCelebration ? 28 : 12,
                              maxBlastForce: _showFullCelebration ? 24 : 14,
                              minBlastForce: _showFullCelebration ? 12 : 7,
                              gravity: _showFullCelebration ? 0.18 : 0.24,
                              colors: [
                                palette.accent,
                                palette.seed,
                                widget.mood.color,
                                Colors.white,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.mood,
    required this.result,
    required this.palette,
    required this.showCardPulse,
    required this.showXpFloat,
  });

  final MoodOption mood;
  final CheckInResult result;
  final AppThemePalette palette;
  final bool showCardPulse;
  final bool showXpFloat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streakFlavor = streakFlavorFor(result.stats.streak);
    final levelFlavor = levelFlavorFor(result.stats.level);
    final insightAccent = Color(result.dailyInsight.accentColor);

    return AnimatedScale(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      scale: showCardPulse ? 1.015 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: mood.color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            if (showCardPulse)
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: showXpFloat ? Offset.zero : const Offset(0, -0.25),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: showXpFloat ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    result.totalXp > 0
                        ? '+${result.totalXp} XP'
                        : 'Reflection updated',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.seed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            CircleAvatar(
              radius: 34,
              backgroundColor: mood.color.withValues(alpha: 0.18),
              child: Text(
                mood.emoji,
                style: const TextStyle(fontSize: 34),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              result.alreadyCheckedIn
                  ? 'Today\'s check-in was updated'
                  : 'You showed up today',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 10),
            Text(
              result.alreadyCheckedIn
                  ? 'You already earned today\'s rewards, but your reflection was saved.'
                  : 'Your ${mood.label.toLowerCase()} reflection is saved for ${AppDateUtils.readableDate(result.log.date)}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: palette.seed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    '+${result.totalXp} XP',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: palette.seed,
                      fontSize: 30,
                    ),
                  ),
                  if (result.streakBonusXp > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Includes +${result.streakBonusXp} streak bonus',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.seed,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaChip(
                  label: '${mood.label} logged',
                  color: mood.color,
                ),
                _MetaChip(
                  label: 'Intensity ${result.log.intensity}/10',
                  color: palette.accent,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionPanel(
              title: 'Your progress today',
              accent: palette.seed,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumn = constraints.maxWidth < 360;
                  final streakTile = _SummaryTile(
                    eyebrow: 'Streak',
                    title: 'Streak: ${result.stats.streak} days \u{1F525}',
                    subtitle: streakFlavor.title,
                    tint: mood.color.withValues(alpha: 0.12),
                    accent: mood.color,
                  );
                  final levelTile = _SummaryTile(
                    eyebrow: 'Level',
                    title: 'Level ${result.stats.level} | ${result.stats.xp} total XP',
                    subtitle: levelFlavor.title,
                    tint: palette.seed.withValues(alpha: 0.10),
                    accent: palette.seed,
                    animateSubtitle: true,
                  );

                  if (useColumn) {
                    return Column(
                      children: [
                        streakTile,
                        const SizedBox(height: 12),
                        levelTile,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: streakTile),
                      const SizedBox(width: 12),
                      Expanded(child: levelTile),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _SectionPanel(
              title: 'Daily Insight',
              accent: insightAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.dailyInsight.title,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.dailyInsight.message,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            if (result.leveledUp) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: palette.seed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Level up unlocked',
                        style: theme.textTheme.titleMedium?.copyWith(
                              color: palette.seed,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
    this.animateSubtitle = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;
  final bool animateSubtitle;

  @override
  Widget build(BuildContext context) {
    final subtitleWidget = Text(
      subtitle,
      key: ValueKey<String>(subtitle),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: accent,
          ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          animateSubtitle
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: subtitleWidget,
                )
              : subtitleWidget,
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.accent,
    required this.child,
  });

  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

bool _isStreakMilestone(CheckInResult result) {
  if (result.alreadyCheckedIn) {
    return false;
  }

  const milestones = <int>{3, 7, 14};
  return milestones.contains(result.stats.streak);
}
