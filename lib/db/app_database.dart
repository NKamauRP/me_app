import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/mood_log.dart';
import '../models/user_stats.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = p.join(databaseDirectory, 'me_mind_journal.db');

    return openDatabase(
      databasePath,
      version: 3,
      onConfigure: (db) async {
        // WAL mode keeps reads/writes responsive as journal history grows.
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
      },
      onCreate: (db, version) async {
        await _createMoodLogsTable(db);
        await _createMoodLogsIndex(db);
        await _createUserStatsTable(db);
        await _seedUserStatsIfNeeded(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v2 keeps existing journal history intact and backfills intensity at 5.
          await _ensureMoodLogsColumn(
            db: db,
            columnName: 'intensity',
            definition: 'INTEGER NOT NULL DEFAULT 5',
          );
        }

        if (oldVersion < 3) {
          await _createMoodLogsIndex(db);
        }
      },
      onOpen: (db) async {
        await _repairLegacySchema(db);
      },
    );
  }

  Future<void> _repairLegacySchema(Database db) async {
    if (!await _tableExists(db, 'mood_logs')) {
      await _createMoodLogsTable(db);
    } else {
      await _ensureMoodLogsColumn(
        db: db,
        columnName: 'intensity',
        definition: 'INTEGER NOT NULL DEFAULT 5',
      );
      await _ensureMoodLogsColumn(
        db: db,
        columnName: 'note',
        definition: "TEXT NOT NULL DEFAULT ''",
      );
    }

    await _createMoodLogsIndex(db);

    if (!await _tableExists(db, 'user_stats')) {
      await _createUserStatsTable(db);
    }
    await _seedUserStatsIfNeeded(db);
  }

  Future<void> _createMoodLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mood_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        mood TEXT NOT NULL,
        intensity INTEGER NOT NULL DEFAULT 5,
        note TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMoodLogsIndex(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mood_logs_mood_date
      ON mood_logs(mood, date DESC)
    ''');
  }

  Future<void> _createUserStatsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats(
        id INTEGER PRIMARY KEY,
        xp INTEGER NOT NULL,
        level INTEGER NOT NULL,
        streak INTEGER NOT NULL,
        last_checkin_date TEXT
      )
    ''');
  }

  Future<void> _seedUserStatsIfNeeded(Database db) async {
    final rows = await db.query(
      'user_stats',
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return;
    }

    await db.insert(
      'user_stats',
      UserStats.initial().toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensureMoodLogsColumn({
    required Database db,
    required String columnName,
    required String definition,
  }) async {
    if (await _columnExists(db, tableName: 'mood_logs', columnName: columnName)) {
      return;
    }

    await db.execute(
      'ALTER TABLE mood_logs ADD COLUMN $columnName $definition',
    );
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );

    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(
    Database db, {
    required String tableName,
    required String columnName,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');

    return rows.any((row) => row['name'] == columnName);
  }

  Future<UserStats> ensureUserStats() async {
    final db = await database;
    final rows = await db.query(
      'user_stats',
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      final defaultStats = UserStats.initial();
      await db.insert('user_stats', defaultStats.toMap());
      return defaultStats;
    }

    return UserStats.fromMap(rows.first);
  }

  Future<void> upsertUserStats(UserStats stats) async {
    final db = await database;

    await db.insert(
      'user_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MoodLog?> getMoodLogByDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'mood_logs',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return MoodLog.fromMap(rows.first);
  }

  Future<MoodLog> insertMoodLog(MoodLog moodLog) async {
    final db = await database;
    final id = await db.insert('mood_logs', moodLog.toMap());

    return moodLog.copyWith(id: id);
  }

  Future<void> updateMoodLog(MoodLog moodLog) async {
    final db = await database;

    await db.update(
      'mood_logs',
      moodLog.toMap(),
      where: 'id = ?',
      whereArgs: [moodLog.id],
    );
  }

  Future<List<MoodLog>> fetchRecentMoodLogs({int limit = 5}) async {
    final db = await database;
    final rows = await db.query(
      'mood_logs',
      orderBy: 'date DESC',
      limit: limit,
    );

    return rows.map(MoodLog.fromMap).toList();
  }

  Future<List<MoodLog>> fetchMoodLogsBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await database;
    final rows = await db.query(
      'mood_logs',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );

    return rows.map(MoodLog.fromMap).toList();
  }

  Future<List<MoodLog>> fetchAllMoodLogs() async {
    final db = await database;
    final rows = await db.query(
      'mood_logs',
      orderBy: 'date DESC',
    );

    return rows.map(MoodLog.fromMap).toList();
  }

  Future<List<MoodLog>> fetchMoodLogsPage({
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'mood_logs',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(MoodLog.fromMap).toList();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('mood_logs');
    await db.delete('user_stats');
    await db.insert(
      'user_stats',
      UserStats.initial().toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
