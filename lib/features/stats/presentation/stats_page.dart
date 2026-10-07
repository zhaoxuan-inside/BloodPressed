import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/design/app_colors.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/core/widgets/stat_card.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'controllers/trend_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

enum _Series { bp, pulse }

/// 趋势页。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int? _days = 30;
  DateTimeRange? _custom;
  MeasureArm? _arm;
  _Series _series = _Series.bp;

  bool get _isCustom => _custom != null;

  TrendQuery get _query => _isCustom
      ? TrendQuery.custom(_custom!.start, _custom!.end, arm: _arm)
      : TrendQuery(days: _days!, arm: _arm);

  StatsRange get _statsRange => _isCustom
      ? StatsRange.custom(_custom!.start, _custom!.end)
      : StatsRange(_days!, '');

  String get _customLabel {
    final s = _custom!.start;
    final e = _custom!.end;
    String fmt(DateTime d) => AppLocaleService.isEn
        ? '${d.month}/${d.day}'
        : '${d.month}月${d.day}日';
    return '${fmt(s)}-${fmt(e)}';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _custom ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 29)),
            end: now,
          ),
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _days = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final query = _query;
    final trend = ref.watch(trendDataProvider(query));
    final stats = ref.watch(statsProvider(_statsRange));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
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
                      label: Text(statsRangeLabel(l10n, r.days)),
                      selected: !_isCustom && _days == r.days,
                      onSelected: (_) => setState(() {
                        _days = r.days;
                        _custom = null;
                      }),
                    )),
                ChoiceChip(
                  label: Text(_isCustom ? _customLabel : l10n.statsCustom),
                  selected: _isCustom,
                  onSelected: (_) => _pickCustomRange(),
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: Text(_arm == null
                      ? l10n.armBoth
                      : (_arm == MeasureArm.left
                          ? l10n.onlyLeftArm
                          : l10n.onlyRightArm)),
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
            error: (e, _) => ErrorBanner(l10n.statsLoadFailed(e.toString())),
            data: (s) => _StatsCards(stats: s),
          ),
          // 图表
          trend.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner(l10n.trendLoadFailed(e.toString())),
            data: (points) {
              if (points.isEmpty) {
                return EmptyState(
                  icon: Icons.show_chart,
                  title: l10n.statsEmptyTitle,
                  subtitle: l10n.statsEmptySubtitle,
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
                              segments: [
                                ButtonSegment(
                                    value: _Series.bp, label: Text(l10n.seriesBp)),
                                ButtonSegment(
                                    value: _Series.pulse, label: Text(l10n.seriesPulse)),
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
                              ? _BpLineChart(points: points, query: query)
                              : _PulseLineChart(points: points, query: query),
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
                l10n.chartReferenceHint,
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
    final l10n = AppLocalizations.of(context);
    final sysColor = _statsColor(stats.avgSystolic, 135);
    final diaColor = _statsColor(stats.avgDiastolic, 85);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          StatCard(
            label: l10n.avgSystolicCard,
            value: stats.avgSystolic.toStringAsFixed(0),
            color: sysColor,
            sub: l10n.minMaxHint('${stats.maxSystolic}', '${stats.minSystolic}'),
          ),
          StatCard(
            label: l10n.avgDiastolicCard,
            value: stats.avgDiastolic.toStringAsFixed(0),
            color: diaColor,
            sub: l10n.minMaxHint('${stats.maxDiastolic}', '${stats.minDiastolic}'),
          ),
          StatCard(
            label: l10n.avgPulseCard,
            value: stats.avgPulse?.toStringAsFixed(0) ?? '—',
            sub: (stats.maxPulse != null && stats.minPulse != null)
                ? l10n.minMaxHint('${stats.maxPulse}', '${stats.minPulse}')
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
  const _BpLineChart({required this.points, required this.query});

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
  const _PulseLineChart({required this.points, required this.query});

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
