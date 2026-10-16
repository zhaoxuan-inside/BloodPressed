/// Raw measurement trends shared by the page, fullscreen and exported cards.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:blood_pressed/core/design/app_colors.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/stats/domain/daily_measurements.dart';
import 'package:blood_pressed/features/stats/domain/trend_timeline.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

import '../controllers/trend_providers.dart';

class MeasurementTrendChart extends StatelessWidget {
  const MeasurementTrendChart({
    super.key,
    required this.points,
    required this.query,
    this.interactive = true,
    this.measurementOrder = false,
  });
  final List<DailyMeasurements> points;
  final TrendQuery query;
  final bool interactive;
  final bool measurementOrder;
  @override
  Widget build(BuildContext context) => _MeasurementChart(
    points: points,
    query: query,
    interactive: interactive,
    measurementOrder: measurementOrder,
  );
}

class PulseTrendChart extends StatelessWidget {
  const PulseTrendChart({
    super.key,
    required this.points,
    required this.query,
    this.interactive = true,
    this.measurementOrder = false,
  });
  final List<DailyMeasurements> points;
  final TrendQuery query;
  final bool interactive;
  final bool measurementOrder;
  @override
  Widget build(BuildContext context) => _MeasurementChart(
    points: points,
    query: query,
    interactive: interactive,
    pulse: true,
    measurementOrder: measurementOrder,
  );
}

typedef _Metric = ({String label, Color color, int? Function(BpRecord) value});

class _MeasurementChart extends StatefulWidget {
  const _MeasurementChart({
    required this.points,
    required this.query,
    required this.interactive,
    this.pulse = false,
    this.measurementOrder = false,
  });
  final List<DailyMeasurements> points;
  final TrendQuery query;
  final bool interactive;
  final bool measurementOrder;
  final bool pulse;
  @override
  State<_MeasurementChart> createState() => _MeasurementChartState();
}

class _MeasurementChartState extends State<_MeasurementChart> {
  final _transform = TransformationController();
  final _scroll = ScrollController();
  String? _selectedId;

