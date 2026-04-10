import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._();
  ChatDatabase._();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'companion_chat.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        // One row per conversation thread
        await db.execute('''
          CREATE TABLE chat_sessions (
            id         TEXT PRIMARY KEY,
            title      TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_pinned  INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // One row per message inside a thread
        await db.execute('''
          CREATE TABLE chat_messages (
            id         TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role       TEXT NOT NULL,
            content    TEXT NOT NULL,
            timestamp  TEXT NOT NULL,
            FOREIGN KEY (session_id)
              REFERENCES chat_sessions(id) ON DELETE CASCADE
          )
        ''');

        // Stores facts the app has learned about the user
        await db.execute('''
          CREATE TABLE user_memory (
            key        TEXT PRIMARY KEY,
            value      TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── Sessions ────────────────────────────────────────────────────

  Future<String> createSession(String title) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await db.insert('chat_sessions', {
        'id': id,
        'title': title,
        'created_at': now,
        'updated_at': now,
        'is_pinned': 0,
      });
      return id;
    } catch (e) {
      debugPrint('ChatDatabase.createSession Error: $e');
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final db = await database;
      return db.query(
        'chat_sessions',
        orderBy: 'is_pinned DESC, updated_at DESC',
      );
    } catch (e) {
      debugPrint('ChatDatabase.getAllSessions Error: $e');
      return [];
    }
  }

  Future<void> updateSessionTitle(String id, String title) async {
    try {
      final db = await database;
      await db.update(
        'chat_sessions',
        {'title': title},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('ChatDatabase.updateSessionTitle Error: $e');
    }
  }

  Future<void> touchSession(String id) async {
    try {
      final db = await database;
      await db.update(
        'chat_sessions',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('ChatDatabase.touchSession Error: $e');
    }
  }

  Future<void> togglePin(String id, bool pinned) async {
    try {
      final db = await database;
      await db.update(
        'chat_sessions',
        {'is_pinned': pinned ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('ChatDatabase.togglePin Error: $e');
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final db = await database;
      await db.delete(
        'chat_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
      // Explicit delete of messages is now redundant due to ON DELETE CASCADE
      // but keeping it doesn't hurt if foreign keys were somehow disabled.
    } catch (e) {
      debugPrint('ChatDatabase.deleteSession Error: $e');
    }
  }

  // ── Messages ────────────────────────────────────────────────────

  Future<void> insertMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      final id = '${sessionId}_${now}';
      await db.insert('chat_messages', {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content,
        'timestamp': now,
      });
      await touchSession(sessionId);
    } catch (e) {
      debugPrint('ChatDatabase.insertMessage Error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String sessionId, {
    int limit = 50,
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        'chat_messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return rows.reversed.toList();
    } catch (e) {
      debugPrint('ChatDatabase.getMessages Error: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getHistoryForInference(
    String sessionId, {
    int limit = 20,
  }) async {
    try {
      final messages = await getMessages(sessionId, limit: limit);
      return messages
          .map((m) => {
                'role': m['role'] as String,
                'content': m['content'] as String,
              })
          .toList();
    } catch (e) {
      debugPrint('ChatDatabase.getHistoryForInference Error: $e');
      return [];
    }
  }

  // ── User Memory ─────────────────────────────────────────────────

  Future<void> saveMemory(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'user_memory',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('ChatDatabase.saveMemory Error: $e');
    }
  }

  Future<String?> getMemory(String key) async {
    try {
      final db = await database;
      final rows = await db.query(
        'user_memory',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e) {
      debugPrint('ChatDatabase.getMemory Error: $e');
      return null;
    }
  }

  Future<Map<String, String>> getAllMemory() async {
    try {
      final db = await database;
      final rows = await db.query('user_memory');
      return {
        for (final r in rows) r['key'] as String: r['value'] as String,
      };
    } catch (e) {
      debugPrint('ChatDatabase.getAllMemory Error: $e');
      return {};
    }
  }
}
