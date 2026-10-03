import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// 血压记录仓库：所有写操作都会同步写入 outbox（云同步保留能力）。
class RecordsRepository {
  RecordsRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxDao _outbox;

  static const String _entityType = 'bp_record';

  /// 查询记录（默认按测量时间倒序）。
  Future<List<BpRecord>> list({
    DateTime? from,
    DateTime? to,
    MeasureArm? arm,
    bool includeDeleted = false,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeDeleted) {
      where.add('deleted_at IS NULL');
    }
    if (from != null) {
      where.add('measured_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('measured_at <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (arm != null) {
      where.add('arm = ?');
      args.add(arm.name);
    }
    final rows = await _db.db.query(
      'bp_records',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'measured_at DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(BpRecord.fromMap).toList();
  }

  Future<BpRecord?> byId(String id) async {
    final rows = await _db.db
        .query('bp_records', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : BpRecord.fromMap(rows.first);
  }

  Future<BpRecord> latest() async {
    final rows = await _db.db.query(
      'bp_records',
      where: 'deleted_at IS NULL',
      orderBy: 'measured_at DESC, created_at DESC',
      limit: 1,
    );
    return BpRecord.fromMap(rows.first);
  }

  Future<bool> existsAny() async {
    final r = await _db.db.rawQuery(
      "SELECT COUNT(*) AS c FROM bp_records WHERE deleted_at IS NULL",
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  Future<BpRecord> create(BpRecord record) async {
    await _db.db.insert('bp_records', record.toMap());
    await _outbox.enqueue(
      entityType: _entityType,
      entityId: record.id,
      op: 'upsert',
      payload: record.toSyncPayload(),
    );
    return record;
  }

  Future<BpRecord> update(BpRecord record) async {
    await _db.db.update(
      'bp_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    await _outbox.enqueue(
      entityType: _entityType,
      entityId: record.id,
      op: 'upsert',
      payload: record.toSyncPayload(),
    );
    return record;
  }

  /// 软删除。
  Future<void> softDelete(String id, {required String deviceId}) async {
    final now = DateTime.now();
    await _db.db.update(
      'bp_records',
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'device_id': deviceId,
        'sync_state': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _outbox.enqueue(
      entityType: _entityType,
      entityId: id,
      op: 'delete',
      payload: {'id': id, 'deleted_at': now.toIso8601String()},
    );
  }

  /// 统计概览（指定时间范围内）。
  Future<BpStats> stats({DateTime? from, DateTime? to, MeasureArm? arm}) async {
    final records = await list(from: from, to: to, arm: arm);
    return BpStats.compute(records);
  }
}

/// 统计概览结果。
class BpStats {
  const BpStats({
    required this.count,
    required this.avgSystolic,
    required this.avgDiastolic,
    required this.avgPulse,
    required this.maxSystolic,
    required this.minSystolic,
    required this.maxDiastolic,
    required this.minDiastolic,
    this.maxPulse,
    this.minPulse,
    required this.normalRate,
  });

  final int count;
  final double avgSystolic;
  final double avgDiastolic;
  final double? avgPulse;
  final int maxSystolic;
  final int minSystolic;
  final int maxDiastolic;
  final int minDiastolic;

  /// 脉搏最值（无任何脉搏记录时为 null）。
  final int? maxPulse;
  final int? minPulse;

  /// 家庭自测达标（<135/85）占比。
  final double normalRate;

  factory BpStats.compute(List<BpRecord> records) {
    if (records.isEmpty) {
      return const BpStats(
        count: 0,
        avgSystolic: 0,
        avgDiastolic: 0,
        avgPulse: null,
        maxSystolic: 0,
        minSystolic: 0,
        maxDiastolic: 0,
        minDiastolic: 0,
        normalRate: 0,
      );
    }
    final sys = records.map((r) => r.systolic).toList();
    final dia = records.map((r) => r.diastolic).toList();
    final pulses = records.where((r) => r.pulse != null).map((r) => r.pulse!).toList();
    final normalCount =
        records.where((r) => r.systolic < 135 && r.diastolic < 85).length;
    return BpStats(
      count: records.length,
      avgSystolic: sys.reduce((a, b) => a + b) / sys.length,
      avgDiastolic: dia.reduce((a, b) => a + b) / dia.length,
      avgPulse: pulses.isEmpty
          ? null
          : pulses.reduce((a, b) => a + b) / records.length,
      maxSystolic: sys.reduce((a, b) => a > b ? a : b),
      minSystolic: sys.reduce((a, b) => a < b ? a : b),
      maxDiastolic: dia.reduce((a, b) => a > b ? a : b),
      minDiastolic: dia.reduce((a, b) => a < b ? a : b),
      maxPulse: pulses.isEmpty ? null : pulses.reduce((a, b) => a > b ? a : b),
      minPulse: pulses.isEmpty ? null : pulses.reduce((a, b) => a < b ? a : b),
      normalRate: normalCount / records.length,
    );
  }
}
