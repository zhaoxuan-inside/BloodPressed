/// 血压记录本地分析器（纯函数，零 Flutter / 网络依赖）。
///
/// 回答「什么时间的血压高、周期怎么样」：按测量时刻分时段（夜间/清晨/
/// 下午/晚间）、按星期分桶，并找出峰值读数。输出结构化数据，**不产生
/// 文案**——结论句由 UI 层按阈值规则经 l10n 渲染（分级标准与
/// BpCategory 一致：<135/85 达标）。
library;

import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// 时段桶（按 measuredAt.hour 划分，前闭后开）。
enum TimeBucket {
  /// 夜间 0:00–6:00
  night,

  /// 清晨 6:00–12:00（清晨高血压敏感窗口）
  morning,

  /// 下午 12:00–18:00
  afternoon,

  /// 晚间 18:00–24:00
  evening,
}

/// 单时段统计。
class BucketStats {
  const BucketStats({
    required this.bucket,
    required this.count,
    required this.avgSystolic,
    required this.avgDiastolic,
    required this.avgPulse,
    required this.onTargetCount,
  });

  final TimeBucket bucket;
  final int count;
  final double avgSystolic;
  final double avgDiastolic;
  final double? avgPulse;

  /// sys<135 且 dia<85 的读数条数（家庭自测达标口径）。
  final int onTargetCount;

  bool get onTargetAll => onTargetCount == count;

  /// 平均高压是否达到偏高口径（≥135 或平均低压 ≥85）。
  bool get avgElevated => avgSystolic >= 135 || avgDiastolic >= 85;
}

/// 单星期统计（1=周一 … 7=周日）。
class WeekdayStats {
  const WeekdayStats({
    required this.weekday,
    required this.count,
    required this.avgSystolic,
    required this.avgDiastolic,
  });

  final int weekday;
  final int count;
  final double avgSystolic;
  final double avgDiastolic;
}

/// 一次完整分析的结构化结果。
class BpAnalysis {
  const BpAnalysis({
    required this.buckets,
    required this.weekdays,
    required this.peakRecord,
    required this.abnormalCount,
    required this.totalCount,
  });

  /// 有数据的时段，按平均高压降序（最需要关注的排最前）。
  final List<BucketStats> buckets;

  /// 有数据的星期，按周一~周日排序。
  final List<WeekdayStats> weekdays;

  /// 范围内收缩压最高的单次读数（空输入为 null）。
  final BpRecord? peakRecord;

  /// sys≥135 或 dia≥85 的读数条数。
  final int abnormalCount;
  final int totalCount;

  bool get isEmpty => totalCount == 0;
}

class BpAnalyzer {
  BpAnalyzer._();

  /// 家庭自测达标口径（与 records_repository.stats 的 normalRate 一致）。
  static const int sysTarget = 135;
  static const int diaTarget = 85;

  static TimeBucket bucketOf(DateTime t) {
    final h = t.hour;
    if (h < 6) return TimeBucket.night;
    if (h < 12) return TimeBucket.morning;
    if (h < 18) return TimeBucket.afternoon;
    return TimeBucket.evening;
  }

  /// 分析一批记录（已按范围/臂过滤的输入由调用方保证）。
  static BpAnalysis analyze(List<BpRecord> records) {
    final live = records;
    if (live.isEmpty) {
      return const BpAnalysis(
        buckets: [],
        weekdays: [],
        peakRecord: null,
        abnormalCount: 0,
        totalCount: 0,
      );
    }

    // 时段分桶
    final byBucket = <TimeBucket, List<BpRecord>>{};
    for (final r in live) {
      byBucket.putIfAbsent(bucketOf(r.measuredAt), () => []).add(r);
    }
    final buckets = byBucket.entries.map((e) {
      final sys = e.value.map((r) => r.systolic).toList();
      final dia = e.value.map((r) => r.diastolic).toList();
      final pulses =
          e.value.map((r) => r.pulse).whereType<int>().toList();
      return BucketStats(
        bucket: e.key,
        count: e.value.length,
        avgSystolic: sys.reduce((a, b) => a + b) / sys.length,
        avgDiastolic: dia.reduce((a, b) => a + b) / dia.length,
        avgPulse: pulses.isEmpty
            ? null
            : pulses.reduce((a, b) => a + b) / pulses.length,
        onTargetCount: e.value
            .where((r) => r.systolic < sysTarget && r.diastolic < diaTarget)
            .length,
      );
    }).toList()
      ..sort((a, b) => b.avgSystolic.compareTo(a.avgSystolic));

    // 星期分桶
    final byWeekday = <int, List<BpRecord>>{};
    for (final r in live) {
      byWeekday.putIfAbsent(r.measuredAt.weekday, () => []).add(r);
    }
    final weekdays = [
      for (var wd = 1; wd <= 7; wd++)
        if (byWeekday.containsKey(wd))
          () {
            final list = byWeekday[wd]!;
            final sys = list.map((r) => r.systolic).toList();
            final dia = list.map((r) => r.diastolic).toList();
            return WeekdayStats(
              weekday: wd,
              count: list.length,
              avgSystolic: sys.reduce((a, b) => a + b) / sys.length,
              avgDiastolic: dia.reduce((a, b) => a + b) / dia.length,
            );
          }(),
    ];

    // 峰值（收缩压最高；并列取时间较后者）
    BpRecord? peak;
    for (final r in live) {
      if (peak == null || r.systolic >= peak.systolic) peak = r;
    }
    final abnormal = live
        .where((r) => r.systolic >= sysTarget || r.diastolic >= diaTarget)
        .length;

    return BpAnalysis(
      buckets: buckets,
      weekdays: weekdays,
      peakRecord: peak,
      abnormalCount: abnormal,
      totalCount: live.length,
    );
  }
}