  @override
  void didUpdateWidget(covariant _MeasurementChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _transform.value = Matrix4.identity();
      _selectedId = null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeline = TrendTimeline(widget.points);
    final records = timeline.entries.whereType<BpRecord>().toList();
    if (records.isEmpty ||
        (widget.pulse && records.every((r) => r.pulse == null))) {
      return Center(
        child: Text(widget.pulse ? l10n.pulseEmpty : l10n.statsEmptyTitle),
      );
    }
    final metrics = <_Metric>[
      if (widget.pulse)
        (
          label: l10n.seriesPulse,
          color: AppColors.chartPulse,
          value: (r) => r.pulse,
        )
      else ...[
        (
          label: l10n.sysLabel,
          color: AppColors.chartSystolic,
          value: (r) => r.systolic,
        ),
        (
          label: l10n.diaLabel,
          color: AppColors.chartDiastolic,
          value: (r) => r.diastolic,
        ),
      ],
    ];
    final pp = (
      label: l10n.pulsePressure,
      color: const Color(0xFF8E5AB5),
      value: (BpRecord r) => r.pulsePressure,
    );
    final selected = records.where((r) => r.id == _selectedId).firstOrNull;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            for (final metric in metrics)
              Text(
                '● ${metric.label}',
                style: TextStyle(color: metric.color, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.trendCoverage(
            records.length,
            records.where((r) => r.hasValidPair).length,
            math.max(0, widget.query.days - widget.points.length),
          ),
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        if (widget.measurementOrder)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.measurementOrderHint,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final plots = Column(
                children: [
                  Expanded(
                    flex: widget.pulse ? 1 : 3,
                    child: _chart(
                      context,
                      timeline,
                      metrics,
                      bloodPressure: !widget.pulse,
                    ),
                  ),
                  if (!widget.pulse) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.pulsePressure} · mmHg',
                      style: TextStyle(fontSize: 11, color: pp.color),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      flex: 2,
                      child: records.every((r) => r.pulsePressure == null)
                          ? Center(
                              child: Text(
                                l10n.pulsePressureEmpty,
                                style: const TextStyle(fontSize: 11),
                              ),
                            )
                          : _chart(context, timeline, [pp]),
                    ),
                  ],
                ],
              );
              if (!widget.measurementOrder) return plots;
              return Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(
                        constraints.maxWidth,
                        records.length * 88.0 + 50,
                      ),
                      height: constraints.maxHeight - 18,
                      child: plots,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.interactive) ...[
          const SizedBox(height: 6),
          Text(
            selected == null
                ? widget.measurementOrder
                      ? l10n.dayInteractionHint
                      : l10n.measurementInteractionHint
                : _detail(selected, l10n),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  String _detail(BpRecord r, AppLocalizations l10n) {
    final day = widget.points.firstWhere(
      (d) => d.records.any((v) => v.id == r.id),
    );
    String summary(String label, MeasurementSummary? s) => s == null
        ? '$label —'
        : '$label ${l10n.candleFirst}${Fmt.time(s.firstMeasuredAt)} ${s.first} → ${l10n.candleLast}${Fmt.time(s.lastMeasuredAt)} ${s.last}\n${l10n.candleLow}${s.minimum} · ${l10n.candleHigh}${s.maximum} · ${l10n.countLabel}: ${s.count}';
    return '${Fmt.full(r.measuredAt)} · ${armLabel(l10n, r.arm)}\n${summary(l10n.sysLabel, day.systolic)}\n${summary(l10n.diaLabel, day.diastolic)}';
  }

  Widget _chart(
    BuildContext context,
    TrendTimeline timeline,
    List<_Metric> metrics, {
    bool bloodPressure = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final entries = timeline.entries;
    final end = widget.query.endDate;
    final start = DateTime(
      end.year,
      end.month,
      end.day - widget.query.days + 1,
    );
    final values = [
      for (final r in entries.whereType<BpRecord>())
        for (final m in metrics)
          if (m.value(r) case final int value) value,
    ];
    // A metric may be entirely absent while the other metric has readings.
    if (values.isEmpty) return Center(child: Text(l10n.statsEmptyTitle));
    final low = math.min(
      values.reduce(math.min),
      bloodPressure ? 85 : values.first,
    );
    final high = math.max(
      values.reduce(math.max),
      bloodPressure ? 135 : values.first,
    );
    final padding = math.max(8, (high - low) * 0.12).toDouble();
    final bars = [
      for (final (metricIndex, m) in metrics.indexed)
        LineChartBarData(
          spots: [
            for (final (index, r) in entries.indexed)
              r == null || m.value(r) == null
                  ? FlSpot.nullSpot
                  : FlSpot(
                      widget.measurementOrder
                          ? index.toDouble()
                          : TrendTimeline.xOf(r.measuredAt, start),
                      m.value(r)!.toDouble(),
                    ),
          ],
          color: m.color,
          isCurved: false,
          barWidth: 1.6,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              final r = entries[index]!;
              final invalid =
                  BpCategory.fromValues(r.systolic, r.diastolic) ==
                      BpCategory.incomplete &&
                  r.hasCompleteBp;
              if (widget.measurementOrder) {
                return _ReadingDotPainter(
                  label: spot.y.toStringAsFixed(0),
                  labelStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: m.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  below: bloodPressure && metricIndex == 1,
                  color: m.color,
                  strokeColor: invalid
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.surface,
                  invalid: invalid,
                );
              }
              return FlDotCirclePainter(
                radius: invalid ? 4 : 2.5,
                color: m.color,
                strokeWidth: invalid ? 2 : 0.8,
                strokeColor: invalid
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.surface,
              );
            },
          ),
        ),
    ];
    return Semantics(
      label: entries
          .whereType<BpRecord>()
          .map(
            (r) =>
                '${Fmt.full(r.measuredAt)} ${r.systolic ?? '—'}/${r.diastolic ?? '—'} ${l10n.pulsePressure} ${r.pulsePressure ?? '—'}',
          )
          .join('\n'),
      child: LineChart(
        LineChartData(
          minX: widget.measurementOrder ? -0.5 : 0,
          maxX: widget.measurementOrder
              ? math.max(entries.length - 0.5, 0.5)
              : widget.query.days.toDouble(),
          minY: low - padding,
          maxY: high + padding,
          lineBarsData: bars,
          clipData: const FlClipData.all(),
          gridData: ChartBase.grid(),
          titlesData: _titles(
            widget.query,
            start,
            high - low <= 50 ? 10 : 20,
            entries,
          ),
          borderData: ChartBase.border(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (bloodPressure) ...[
                HorizontalLine(
                  y: 135,
                  color: AppColors.chartSystolic.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                ),
                HorizontalLine(
                  y: 85,
                  color: AppColors.chartDiastolic.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                ),
              ],
            ],
          ),
          lineTouchData: LineTouchData(
            enabled: widget.interactive,
            touchSpotThreshold: 18,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent ||
                  response?.lineBarSpots?.isEmpty != false) {
                return;
              }
              final index = response!.lineBarSpots!.first.spotIndex;
              final r = entries[index];
              if (r != null) setState(() => _selectedId = r.id);
            },
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 230,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  () {
                    final r = entries[spot.spotIndex]!;
                    final sameTime = entries
                        .whereType<BpRecord>()
                        .where((v) => v.measuredAt == r.measuredAt)
                        .toList();
                    String reading(BpRecord v) =>
                        '${armLabel(l10n, v.arm)} ${v.systolic ?? '—'}/${v.diastolic ?? '—'} mmHg\n${l10n.pulsePressure}: ${v.pulsePressure ?? '—'} mmHg · ${l10n.seriesPulse}: ${v.pulse ?? '—'}';
                    final text =
                        '${Fmt.full(r.measuredAt)}\n${sameTime.map(reading).join('\n')}\n${categoryLabel(l10n, BpCategory.fromValues(r.systolic, r.diastolic))}';
                    // One tooltip for the selected measurement, avoiding duplicated BP text.
                    return spot == spots.first
                        ? LineTooltipItem(
                            text,
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.4,
                            ),
                          )
                        : null;
                  }(),
              ],
            ),
          ),
        ),
        duration: Duration.zero,
        transformationConfig: FlTransformationConfig(
          scaleAxis: widget.interactive && !widget.measurementOrder
              ? FlScaleAxis.horizontal
              : FlScaleAxis.none,
          maxScale: 100,
          transformationController: _transform,
        ),
      ),
    );
  }

  FlTitlesData _titles(
    TrendQuery query,
    DateTime start,
    double interval,
    List<BpRecord?> entries,
  ) {
    final base = ChartBase.titles(interval: interval);
    return base.copyWith(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: widget.measurementOrder
              ? 1
              : query.days == 1
              ? 0.25
              : ChartBase.labelInterval(query.days),
          minIncluded: !widget.measurementOrder,
          maxIncluded: false,
          getTitlesWidget: (value, meta) {
            if (widget.measurementOrder) {
              final index = value.round();
              if ((value - index).abs() > 0.001 ||
                  index < 0 ||
                  index >= entries.length ||
                  entries[index] == null) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  '${index + 1}. ${Fmt.time(entries[index]!.measuredAt)}',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            if (value < 0 || value >= query.days) {
              return const SizedBox.shrink();
            }
            if (query.days > 1 && (value - value.round()).abs() > 0.001) {
              return const SizedBox.shrink();
            }
            final day = DateTime(
              start.year,
              start.month,
              start.day + value.floor(),
            );
            final label = query.days == 1
                ? '${(value * 24).round().toString().padLeft(2, '0')}:00'
                : query.days > 366
                ? '${day.year}/${day.month}'
                : '${day.month}/${day.day}';
            return SideTitleWidget(
              meta: meta,
              child: Text(label, style: const TextStyle(fontSize: 9)),
            );
          },
        ),
      ),
    );
  }
}

/// Numeric labels remain legible because the day view reserves width per reading.
class _ReadingDotPainter extends FlDotCirclePainter {
  _ReadingDotPainter({
    required this.label,
    required this.below,
    required this.labelStyle,
    required super.color,
    required super.strokeColor,
    required bool invalid,
  }) : super(radius: invalid ? 4 : 3, strokeWidth: invalid ? 2 : 1);
  final String label;
  final bool below;
  final TextStyle labelStyle;
  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    super.draw(canvas, spot, offsetInCanvas);
    final text = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        offsetInCanvas.dx - text.width / 2,
        offsetInCanvas.dy + (below ? 6 : -19),
      ),
    );
  }
}
