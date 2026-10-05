import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// 记录列表状态。
class RecordsController extends StateNotifier<AsyncValue<List<BpRecord>>> {
  RecordsController(this._repo, this._deviceId) : super(const AsyncLoading()) {
    refresh();
  }

  final RecordsRepository _repo;
  final Future<String> _deviceId;

  static const int _displayLimit = 500;

  Future<void> refresh() async {
    try {
      final records = await _repo.list(limit: _displayLimit);
      state = AsyncData(records);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> save({
    required int systolic,
    required int diastolic,
    int? pulse,
    required DateTime measuredAt,
    required MeasureArm arm,
    MeasurePosture? posture,
    String? note,
    RecordSource source = RecordSource.manual,
    String? photoPath,
    String? editId,
  }) async {
    final deviceId = await _deviceId;
    if (editId != null) {
      final existing = await _repo.byId(editId);
      if (existing != null) {
        await _repo.update(existing.copyWith(
          systolic: systolic,
          diastolic: diastolic,
          pulse: pulse,
          measuredAt: measuredAt,
          arm: arm,
          posture: posture,
          note: note,
          updatedAt: DateTime.now(),
        ));
      }
    } else {
      final now = DateTime.now();
      await _repo.create(BpRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString() +
            deviceId.substring(0, 8),
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
        measuredAt: measuredAt,
        arm: arm,
        posture: posture,
        note: note,
        photoPath: photoPath,
        source: source,
        deviceId: deviceId,
        createdAt: now,
        updatedAt: now,
      ));
    }
    await refresh();
  }

  Future<void> delete(String id) async {
    final deviceId = await _deviceId;
    await _repo.softDelete(id, deviceId: deviceId);
    await refresh();
  }
}

final recordsControllerProvider =
    StateNotifierProvider<RecordsController, AsyncValue<List<BpRecord>>>(
        (ref) {
  final repo = ref.watch(recordsRepositoryProvider);
  return RecordsController(repo, ref.watch(deviceIdProvider.future));
});

/// 最近一次记录。
final latestRecordProvider = Provider<BpRecord?>((ref) {
  final list = ref.watch(recordsControllerProvider).valueOrNull;
  return (list == null || list.isEmpty) ? null : list.first;
});

/// 今日记录。
final todayRecordsProvider = Provider<List<BpRecord>>((ref) {
  final list = ref.watch(recordsControllerProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return list.where((r) {
    return !r.measuredAt.isBefore(start);
  }).toList();
});

/// 统计（近 N 天或自定义区间）。watch 记录列表状态：数据变化后自动重算。
final statsProvider = FutureProvider.family<BpStats, StatsRange>(
    (ref, range) async {
  ref.watch(recordsControllerProvider);
  final repo = ref.watch(recordsRepositoryProvider);
  if (range.isCustom) {
    return repo.stats(from: range.from!, to: range.to!);
  }
  final to = DateTime.now();
  final from = to.subtract(Duration(days: range.days));
  return repo.stats(from: from, to: to);
});

class StatsRange {
  const StatsRange(this.days, this.label, {this.from, this.to});

  /// 自定义区间工厂：from/to 含首尾整天。
  StatsRange.custom(DateTime from, DateTime to, {String label = ''})
      : this(
          to.difference(DateTime(from.year, from.month, from.day)).inDays + 1,
          label,
          from: DateTime(from.year, from.month, from.day),
          to: DateTime(to.year, to.month, to.day, 23, 59, 59),
        );

  final int days; // 7 / 30 / 90 / 3650(全部)；自定义=跨度天数
  final String label;

  /// 自定义区间起点（当天 00:00）；预设模式为 null。
  final DateTime? from;

  /// 自定义区间终点（当天 23:59:59）；预设模式为 null。
  final DateTime? to;

  bool get isCustom => from != null && to != null;

  @override
  bool operator ==(Object other) =>
      other is StatsRange &&
      other.days == days &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(days, from, to);
}

const kStatsRanges = [
  StatsRange(7, '近7天'),
  StatsRange(30, '近30天'),
  StatsRange(90, '近90天'),
  StatsRange(3650, '全部'),
];
