import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart' show recordsRepositoryProvider;

import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/domain/daily_candle.dart';

/// 趋势查询参数。
///
/// 预设模式（近 N 天，锚定今天）或自定义模式（显式起止日期，可完全在过去）。
class TrendQuery {
  const TrendQuery({required this.days, this.arm, this.from, this.to});

  /// 自定义时间段工厂：days 自动取首尾闭区间跨度。
  factory TrendQuery.custom(DateTime from, DateTime to, {MeasureArm? arm}) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return TrendQuery(
      days:
          DateTime.utc(end.year, end.month, end.day)
              .difference(DateTime.utc(start.year, start.month, start.day))
              .inDays +
          1,
      arm: arm,
      from: start,
      to: DateTime(
        end.year,
        end.month,
        end.day + 1,
      ).subtract(const Duration(microseconds: 1)),
    );
  }

  /// 预设模式：窗口天数（近 N 天）；自定义模式：图表跨度（天）。
  final int days;
  final MeasureArm? arm;

  /// 自定义起点（当天 00:00）；预设模式为 null。
  final DateTime? from;

  /// 自定义终点（当天 23:59:59，含整日）；预设模式为 null。
  final DateTime? to;

  bool get isCustom => from != null && to != null;

  /// 图表 x 轴锚定的末日：自定义取区间末日，预设取当前时刻。
  DateTime get endDate =>
      isCustom ? DateTime(to!.year, to!.month, to!.day) : DateTime.now();

  @override
  bool operator ==(Object other) =>
      other is TrendQuery &&
      other.days == days &&
      other.arm == arm &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(days, arm, from, to);
}

/// 图表数据（范围内记录，按天聚合）。
///
/// watch 记录列表状态：新增/编辑/删除后自动重算。
final trendDataProvider = FutureProvider.family<List<DayCandle>, TrendQuery>((
  ref,
  q,
) async {
  ref.watch(recordsControllerProvider);
  final repo = ref.watch(recordsRepositoryProvider);
  final now = DateTime.now();
  final records = await repo.list(
    from: q.isCustom
        ? q.from
        : DateTime(now.year, now.month, now.day - q.days + 1),
    to: q.isCustom ? q.to : now,
    arm: q.arm,
  );
  return DayCandle.aggregate(records);
});

/// x 轴：0 = 区间首日，days-1 = 区间末日（预设模式末日=今天；自定义=区间末）。
double xOf(DateTime date, TrendQuery q) {
  final endDate = q.endDate;
  final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
  final d0 = DateTime.utc(date.year, date.month, date.day);
  final diff = end.difference(d0).inDays;
  return (q.days - 1 - diff).toDouble().clamp(0.0, (q.days - 1).toDouble());
}

/// 规律分析：与趋势图同查询（范围 + 臂过滤），对原始记录做
/// 时段/星期/峰值分析。跟随 recordsControllerProvider 变化自动重算。
final analysisDataProvider = FutureProvider.family<BpAnalysis, TrendQuery>((
  ref,
  q,
) async {
  ref.watch(recordsControllerProvider);
  final repo = ref.watch(recordsRepositoryProvider);
  final now = DateTime.now();
  final from = q.isCustom
      ? q.from!
      : DateTime(now.year, now.month, now.day - q.days + 1);
  final to = q.isCustom ? q.to! : now;
  final records = await repo.list(from: from, to: to, arm: q.arm);
  return BpAnalyzer.analyze(records);
});

/// 图表基座配置（坐标轴/网格/参考线），页面内共享。
class ChartBase {
  static const sysColor = Color(0xFFE53935);
  static const diaColor = Color(0xFF1E88E5);

  static double labelInterval(int days) {
    if (days <= 7) return 1;
    if (days <= 30) return 5;
    if (days <= 90) return 15;
    if (days <= 180) return 30;
    if (days <= 366) return 60;
    return (days - 1).toDouble(); // 超长区间只标首尾年月。
  }

  static FlTitlesData titles(TrendQuery q) {
    final days = q.days;
    final end = q.endDate;
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          minIncluded: false,
          maxIncluded: false,
          getTitlesWidget: (v, meta) {
            if ((v - v.round()).abs() > 0.001 || v < 0 || v >= days) {
              return const SizedBox.shrink();
            }
            final date = DateTime(
              end.year,
              end.month,
              end.day - (days - 1 - v).round(),
            );
            // "全部"等超长跨度只渲染首尾两个年月标签，避免重叠
            if (days > 366 && v > 0 && v < days - 1) {
              return const SizedBox.shrink();
            }
            final label = days > 366
                ? '${date.year}/${date.month}'
                : '${date.month}/${date.day}';
            return SideTitleWidget(
              meta: meta,
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  static FlGridData grid({bool bloodPressure = false}) => FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: bloodPressure ? 5 : 20,
    checkToShowHorizontalLine: (value) =>
        value % 20 == 0 || (bloodPressure && (value == 135 || value == 85)),
    getDrawingHorizontalLine: (value) {
      final reference = bloodPressure && (value == 135 || value == 85);
      return FlLine(
        color: reference
            ? (value == 135 ? sysColor : diaColor).withValues(alpha: 0.65)
            : Colors.grey.withValues(alpha: 0.2),
        strokeWidth: 1,
        dashArray: reference ? [6, 4] : null,
      );
    },
  );

  static FlBorderData border() => FlBorderData(
    show: true,
    border: Border(
      bottom: BorderSide(color: Colors.grey.shade300),
      left: BorderSide(color: Colors.grey.shade300),
    ),
  );
}
