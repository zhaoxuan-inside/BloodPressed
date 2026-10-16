/// 每日测量蜡烛图：趋势页、全屏页与分享卡共用。
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:blood_pressed/core/design/app_colors.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/stats/domain/daily_candle.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

import '../controllers/trend_providers.dart';

class TrendCandleChart extends StatelessWidget {
  const TrendCandleChart({
    super.key,
    required this.points,
    required this.query,
    this.interactive = true,
  });
  final List<DayCandle> points;
  final TrendQuery query;
  final bool interactive;

  @override
  Widget build(BuildContext context) => _DailyCandleChart(
    points: points,
    query: query,
    pulse: false,
    interactive: interactive,
  );
}

class PulseCandleChart extends StatelessWidget {
  const PulseCandleChart({
    super.key,
    required this.points,
    required this.query,
    this.interactive = true,
  });
  final List<DayCandle> points;
  final TrendQuery query;
  final bool interactive;

  @override
  Widget build(BuildContext context) => _DailyCandleChart(
    points: points,
    query: query,
    pulse: true,
    interactive: interactive,
  );
}

typedef _ChartCandle = ({
  DayCandle day,
  MeasurementCandle reading,
  String label,
  Color color,
  double x,
});

class _DailyCandleChart extends StatelessWidget {
  const _DailyCandleChart({
    required this.points,
    required this.query,
    required this.pulse,
    required this.interactive,
  });

  final List<DayCandle> points;
  final TrendQuery query;
  final bool pulse;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candles = <_ChartCandle>[
      for (final day in points)
        if (pulse) ...[
          if (day.pulse case final MeasurementCandle reading)
            (
              day: day,
              reading: reading,
              label: l10n.seriesPulse,
              color: AppColors.chartPulse,
              x: xOf(day.date, query),
            ),
        ] else ...[
          (
            day: day,
            reading: day.systolic,
            label: l10n.sysLabel,
            color: AppColors.chartSystolic,
            x: xOf(day.date, query) - 0.19,
          ),
          (
            day: day,
            reading: day.diastolic,
            label: l10n.diaLabel,
            color: AppColors.chartDiastolic,
            x: xOf(day.date, query) + 0.19,
          ),
        ],
    ];
    if (candles.isEmpty) {
      return Center(
        child: Text(pulse ? l10n.pulseEmpty : l10n.statsEmptyTitle),
      );
    }
    final minimum = candles.map((c) => c.reading.minimum).reduce(math.min);
    final maximum = candles.map((c) => c.reading.maximum).reduce(math.max);
    final minY =
        ((math.min(minimum, pulse ? minimum : 85) - 10) / 10).floorToDouble() *
        10;
    final maxY =
        ((math.max(maximum, pulse ? maximum : 135) + 10) / 10).ceilToDouble() *
        10;

    String describe(_ChartCandle candle) {
      final r = candle.reading;
      final unit = pulse ? l10n.pulseUnit : 'mmHg';
      return '${Fmt.day(candle.day.date)} · ${candle.label}\n'
          '${l10n.candleFirst} ${Fmt.time(r.firstMeasuredAt)}: ${r.first} $unit\n'
          '${l10n.candleLast} ${Fmt.time(r.lastMeasuredAt)}: ${r.last} $unit\n'
          '${l10n.candleHigh}: ${r.maximum} $unit\n'
          '${l10n.candleLow}: ${r.minimum} $unit\n'
          '${l10n.countLabel}: ${r.count}';
    }

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 2,
          children: [
            for (final (label, color)
                in pulse
                    ? [(l10n.seriesPulse, AppColors.chartPulse)]
                    : [
                        (l10n.sysLabel, AppColors.chartSystolic),
                        (l10n.diaLabel, AppColors.chartDiastolic),
                      ])
              Text('● $label', style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bodyWidth =
                  ((constraints.maxWidth - 34) /
                          math.max(query.days, 1) *
                          (pulse ? 0.45 : 0.25))
                      .clamp(1.2, 16.0);
              return Semantics(
                label: candles.map(describe).join('\n'),
                child: CandlestickChart(
                  CandlestickChartData(
                    minX: -0.5,
                    maxX: math.max(query.days, 1) - 0.5,
                    minY: minY,
                    maxY: maxY,
                    candlestickSpots: [
                      for (final c in candles)
                        CandlestickSpot(
                          x: c.x,
                          open: c.reading.first.toDouble(),
                          close: c.reading.last.toDouble(),
                          high: c.reading.maximum.toDouble(),
                          low: c.reading.minimum.toDouble(),
                        ),
                    ],
                    candlestickPainter: DefaultCandlestickPainter(
                      candlestickStyleProvider: (spot, index) {
                        final color = candles[index].color;
                        return CandlestickStyle(
                          lineColor: color,
                          lineWidth: 1.2,
                          bodyStrokeColor: color,
                          bodyStrokeWidth: 1.2,
                          bodyFillColor: spot.close < spot.open
                              ? color
                              : Colors.transparent,
                          bodyWidth: bodyWidth,
                          bodyRadius: 0,
                        );
                      },
                    ),
                    gridData: ChartBase.grid(bloodPressure: !pulse),
                    titlesData: ChartBase.titles(query),
                    borderData: ChartBase.border(),
                    candlestickTouchData: CandlestickTouchData(
                      enabled: interactive,
                      touchSpotThreshold: 12,
                      touchTooltipData: CandlestickTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        maxContentWidth: 220,
                        getTooltipItems: (_, spot, index) =>
                            CandlestickTooltipItem(
                              describe(candles[index]),
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                      ),
                    ),
                  ),
                  duration: Duration.zero,
                  transformationConfig: FlTransformationConfig(
                    scaleAxis: interactive
                        ? FlScaleAxis.horizontal
                        : FlScaleAxis.none,
                    maxScale: 100,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n.candleHint}${interactive ? '\n${l10n.candleInteractionHint}' : ''}',
          style: TextStyle(
            fontSize: 10,
            height: 1.4,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
