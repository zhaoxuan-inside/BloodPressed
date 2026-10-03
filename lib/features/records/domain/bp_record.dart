/// 血压记录实体与相关枚举。
library;

enum MeasureArm {
  left('左臂'),
  right('右臂');

  const MeasureArm(this.label);
  final String label;

  static MeasureArm fromName(String name) =>
      name == 'right' ? MeasureArm.right : MeasureArm.left;
  String get name => this == MeasureArm.right ? 'right' : 'left';
}

enum MeasurePosture {
  sitting('坐位'),
  lying('卧位'),
  standing('站位');

  const MeasurePosture(this.label);
  final String label;

  static MeasurePosture? tryFromName(String? name) {
    for (final p in MeasurePosture.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  String get name {
    switch (this) {
      case MeasurePosture.sitting:
        return 'sitting';
      case MeasurePosture.lying:
        return 'lying';
      case MeasurePosture.standing:
        return 'standing';
    }
  }
}

/// 记录来源：手动录入 / OCR 识别 / 大模型识别。
enum RecordSource {
  manual('手动'),
  ocr('拍照识别'),
  ai('AI识别');

  const RecordSource(this.label);
  final String label;

  static RecordSource fromName(String? name) {
    switch (name) {
      case 'ocr':
        return RecordSource.ocr;
      case 'ai':
        return RecordSource.ai;
      default:
        return RecordSource.manual;
    }
  }

  String get name {
    switch (this) {
      case RecordSource.manual:
        return 'manual';
      case RecordSource.ocr:
        return 'ocr';
      case RecordSource.ai:
        return 'ai';
    }
  }
}

/// 同步状态：云同步保留能力（outbox 模式），默认全部 pending。
enum SyncState { pending, synced }

class BpRecord {
  const BpRecord({
    required this.id,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.measuredAt,
    required this.arm,
    this.posture,
    this.note,
    this.photoPath,
    required this.source,
    required this.deviceId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncState = SyncState.pending,
  });

  final String id;
  final int systolic; // 高压（收缩压）
  final int diastolic; // 低压（舒张压）
  final int? pulse; // 脉搏
  final DateTime measuredAt; // 测量时间
  final MeasureArm arm; // 左/右臂
  final MeasurePosture? posture; // 体位（可选）
  final String? note; // 备注
  final String? photoPath; // OCR 时的原图（可选）
  final RecordSource source; // 录入来源
  final String deviceId; // 录入设备（多端同步预留）
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // 软删除
  final SyncState syncState;

  bool get isDeleted => deletedAt != null;

  BpRecord copyWith({
    int? systolic,
    int? diastolic,
    Object? pulse = _unset,
    DateTime? measuredAt,
    MeasureArm? arm,
    Object? posture = _unset,
    Object? note = _unset,
    Object? photoPath = _unset,
    RecordSource? source,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
    SyncState? syncState,
  }) {
    return BpRecord(
      id: id,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse == _unset ? this.pulse : pulse as int?,
      measuredAt: measuredAt ?? this.measuredAt,
      arm: arm ?? this.arm,
      posture: posture == _unset ? this.posture : posture as MeasurePosture?,
      note: note == _unset ? this.note : note as String?,
      photoPath:
          photoPath == _unset ? this.photoPath : photoPath as String?,
      source: source ?? this.source,
      deviceId: deviceId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
      syncState: syncState ?? this.syncState,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'measured_at': measuredAt.millisecondsSinceEpoch,
        'arm': arm.name,
        'posture': posture?.name,
        'note': note,
        'photo_path': photoPath,
        'source': source.name,
        'device_id': deviceId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'sync_state': syncState == SyncState.synced ? 'synced' : 'pending',
      };

  static BpRecord fromMap(Map<String, Object?> map) => BpRecord(
        id: map['id'] as String,
        systolic: map['systolic'] as int,
        diastolic: map['diastolic'] as int,
        pulse: map['pulse'] as int?,
        measuredAt:
            DateTime.fromMillisecondsSinceEpoch(map['measured_at'] as int),
        arm: MeasureArm.fromName(map['arm'] as String? ?? 'left'),
        posture: MeasurePosture.tryFromName(map['posture'] as String?),
        note: map['note'] as String?,
        photoPath: map['photo_path'] as String?,
        source: RecordSource.fromName(map['source'] as String?),
        deviceId: (map['device_id'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int),
        syncState: map['sync_state'] == 'synced'
            ? SyncState.synced
            : SyncState.pending,
      );

  /// 同步载荷（outbox / 未来云同步平台共用）。
  Map<String, Object?> toSyncPayload() => toMap();
}

/// 合法性校验：返回错误信息，null 表示合法。
String? validateBpValues({
  required int? systolic,
  required int? diastolic,
  int? pulse,
}) {
  if (systolic == null || diastolic == null) return '请填写高压与低压';
  if (systolic < 40 || systolic > 300) return '高压应在 40 ~ 300 之间';
  if (diastolic < 30 || diastolic > 200) return '低压应在 30 ~ 200 之间';
  if (systolic <= diastolic) return '高压应大于低压';
  if (pulse != null && (pulse < 20 || pulse > 300)) {
    return '脉搏应在 20 ~ 300 之间';
  }
  return null;
}

const Object _unset = Object();
