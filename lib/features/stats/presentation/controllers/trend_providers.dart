import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart' show recordsRepositoryProvider;

import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/domain/daily_measurements.dart';

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

/// 图表数据（按日组织的范围内原始记录及摘要）。
///
/// watch 记录列表状态：新增/编辑/删除后自动重算。
final trendDataProvider =
    FutureProvider.family<List<DailyMeasurements>, TrendQuery>((ref, q) async {
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
      return DailyMeasurements.aggregate(records);
    });

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

/// 图表基座配置（坐标轴/网格），页面内共享。
class ChartBase {
  static double labelInterval(int days) {
    if (days <= 7) return 1;
    if (days <= 30) return 5;
    if (days <= 90) return 15;
    if (days <= 180) return 30;
    if (days <= 366) return 60;
    return (days - 1).toDouble(); // 超长区间只标首尾年月。
  }

  static FlTitlesData titles({double interval = 20}) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: interval,
          minIncluded: false,
          maxIncluded: false,
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
      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  static FlGridData grid() => FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: 20,
    getDrawingHorizontalLine: (_) =>
        FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
  );

  static FlBorderData border() => FlBorderData(
    show: true,
    border: Border(
      bottom: BorderSide(color: Colors.grey.shade300),
      left: BorderSide(color: Colors.grey.shade300),
    ),
  );
}
