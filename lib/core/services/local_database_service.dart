import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??=
        await _initDB(); //inicializa o banco de dados se não estiver inicializado
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath(); //pega o caminho do banco de dados
    final path = join(
      dbPath,
      'bebeu_offline.db',
    ); //junta o caminho do banco de dados com o nome do banco de dados -> bebeu_offline.db

    return openDatabase(
      //abre o banco de dados
      path,
      version: 1, //so muda a versão do banco de dados se mudar o schema
      onCreate:
          (
            /*db -> banco de dados*/ db,
            /*version -> versão do banco de dados*/ version,
          ) async {
            //cria as tabelas do banco de dados
            await db.execute('''
          CREATE TABLE cached_data (
            id INTEGER PRIMARY KEY,
            date TEXT UNIQUE,
            total_intake INTEGER,
            daily_goal INTEGER,
            user_name TEXT,
            updated_at TEXT
          )
        '''); //cria a tabela cached_data
            await db.execute('''
          CREATE TABLE pending_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        '''); //cria a tabela pending_logs
          },
    );
  }

  static Future<void> cacheDailyData({
    required int totalIntake,
    required int dailyGoal,
    required String userName,
  }) async {
    final db = await _database; //pega o banco de dados
    final today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); //pega a data atual
    await db.insert(
      //insere os dados na tabela cached_data
      'cached_data',
      {
        'date': today,
        'total_intake': totalIntake, //total de ml ingeridos
        'daily_goal': dailyGoal, //meta de ml diária
        'user_name': userName, //nome do usuário
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, //substitui os dados se a data já existir
    );
  }

  static Future<Map<String, dynamic>?> getCachedData() async {
    //pega os dados da tabela cached_data
    final db = await _database; //pega o banco de dados
    final today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); //pega a data atual
    final rows = await db.query(
      //pega os dados da tabela cached_data
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
      where: 'synced = 0', //0 -> não sincronizado
      orderBy: 'created_at ASC',
    );
  }

  //marca o log como sincronizado
  static Future<void> markLogSynced(int id) async {
    final db = await _database;
    await db.update(
      'pending_logs',
      {'synced': 1}, //1 -> sincronizado
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
