import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'benchmark_session.dart';

class BenchmarkSessionStore {
  static final BenchmarkSessionStore instance = BenchmarkSessionStore._internal();
  BenchmarkSessionStore._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'benchmark_sessions.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE sessions(id TEXT PRIMARY KEY, name TEXT, timestamp TEXT, mode TEXT, csvContent TEXT, requestCount INTEGER, totalJoules REAL)',
        );
      },
    );
  }

  Future<void> saveSession(BenchmarkSession session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BenchmarkSession>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sessions', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return BenchmarkSession.fromJson(maps[i]);
    });
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('sessions');
  }
}
