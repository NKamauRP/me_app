import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._init();

  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('moodlog.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);

    return openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mood_entries (
        id TEXT PRIMARY KEY,
        mood_id TEXT NOT NULL,
        custom_label TEXT,
        intensity INTEGER NOT NULL,
        note TEXT,
        timestamp TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_xp (
        date TEXT PRIMARY KEY,
        xp_earned INTEGER DEFAULT 0,
        entries_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE insights (
        date TEXT PRIMARY KEY,
        instant_insight TEXT,
        daily_insight TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_mood_entries_date_time ON mood_entries(date, timestamp)',
    );
  }

  Future<String> insertEntry(Map<String, dynamic> entry) async {
    final db = await database;
    await db.insert(
      'mood_entries',
      entry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return entry['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getEntriesForDate(String date) async {
    final db = await database;
    return db.query(
      'mood_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getEntriesForWeek(String startDate) async {
    final db = await database;
    return db.query(
      'mood_entries',
      where: 'date >= ?',
      whereArgs: [startDate],
      orderBy: 'date ASC, timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllEntries() async {
    final db = await database;
    return db.query(
      'mood_entries',
      orderBy: 'date DESC, timestamp DESC',
    );
  }

  Future<int> getDailyXP(String date) async {
    final db = await database;
    final result = await db.query(
      'daily_xp',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (result.isEmpty) {
      return 0;
    }
    return (result.first['xp_earned'] as int?) ?? 0;
  }

  Future<void> updateDailyXP(String date, int xpToAdd) async {
    final db = await database;
    final result = await db.query(
      'daily_xp',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    final currentXp = result.isEmpty ? 0 : (result.first['xp_earned'] as int? ?? 0);
    final currentEntries =
        result.isEmpty ? 0 : (result.first['entries_count'] as int? ?? 0);

    await db.insert(
      'daily_xp',
      {
        'date': date,
        'xp_earned': currentXp + xpToAdd,
        'entries_count': currentEntries + 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveInsight(
    String date, {
    String? instant,
    String? daily,
  }) async {
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
        ...?(instant == null ? null : {'instant_insight': instant}),
        ...?(daily == null ? null : {'daily_insight': daily}),
        'updated_at': now,
      },
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<Map<String, dynamic>?> getInsight(String date) async {
    final db = await database;
    final result = await db.query(
      'insights',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'moodlog.db');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await deleteDatabase(path);
    _database = await _initDB('moodlog.db');
  }
}
