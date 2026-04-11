import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bebeu_offline.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_data (
            id INTEGER PRIMARY KEY,
            date TEXT UNIQUE,
            total_intake INTEGER,
            daily_goal INTEGER,
            user_name TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  static Future<void> cacheDailyData({
    required int totalIntake,
    required int dailyGoal,
    required String userName,
  }) async {
    final db = await _database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await db.insert(
      'cached_data',
      {
        'date': today,
        'total_intake': totalIntake,
        'daily_goal': dailyGoal,
        'user_name': userName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getCachedData() async {
    final db = await _database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query(
      'cached_data',
      where: 'date = ?',
      whereArgs: [today],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> addPendingLog(int amount) async {
    final db = await _database;
    await db.insert('pending_logs', {
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingLogs() async {
    final db = await _database;
    return db.query(
      'pending_logs',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markLogSynced(int id) async {
    final db = await _database;
    await db.update(
      'pending_logs',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateCachedIntake(int newIntake) async {
    final db = await _database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await db.update(
      'cached_data',
      {
        'total_intake': newIntake,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'date = ?',
      whereArgs: [today],
    );
  }

  static Future<int> getPendingCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_logs WHERE synced = 0',
    );
    return result.first['count'] as int;
  }

  static Future<int> getPendingAmount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM pending_logs WHERE synced = 0',
    );
    final total = result.first['total'];
    return total == null ? 0 : total as int;
  }
}
