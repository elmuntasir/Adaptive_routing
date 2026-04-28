import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite-backed cache for Gemini routing policy (conscious routing).
/// Key = SHA-256 of payload_type|mode|device_tier|network_type (battery excluded).
class AiPolicyStore {
  static final AiPolicyStore instance = AiPolicyStore._internal();
  AiPolicyStore._internal();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'ai_routing_policy.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE policy (
  cache_key TEXT PRIMARY KEY,
  route TEXT NOT NULL,
  reasoning TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
      },
    );
  }

  static String computeKey({
    required String payloadType,
    required String mode,
    required String deviceTier,
    required String networkType,
  }) {
    final raw = '$payloadType|$mode|$deviceTier|$networkType';
    final digest = sha256.convert(utf8.encode(raw));
    return digest.toString();
  }

  Future<PolicyEntry?> get(String cacheKey) async {
    await init();
    final rows = await _db!.query(
      'policy',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PolicyEntry(
      route: rows.first['route'] as String,
      reasoning: rows.first['reasoning'] as String,
      createdAt: DateTime.parse(rows.first['created_at'] as String),
    );
  }

  Future<void> put({
    required String cacheKey,
    required String route,
    required String reasoning,
  }) async {
    await init();
    await _db!.insert('policy', {
      'cache_key': cacheKey,
      'route': route,
      'reasoning': reasoning,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    await init();
    await _db!.delete('policy');
  }
}

class PolicyEntry {
  final String route;
  final String reasoning;
  final DateTime createdAt;

  PolicyEntry({
    required this.route,
    required this.reasoning,
    required this.createdAt,
  });
}
