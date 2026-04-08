import 'database_helper.dart';

class DayAggregate {
  const DayAggregate({
    required this.dominantMood,
    required this.avgIntensity,
    required this.arc,
    required this.notes,
    required this.entryCount,
  });

  final String dominantMood;
  final double avgIntensity;
  final String arc;
  final List<String> notes;
  final int entryCount;
}

class MoodAggregator {
  static Future<DayAggregate?> aggregateDay(String date) async {
    final entries = await DatabaseHelper.instance.getEntriesForDate(date);
    if (entries.isEmpty) {
      return null;
    }

    final counts = <String, int>{};
    for (final entry in entries) {
      final id = entry['mood_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final dominantMood = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final totalIntensity = entries
        .map((entry) => entry['intensity'] as int)
        .reduce((a, b) => a + b);
    final avgIntensity = totalIntensity / entries.length;

    final firstIntensity = entries.first['intensity'] as int;
    final lastIntensity = entries.last['intensity'] as int;
    final arc = switch (lastIntensity.compareTo(firstIntensity)) {
      > 0 => 'improving',
      < 0 => 'declining',
      _ => 'stable',
    };

    final notes = entries
        .map((entry) => entry['note'] as String?)
        .whereType<String>()
        .where((note) => note.trim().isNotEmpty)
        .toList(growable: false);

    return DayAggregate(
      dominantMood: dominantMood,
      avgIntensity: double.parse(avgIntensity.toStringAsFixed(1)),
      arc: arc,
      notes: notes,
      entryCount: entries.length,
    );
  }
}
