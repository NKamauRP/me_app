import 'package:flutter/foundation.dart';
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

    try {
      _database = await _openDatabase();
      return _database!;
    } catch (e) {
      debugPrint('AppDatabase.getDatabase Error: $e');
      rethrow;
    }
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
        await _createMoodEntriesTable(db);
        await _createMoodEntriesIndex(db);
        await _createDailyXpTable(db);
        await _createInsightsTable(db);
        await _seedDailyXpIfNeeded(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v2 keeps existing journal history intact and backfills intensity at 5.
          await _ensureMoodEntriesColumn(
            db: db,
            columnName: 'intensity',
            definition: 'INTEGER NOT NULL DEFAULT 5',
          );
        }

        if (oldVersion < 3) {
          await _createMoodEntriesIndex(db);
        }
      },
      onOpen: (db) async {
        await _migrateAndRepairSchema(db);
      },
    );
  }

  Future<void> _migrateAndRepairSchema(Database db) async {
    try {
      // Migrate mood_logs -> mood_entries
      if (await _tableExists(db, 'mood_logs')) {
        if (!await _tableExists(db, 'mood_entries')) {
          await db.execute('ALTER TABLE mood_logs RENAME TO mood_entries');
        } else {
          await db.execute('DROP TABLE mood_logs');
        }
      }

      // Migrate user_stats -> daily_xp
      if (await _tableExists(db, 'user_stats')) {
        if (!await _tableExists(db, 'daily_xp')) {
          await db.execute('ALTER TABLE user_stats RENAME TO daily_xp');
        } else {
          await db.execute('DROP TABLE user_stats');
        }
      }

      if (!await _tableExists(db, 'mood_entries')) {
        await _createMoodEntriesTable(db);
      } else {
        await _ensureMoodEntriesColumn(
          db: db,
          columnName: 'intensity',
          definition: 'INTEGER NOT NULL DEFAULT 5',
        );
        await _ensureMoodEntriesColumn(
          db: db,
          columnName: 'note',
          definition: "TEXT NOT NULL DEFAULT ''",
        );
      }

      await _createMoodEntriesIndex(db);

      if (!await _tableExists(db, 'daily_xp')) {
        await _createDailyXpTable(db);
      }
      await _seedDailyXpIfNeeded(db);
      
      if (!await _tableExists(db, 'insights')) {
        await _createInsightsTable(db);
      }
    } catch (e) {
      debugPrint('AppDatabase._migrateAndRepairSchema Error: $e');
    }
  }

  Future<void> _createMoodEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mood_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        mood TEXT NOT NULL,
        intensity INTEGER NOT NULL DEFAULT 5,
        note TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createInsightsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS insights(
        date TEXT PRIMARY KEY,
        instant_insight TEXT,
        daily_insight TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _createMoodEntriesIndex(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mood_entries_mood_date
      ON mood_entries(mood, date DESC)
    ''');
  }

  Future<void> _createDailyXpTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_xp(
        id INTEGER PRIMARY KEY,
        xp INTEGER NOT NULL,
        level INTEGER NOT NULL,
        streak INTEGER NOT NULL,
        last_checkin_date TEXT
      )
    ''');
  }

  Future<void> _seedDailyXpIfNeeded(Database db) async {
    final rows = await db.query(
      'daily_xp',
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return;
    }

    await db.insert(
      'daily_xp',
      UserStats.initial().toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensureMoodEntriesColumn({
    required Database db,
    required String columnName,
    required String definition,
  }) async {
    if (await _columnExists(db, tableName: 'mood_entries', columnName: columnName)) {
      return;
    }

    await db.execute(
      'ALTER TABLE mood_entries ADD COLUMN $columnName $definition',
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
      'daily_xp',
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      final defaultStats = UserStats.initial();
      await db.insert('daily_xp', defaultStats.toMap());
      return defaultStats;
    }

    return UserStats.fromMap(rows.first);
  }

  Future<void> upsertUserStats(UserStats stats) async {
    final db = await database;

    await db.insert(
      'daily_xp',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MoodLog?> getMoodLogByDate(String date) async {
    try {
      final db = await database;
      final rows = await db.query(
        'mood_entries',
        where: 'date = ?',
        whereArgs: [date],
        limit: 1,
      );

      if (rows.isEmpty) {
        return null;
      }

      return MoodLog.fromMap(rows.first);
    } catch (e) {
      debugPrint('AppDatabase.getMoodLogByDate Error: $e');
      return null;
    }
  }

  Future<MoodLog> insertMoodLog(MoodLog moodLog) async {
    try {
      final db = await database;
      final id = await db.insert('mood_entries', moodLog.toMap());
      return moodLog.copyWith(id: id);
    } catch (e) {
      debugPrint('AppDatabase.insertMoodLog Error: $e');
      rethrow;
    }
  }

  Future<void> updateMoodLog(MoodLog moodLog) async {
    try {
      final db = await database;
      await db.update(
        'mood_entries',
        moodLog.toMap(),
        where: 'id = ?',
        whereArgs: [moodLog.id],
      );
    } catch (e) {
      debugPrint('AppDatabase.updateMoodLog Error: $e');
    }
  }

  Future<List<MoodLog>> fetchRecentMoodLogs({int limit = 5}) async {
    try {
      final db = await database;
      final rows = await db.query(
        'mood_entries',
        orderBy: 'date DESC',
        limit: limit,
      );
      return rows.map(MoodLog.fromMap).toList();
    } catch (e) {
      debugPrint('AppDatabase.fetchRecentMoodLogs Error: $e');
      return [];
    }
  }

  Future<List<MoodLog>> fetchMoodLogsBetween({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        'mood_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC',
      );
      return rows.map(MoodLog.fromMap).toList();
    } catch (e) {
      debugPrint('AppDatabase.fetchMoodLogsBetween Error: $e');
      return [];
    }
  }

  Future<List<MoodLog>> fetchAllMoodLogs() async {
    try {
      final db = await database;
      final rows = await db.query(
        'mood_entries',
        orderBy: 'date DESC',
      );
      return rows.map(MoodLog.fromMap).toList();
    } catch (e) {
      debugPrint('AppDatabase.fetchAllMoodLogs Error: $e');
      return [];
    }
  }

  Future<List<MoodLog>> fetchMoodLogsPage({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        'mood_entries',
        orderBy: 'date DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map(MoodLog.fromMap).toList();
    } catch (e) {
      debugPrint('AppDatabase.fetchMoodLogsPage Error: $e');
      return [];
    }
  }

  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.delete('mood_entries');
      await db.delete('daily_xp');
      await db.insert(
        'daily_xp',
        UserStats.initial().toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('AppDatabase.clearAllData Error: $e');
    }
  }

  Future<void> saveInsight(
    String date, {
    String? instant,
    String? daily,
  }) async {
    try {
      final db = await database;
      final existing = await db.query(
        'insights',
        where: 'date = ?',
        whereArgs: [date],
        limit: 1,
      );
      final now = DateTime.now().toIso8601String();

      if (existing.isEmpty) {
        await db.insert(
          'insights',
          {
            'date': date,
            'instant_insight': instant,
            'daily_insight': daily,
            'updated_at': now,
          },
        );
        return;
      }

      await db.update(
        'insights',
        {
          if (instant != null) 'instant_insight': instant,
          if (daily != null) 'daily_insight': daily,
          'updated_at': now,
        },
        where: 'date = ?',
        whereArgs: [date],
      );
    } catch (e) {
      debugPrint('AppDatabase.saveInsight Error: $e');
    }
  }

  Future<Map<String, dynamic>?> getInsight(String date) async {
    try {
      final db = await database;
      final result = await db.query(
        'insights',
        where: 'date = ?',
        whereArgs: [date],
        limit: 1,
      );
      return result.isEmpty ? null : result.first;
    } catch (e) {
      debugPrint('AppDatabase.getInsight Error: $e');
      return null;
    }
  }
}
