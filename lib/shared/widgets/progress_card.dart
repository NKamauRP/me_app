import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../features/mind/daily_insight.dart';
import '../../models/mood_log.dart';
import '../../models/user_stats.dart';
import 'glass_panel.dart';

class ProgressCard extends StatefulWidget {
  const ProgressCard({
    super.key,
    required this.stats,
    required this.levelFlavor,
    required this.weeklyLogs,
    required this.accentColor,
    required this.seedColor,
  });

  final UserStats stats;
  final ProgressFlavor levelFlavor;
  final List<MoodLog> weeklyLogs;
  final Color accentColor;
  final Color seedColor;

  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  late double _previousProgress;
  bool _showProgressGlow = false;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _previousProgress = widget.stats.progressToNextLevel;
  }

  @override
  void didUpdateWidget(covariant ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats.xp != widget.stats.xp) {
      _previousProgress = oldWidget.stats.progressToNextLevel;
      _showXpGlowPulse();
    }
  }

  @override
  void dispose() {
    _glowTimer?.cancel();
    super.dispose();
  }

  void _showXpGlowPulse() {
    setState(() => _showProgressGlow = true);
    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) {
        setState(() => _showProgressGlow = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      scale: _showProgressGlow ? 1.02 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.seedColor.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights & Progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontFamily: 'Lora',
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your consistency and growth',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.seedColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LEVEL ${widget.stats.level}',
                    style: TextStyle(
                      color: widget.seedColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.stats.xpIntoCurrentLevel}/50 XP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: widget.seedColor,
                      ),
                ),
                Text(
                  'Next level in ${50 - widget.stats.xpIntoCurrentLevel} XP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: _previousProgress,
                  end: widget.stats.progressToNextLevel,
                ),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutQuart,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    minHeight: 8,
                    value: value,
                    backgroundColor: widget.seedColor.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.seedColor),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Current Streak',
                    value: '🔥 ${widget.stats.streak} days',
                    accentColor: widget.seedColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Archetype',
                    value: widget.levelFlavor.title,
                    accentColor: widget.seedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MiniWeeklyGraph(
              logs: widget.weeklyLogs,
              lineColor: widget.seedColor,
              accentColor: widget.seedColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _MiniWeeklyGraph extends StatelessWidget {
  const _MiniWeeklyGraph({
    required this.logs,
    required this.lineColor,
    required this.accentColor,
  });

  final List<MoodLog> logs;
  final Color lineColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final days = AppDateUtils.lastNDates(7);
    final logsByDate = <String, MoodLog>{
      for (final log in logs) log.date: log,
    };
    final values = List<double>.generate(days.length, (index) {
      final key = AppDateUtils.toStorageDate(days[index]);
      return (logsByDate[key]?.intensity ?? 0).toDouble();
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lineColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly mood',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            logs.isEmpty
                ? 'Your trend will appear after your first check-ins.'
                : 'A quick look at your last seven days.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: CustomPaint(
              // A tiny sparkline gives trend context while keeping the dashboard
              // visually quiet and much lighter than a full chart component.
              painter: _SparklinePainter(
                values: values,
                lineColor: lineColor,
                accentColor: accentColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days
                .map(
                  (day) => Text(
                    AppDateUtils.shortWeekday(day),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.accentColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), basePaint);
    }

    final nonZero = values.where((value) => value > 0).toList();
    if (nonZero.isEmpty) {
      final dotPaint = Paint()..color = lineColor.withValues(alpha: 0.22);
      for (var i = 0; i < values.length; i++) {
        final dx = _xForIndex(i, values.length, size.width);
        canvas.drawCircle(Offset(dx, size.height * 0.7), 4, dotPaint);
      }
      return;
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = _xForIndex(i, values.length, size.width);
      final normalized = values[i] == 0 ? 0.16 : values[i] / 10;
      final y = size.height - (normalized * size.height * 0.88) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final previousX = _xForIndex(i - 1, values.length, size.width);
        final controlX = (previousX + x) / 2;
        final previousNormalized = values[i - 1] == 0 ? 0.16 : values[i - 1] / 10;
        final previousY =
            size.height - (previousNormalized * size.height * 0.88) - 6;
        path.cubicTo(controlX, previousY, controlX, y, x, y);
      }
    }

    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.18),
          accentColor.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = accentColor;
    final dotOutline = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      final x = _xForIndex(i, values.length, size.width);
      final normalized = values[i] == 0 ? 0.16 : values[i] / 10;
      final y = size.height - (normalized * size.height * 0.88) - 6;
      canvas.drawCircle(Offset(x, y), 4.6, dotOutline);
      canvas.drawCircle(Offset(x, y), 3.2, dotPaint);
    }
  }

  double _xForIndex(int index, int count, double width) {
    if (count <= 1) {
      return width / 2;
    }
    return (width / (count - 1)) * index;
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) {
      return true;
    }

    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }

    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor;
  }
}
