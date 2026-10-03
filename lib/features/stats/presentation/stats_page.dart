import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/design/app_colors.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/core/widgets/stat_card.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'controllers/trend_providers.dart';

enum _Series { bp, pulse }

/// 趋势页。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int _days = 30;
  MeasureArm? _arm;
  _Series _series = _Series.bp;

  TrendQuery get _query => TrendQuery(days: _days, arm: _arm);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = ref.watch(trendDataProvider(_query));
    final stats = ref.watch(statsProvider(StatsRange(_days, '')));

    return Scaffold(
      appBar: AppBar(title: const Text('血压趋势')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // 筛选条
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...kStatsRanges.map((r) => ChoiceChip(
                      label: Text(r.label),
                      selected: _days == r.days,
                      onSelected: (_) => setState(() => _days = r.days),
                    )),
                const SizedBox(width: 4),
                FilterChip(
                  label: Text(_arm == null
                      ? '双臂'
                      : (_arm == MeasureArm.left ? '仅左臂' : '仅右臂')),
                  selected: _arm != null,
                  onSelected: (_) => setState(() {
                    _arm = _arm == null
                        ? MeasureArm.left
                        : (_arm == MeasureArm.left
                            ? MeasureArm.right
                            : null);
                  }),
                ),
              ],
            ),
          ),
          // 统计概览
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner('统计加载失败：$e'),
            data: (s) => _StatsCards(stats: s),
          ),
          // 图表
          trend.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner('趋势加载失败：$e'),
            data: (points) {
              if (points.isEmpty) {
                return const EmptyState(
                  icon: Icons.show_chart,
                  title: '该范围内暂无数据',
                  subtitle: '调整时间范围或先添加几条记录',
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SegmentedButton<_Series>(
                              segments: const [
                                ButtonSegment(
                                    value: _Series.bp, label: Text('血压')),
                                ButtonSegment(
                                    value: _Series.pulse, label: Text('脉搏')),
                              ],
                              selected: {_series},
                              onSelectionChanged: (s) =>
                                  setState(() => _series = s.first),
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 260,
                          child: _series == _Series.bp
                              ? _BpLineChart(points: points, days: _days)
                              : _PulseLineChart(points: points, days: _days),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // 图例说明
          if (_series == _Series.bp)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '水平虚线为家庭自测参考线（高压 135 / 低压 85，超过即为升高）。'
                '同日多次测量取平均值。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsCards extends StatelessWidget {
  const _StatsCards({required this.stats});

  final BpStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.count == 0) {
      return const SizedBox.shrink();
    }
    final sysColor = _statsColor(stats.avgSystolic, 135);
    final diaColor = _statsColor(stats.avgDiastolic, 85);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          StatCard(
            label: '平均高压',
            value: stats.avgSystolic.toStringAsFixed(0),
            color: sysColor,
            sub: '最高 ${stats.maxSystolic} · 最低 ${stats.minSystolic}',
          ),
          StatCard(
            label: '平均低压',
            value: stats.avgDiastolic.toStringAsFixed(0),
            color: diaColor,
            sub: '最高 ${stats.maxDiastolic} · 最低 ${stats.minDiastolic}',
          ),
          StatCard(
            label: '平均脉搏',
            value: stats.avgPulse?.toStringAsFixed(0) ?? '—',
            sub: (stats.maxPulse != null && stats.minPulse != null)
                ? '最高 ${stats.maxPulse} · 最低 ${stats.minPulse}'
                : null,
          ),
        ],
      ),
    );
  }

  Color _statsColor(double v, double threshold) {
    if (v >= 160) return BpCategoryStyle.colorOf(BpCategory.grade2);
    if (v >= threshold) return BpCategoryStyle.colorOf(BpCategory.grade1);
    if (v >= threshold - 10) {
      return BpCategoryStyle.colorOf(BpCategory.elevated);
    }
    return BpCategoryStyle.colorOf(BpCategory.normal);
  }
}

class _BpLineChart extends StatelessWidget {
  const _BpLineChart({required this.points, required this.days});

  final List<DayPoint> points;
  final int days;

  @override
  Widget build(BuildContext context) {
    final sysSpots =
        points.map((p) => FlSpot(xOf(p.date, days), p.avgSystolic)).toList();
    final diaSpots =
        points.map((p) => FlSpot(xOf(p.date, days), p.avgDiastolic)).toList();
    final allY =
        points.expand((p) => [p.avgSystolic, p.avgDiastolic]).toList();

    return LineChart(
      LineChartData(
        minX: ChartBase.minX(days),
        maxX: ChartBase.maxX(days),
        minY: ((allY.reduce(_min) - 15) / 10).floorToDouble() * 10,
        maxY: ((allY.reduce(_max) + 15) / 10).ceilToDouble() * 10,
        gridData: ChartBase.grid(),
        titlesData: ChartBase.titles(days),
        borderData: ChartBase.border(),
        lineTouchData: ChartBase.touch(),
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

class _PulseLineChart extends StatelessWidget {
  const _PulseLineChart({required this.points, required this.days});

  final List<DayPoint> points;
  final int days;

  @override
  Widget build(BuildContext context) {
    final spots = points
        .where((p) => p.avgPulse != null)
        .map((p) => FlSpot(xOf(p.date, days), p.avgPulse!))
        .toList();
    if (spots.isEmpty) {
      return const Center(
        child: Text('该范围内没有脉搏数据', style: TextStyle(color: Colors.grey)),
      );
    }
    final ys = spots.map((s) => s.y).toList();

    return LineChart(
      LineChartData(
        minX: ChartBase.minX(days),
        maxX: ChartBase.maxX(days),
        minY: ((ys.reduce(_min) - 10) / 10).floorToDouble() * 10,
        maxY: ((ys.reduce(_max) + 10) / 10).ceilToDouble() * 10,
        gridData: ChartBase.grid(),
        titlesData: ChartBase.titles(days),
        borderData: ChartBase.border(),
        lineTouchData: ChartBase.touch(),
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
