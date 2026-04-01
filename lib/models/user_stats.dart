class UserStats {
  const UserStats({
    required this.id,
    required this.xp,
    required this.level,
    required this.streak,
    required this.lastCheckinDate,
  });

  final int id;
  final int xp;
  final int level;
  final int streak;
  final String? lastCheckinDate;

  double get progressToNextLevel => (xp % 50) / 50;

  int get xpIntoCurrentLevel => xp % 50;

  int get xpRemainingToNextLevel => 50 - xpIntoCurrentLevel;

  UserStats copyWith({
    int? id,
    int? xp,
    int? level,
    int? streak,
    String? lastCheckinDate,
    bool clearLastCheckinDate = false,
  }) {
    return UserStats(
      id: id ?? this.id,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      lastCheckinDate: clearLastCheckinDate
          ? null
          : lastCheckinDate ?? this.lastCheckinDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'xp': xp,
      'level': level,
      'streak': streak,
      'last_checkin_date': lastCheckinDate,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      id: map['id'] as int,
      xp: map['xp'] as int,
      level: map['level'] as int,
      streak: map['streak'] as int,
      lastCheckinDate: map['last_checkin_date'] as String?,
    );
  }

  factory UserStats.initial() {
    return const UserStats(
      id: 1,
      xp: 0,
      level: 1,
      streak: 0,
      lastCheckinDate: null,
    );
  }
}
