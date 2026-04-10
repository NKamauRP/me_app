import '../db/app_database.dart';

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
    final entry = await AppDatabase.instance.getMoodLogByDate(date);
    if (entry == null) {
      return null;
    }

    final notes = entry.note.trim().isNotEmpty ? [entry.note] : const <String>[];

    return DayAggregate(
      dominantMood: entry.mood,
      avgIntensity: entry.intensity.toDouble(),
      arc: 'stable',
      notes: notes,
      entryCount: 1,
    );
  }

  static Future<Map<String, dynamic>?> aggregateRange(int days) async {
    final entries = await AppDatabase.instance.fetchMoodLogsBetween(
      startDate: DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10),
      endDate: DateTime.now().toIso8601String().substring(0, 10),
    );

    if (entries.isEmpty) return null;

    final counts = <String, int>{};
    double totalIntensity = 0;
    final notes = <String>[];

    for (final entry in entries) {
      counts[entry.mood] = (counts[entry.mood] ?? 0) + 1;
      totalIntensity += entry.intensity;
      if (entry.note.trim().isNotEmpty) {
        notes.add(entry.note);
      }
    }

    final dominantMood = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return {
      'dominantMood': dominantMood,
      'avgIntensity': (totalIntensity / entries.length).toStringAsFixed(1),
      'entryCount': entries.length,
      'notes': notes.take(10).toList(),
      'moodDistribution': counts,
    };
  }
}
