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
    final rows = await _db.db.query(
      'bp_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
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

  Future<BpRecord> create(BpRecord record) async {
    _validate(record);
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
    _validate(record);
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

  static void _validate(BpRecord record) {
    final error = validateBpValues(
      systolic: record.systolic,
      diastolic: record.diastolic,
      pulse: record.pulse,
    );
    if (error != null) throw ArgumentError(error.name);
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
    this.completeCount = 0,
    this.systolicCount = 0,
    this.diastolicCount = 0,
  });

  final int count;
  final int completeCount;
  final int systolicCount;
  final int diastolicCount;
  final double? avgSystolic;
  final double? avgDiastolic;
  final double? avgPulse;
  final int? maxSystolic;
  final int? minSystolic;
  final int? maxDiastolic;
  final int? minDiastolic;

  /// 脉搏最值（无任何脉搏记录时为 null）。
  final int? maxPulse;
  final int? minPulse;

  /// 家庭自测达标（<135/85）占比。
  final double? normalRate;

  factory BpStats.compute(List<BpRecord> records) {
    final live = records.where((r) => !r.isDeleted).toList();
    final sys = live
        .map((r) => r.systolic)
        .whereType<int>()
        .where((v) => v >= 40 && v <= 300)
        .toList();
    final dia = live
        .map((r) => r.diastolic)
        .whereType<int>()
        .where((v) => v >= 30 && v <= 200)
        .toList();
    final pulses = live
        .map((r) => r.pulse)
        .whereType<int>()
        .where((v) => v >= 20 && v <= 300)
        .toList();
    final pairs = live.where((r) => r.hasValidPair).toList();
    final normalCount = pairs
        .where((r) => r.systolic! < 135 && r.diastolic! < 85)
        .length;
    double? average(List<int> values) =>
        values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    int? minimum(List<int> values) =>
        values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    int? maximum(List<int> values) =>
        values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    return BpStats(
      count: live.length,
      completeCount: pairs.length,
      systolicCount: sys.length,
      diastolicCount: dia.length,
      avgSystolic: average(sys),
      avgDiastolic: average(dia),
      avgPulse: average(pulses),
      maxSystolic: maximum(sys),
      minSystolic: minimum(sys),
      maxDiastolic: maximum(dia),
      minDiastolic: minimum(dia),
      maxPulse: maximum(pulses),
      minPulse: minimum(pulses),
      normalRate: pairs.isEmpty ? null : normalCount / pairs.length,
    );
  }
}
