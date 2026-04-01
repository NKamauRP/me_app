class MoodLog {
  const MoodLog({
    this.id,
    required this.date,
    required this.mood,
    required this.intensity,
    required this.note,
  });

  final int? id;
  final String date;
  final String mood;
  final int intensity;
  final String note;

  MoodLog copyWith({
    int? id,
    String? date,
    String? mood,
    int? intensity,
    String? note,
  }) {
    return MoodLog(
      id: id ?? this.id,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      intensity: intensity ?? this.intensity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'mood': mood,
      'intensity': intensity,
      'note': note,
    };
  }

  factory MoodLog.fromMap(Map<String, dynamic> map) {
    return MoodLog(
      id: map['id'] as int?,
      date: map['date'] as String,
      mood: map['mood'] as String,
      intensity: map['intensity'] as int? ?? 5,
      note: map['note'] as String,
    );
  }
}
