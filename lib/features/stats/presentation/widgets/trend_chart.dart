/// 趋势折线图公共组件：趋势页、全屏横屏页、分享卡共用。
///
/// 触摸提示显示日期（今天/昨天友好化，否则 M/d）与序列值——
/// 修复了旧实现提示 day-index 不可读的问题。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:blood_pressed/core/design/app_colors.dart';
import '../controllers/trend_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 血压双序列折线（高压红 / 低压蓝 + 135/85 参考线）。
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.points, required this.query});

  final List<DayPoint> points;
  final TrendQuery query;

  @override
  Widget build(BuildContext context) {
    final sysSpots =
        points.map((p) => FlSpot(xOf(p.date, query), p.avgSystolic)).toList();
    final diaSpots =
        points.map((p) => FlSpot(xOf(p.date, query), p.avgDiastolic)).toList();
    final allY =
        points.expand((p) => [p.avgSystolic, p.avgDiastolic]).toList();

    return LineChart(
      LineChartData(
        minX: ChartBase.minX(query.days),
        maxX: ChartBase.maxX(query.days),
        minY: ((allY.reduce(_min) - 15) / 10).floorToDouble() * 10,
        maxY: ((allY.reduce(_max) + 15) / 10).ceilToDouble() * 10,
        gridData: ChartBase.grid(),
        titlesData: ChartBase.titles(query),
        borderData: ChartBase.border(),
        lineTouchData: ChartBase.touch(query),
        extraLinesData: ChartBase.referenceLines(),
        lineBarsData: [
          LineChartBarData(
            spots: sysSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 2.4,
            color: AppColors.chartSystolic,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 2.6,
                color: barData.color ?? Colors.blue,
                strokeColor: Colors.white,
                strokeWidth: 1,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chartSystolic.withValues(alpha: 0.06),
            ),
          ),
          LineChartBarData(
            spots: diaSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 2.4,
            color: AppColors.chartDiastolic,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 2.6,
                color: barData.color ?? Colors.blue,
                strokeColor: Colors.white,
                strokeWidth: 1,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chartDiastolic.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}

/// 脉搏单序列折线。
class PulseLineChart extends StatelessWidget {
  const PulseLineChart({super.key, required this.points, required this.query});

  final List<DayPoint> points;
  final TrendQuery query;

  @override
  Widget build(BuildContext context) {
    final spots = points
        .where((p) => p.avgPulse != null)
        .map((p) => FlSpot(xOf(p.date, query), p.avgPulse!))
        .toList();
    if (spots.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).pulseEmpty,
            style: const TextStyle(color: Colors.grey)),
      );
    }
    final ys = spots.map((s) => s.y).toList();

    return LineChart(
      LineChartData(
        minX: ChartBase.minX(query.days),
        maxX: ChartBase.maxX(query.days),
        minY: ((ys.reduce(_min) - 10) / 10).floorToDouble() * 10,
        maxY: ((ys.reduce(_max) + 10) / 10).ceilToDouble() * 10,
        gridData: ChartBase.grid(),
        titlesData: ChartBase.titles(query),
        borderData: ChartBase.border(),
        lineTouchData: ChartBase.touch(query, pulse: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            barWidth: 2.4,
            color: AppColors.chartPulse,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 2.6,
                color: barData.color ?? Colors.blue,
                strokeColor: Colors.white,
                strokeWidth: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
