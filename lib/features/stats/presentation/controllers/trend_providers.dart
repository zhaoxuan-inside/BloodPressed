import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart' show recordsRepositoryProvider;
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';

/// 趋势查询参数。
class TrendQuery {
  const TrendQuery({required this.days, this.arm});

  final int days;
  final MeasureArm? arm;

  @override
  bool operator ==(Object other) =>
      other is TrendQuery && other.days == days && other.arm == arm;

  @override
  int get hashCode => Object.hash(days, arm);
}

/// 图表数据（范围内记录，按天聚合）。
///
/// watch 记录列表状态：新增/编辑/删除后自动重算。
final trendDataProvider =
    FutureProvider.family<List<DayPoint>, TrendQuery>((ref, q) async {
  ref.watch(recordsControllerProvider);
  final repo = ref.watch(recordsRepositoryProvider);
  final to = DateTime.now();
  final from = to.subtract(Duration(days: q.days));
  final records = await repo.list(from: from, to: to, arm: q.arm);
  return DayPoint.aggregate(records, q.days);
});

/// 一天的聚合点。
class DayPoint {
  const DayPoint({
    required this.date,
    required this.avgSystolic,
    required this.avgDiastolic,
    this.avgPulse,
    this.count = 1,
  });

  final DateTime date;
  final double avgSystolic;
  final double avgDiastolic;
  final double? avgPulse;
  final int count;

  /// 按"天"聚合（同日多次取均值）。
  static List<DayPoint> aggregate(List<BpRecord> records, int days) {
    final byDay = <DateTime, List<BpRecord>>{};
    for (final r in records) {
      final key =
          DateTime(r.measuredAt.year, r.measuredAt.month, r.measuredAt.day);
      byDay.putIfAbsent(key, () => []).add(r);
    }
    final points = byDay.entries.map((e) {
      final list = e.value;
      double avg(int Function(BpRecord) pick) =>
          list.map(pick).reduce((a, b) => a + b) / list.length;
      final pulses =
          list.where((r) => r.pulse != null).map((r) => r.pulse!).toList();
      return DayPoint(
        date: e.key,
        avgSystolic: avg((r) => r.systolic),
        avgDiastolic: avg((r) => r.diastolic),
        avgPulse: pulses.isEmpty
            ? null
            : pulses.reduce((a, b) => a + b) / pulses.length,
        count: list.length,
      );
    }).toList();
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }
}

/// x 轴：0 = 最早一天，days-1 = 今天。
double xOf(DateTime date, int days) {
  final today = DateTime.now();
  final d0 = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d0).inDays;
  return (days - 1 - diff).toDouble().clamp(0.0, (days - 1).toDouble());
}

/// 图表基座配置（坐标轴/网格/参考线），页面内共享。
class ChartBase {
  static const sysColor = Color(0xFFE53935);
  static const diaColor = Color(0xFF1E88E5);
  static const pulseColor = Color(0xFF43A047);

  static double minX(int days) => 0;
  static double maxX(int days) => (days - 1).toDouble();

  static double labelInterval(int days) {
    if (days <= 7) return 1;
    if (days <= 30) return 5;
    if (days <= 90) return 15;
    if (days <= 180) return 30;
    if (days <= 366) return 60;
    return 365; // "全部"范围按年取刻度，配合渲染端过滤避免重叠
  }

  static FlTitlesData titles(int days) => FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            reservedSize: 34,
            getTitlesWidget: (v, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: labelInterval(days),
            reservedSize: 26,
            getTitlesWidget: (v, meta) {
              final date = DateTime.now()
                  .subtract(Duration(days: (days - 1 - v).round()));
              // "全部"等超长跨度只渲染首尾两个年月标签，避免重叠
              if (days > 366 && v > 0 && v < days - 1) {
                return const SizedBox.shrink();
              }
              final label = days <= 7
                  ? Fmt.friendlyDay(date)
                  : days > 366
                      ? '${date.year}/${date.month}'
                      : '${date.month}/${date.day}';
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  label,
                  style:
                      const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      );

  static FlGridData grid() => const FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
      );

  static ExtraLinesData referenceLines() => ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 135,
            color: sysColor.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: const TextStyle(fontSize: 10, color: sysColor),
              labelResolver: (_) => '高压135',
            ),
          ),
          HorizontalLine(
            y: 85,
            color: diaColor.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: const TextStyle(fontSize: 10, color: diaColor),
              labelResolver: (_) => '低压85',
            ),
          ),
        ],
      );

  static FlBorderData border() => FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          left: BorderSide(color: Colors.grey.shade300),
        ),
      );

  static LineTouchData touch() => LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '${s.x.toInt()}: ${s.y.toStringAsFixed(0)}',
                    const TextStyle(fontSize: 11, color: Colors.white),
                  ))
              .toList(),
        ),
      );
}
