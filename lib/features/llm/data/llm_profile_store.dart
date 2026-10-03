import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

/// LLM 配置档案存取（本地模型 / 远端 API 统一存放，config 字段为 JSON）。
class LlmProfileStore {
  LlmProfileStore(this._db);

  final AppDatabase _db;

  Future<List<LlmProfile>> list() async {
    final rows =
        await _db.db.query('llm_profiles', orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  Future<LlmProfile?> byId(String id) async {
    final rows = await _db.db
        .query('llm_profiles', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> upsert(LlmProfile profile) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert(
      'llm_profiles',
      {
        'id': profile.id,
        'kind': profile.kind.name,
        'name': profile.name,
        'config': jsonEncode(profile.config),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.db.delete('llm_profiles', where: 'id = ?', whereArgs: [id]);
  }

  LlmProfile _fromRow(Map<String, Object?> row) => LlmProfile(
        id: row['id'] as String,
        kind: row['kind'] == 'remote' ? LlmKind.remote : LlmKind.local,
        name: row['name'] as String,
        config: jsonDecode((row['config'] as String?) ?? '{}')
                as Map<String, Object?>,
      );
}
