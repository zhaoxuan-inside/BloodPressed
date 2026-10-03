import 'dart:convert';

import 'app_database.dart';

/// 云同步变更日志条目。
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.createdAt,
  });

  final int id;
  final String entityType; // 目前仅 'bp_record'
  final String entityId;
  final String op; // 'upsert' | 'delete'
  final String payload; // JSON
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'op': op,
        'payload': payload,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static OutboxEntry fromMap(Map<String, Object?> map) => OutboxEntry(
        id: map['id'] as int,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String,
        op: map['op'] as String,
        payload: (map['payload'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Map<String, Object?> payloadJson() =>
      payload.isEmpty ? {} : jsonDecode(payload) as Map<String, Object?>;
}

/// 变更日志 DAO。云同步开启前仅累积日志；开启后由 SyncService 消费。
class OutboxDao {
  OutboxDao(this._db);

  final AppDatabase _db;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String op,
    Map<String, Object?>? payload,
  }) async {
    await _db.db.insert('sync_outbox', {
      'entity_type': entityType,
      'entity_id': entityId,
      'op': op,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<OutboxEntry>> take(int limit) async {
    final rows = await _db.db.query(
      'sync_outbox',
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(OutboxEntry.fromMap).toList();
  }

  Future<int> count() async {
    final r = await _db.db.rawQuery('SELECT COUNT(*) AS c FROM sync_outbox');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final ph = List.filled(ids.length, '?').join(',');
    await _db.db
        .delete('sync_outbox', where: 'id IN ($ph)', whereArgs: ids);
  }

  Future<void> clear() async {
    await _db.db.delete('sync_outbox');
  }
}
