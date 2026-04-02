import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../models/mood_log.dart';
import '../../shared/widgets/glass_panel.dart';
import 'micro_interactions.dart';
import 'mood_catalog.dart';

class WeeklyMoodGraph extends StatelessWidget {
  const WeeklyMoodGraph({
    super.key,
    required this.logs,
  });

  final List<MoodLog> logs;

  @override
  Widget build(BuildContext context) {
    final days = AppDateUtils.lastNDates(7);
    final logsByDate = <String, MoodLog>{
      for (final log in logs) log.date: log,
    };
    // The graph always renders seven fixed day slots so the dashboard
    // layout stays stable even when some days have no check-in yet.
    final chartEntries = days
        .map(
          (day) => logsByDate[AppDateUtils.toStorageDate(day)],
        )
        .toList();

    return RevealOnBuild(
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly mood graph',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Intensity across your last seven days.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: const Color(0xFFE9E2D9),
                      strokeWidth: 1,
                    ),
                  ),
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
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              AppDateUtils.shortWeekday(days[index]),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7E8389),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: const Color(0xFF1D7A72),
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final log = chartEntries[index];
                          final color = log == null
                              ? const Color(0xFFD5D3CE)
                              : moodOptionById(log.mood).color;
                          return FlDotCirclePainter(
                            radius: 4.8,
                            color: color,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF1D7A72).withValues(alpha: 0.12),
                      ),
                      spots: List<FlSpot>.generate(
                        chartEntries.length,
                        (index) => FlSpot(
                          index.toDouble(),
                          (chartEntries[index]?.intensity ?? 0).toDouble(),
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(enabled: false),
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(chartEntries.length, (index) {
                final log = chartEntries[index];
                final emoji = log == null ? '...' : moodOptionById(log.mood).emoji;
                return Expanded(
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
