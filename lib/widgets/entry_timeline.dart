import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/mood_log.dart';

class EntryTimeline extends StatelessWidget {
  const EntryTimeline({
    super.key,
    required this.entries,
    required this.moodMap,
  });

  final List<MoodLog> entries;
  final Map<String, Map<String, dynamic>> moodMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No entries yet today',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final mood = moodMap[entry.mood] ?? moodMap['happy']!;
          final color = mood['color'] as Color;
          final label = mood['label'] as String;
          final time = 'Daily Log';

          return ActionChip(
            backgroundColor: color.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: color.withValues(alpha: 0.18)),
            ),
            label: Text(
              '${mood['emoji']}  $time',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => _showEntryDetail(
              context: context,
              moodLabel: label,
              moodEmoji: mood['emoji'] as String,
              color: color,
              intensity: entry.intensity,
              note: entry.note,
              timestamp: entry.date,
            ),
          );
        },
      ),
    );
  }

  void _showEntryDetail({
    required BuildContext context,
    required String moodLabel,
    required String moodEmoji,
    required Color color,
    required int intensity,
    required String? note,
    required String? timestamp,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final parsedTime =
            DateTime.tryParse(timestamp ?? '') ?? DateTime.now();
        final intensityDots = List.generate(
          5,
          (index) => index < (intensity / 2).ceil() ? '●' : '○',
        ).join();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    moodEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      moodLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailLine(
                label: 'Intensity',
                value: '$intensity/10  $intensityDots',
                color: color,
              ),
              const SizedBox(height: 10),
              _DetailLine(
                label: 'Date',
                value: DateFormat('EEE, d MMM').format(parsedTime),
                color: color,
              ),
              if (note != null && note.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Note',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  note,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
