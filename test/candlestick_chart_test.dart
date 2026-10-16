import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressed/features/export/presentation/share_card_widgets.dart';
import 'package:blood_pressed/features/stats/domain/daily_candle.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/features/stats/presentation/widgets/trend_chart.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

import 'daily_candle_test.dart' show reading;

Future<void> showChart(
  WidgetTester tester,
  Widget child, {
  String locale = 'zh',
  double width = 360,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: 320, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final query = TrendQuery.custom(
    DateTime(2026, 10, 15),
    DateTime(2026, 10, 15),
  );

  testWidgets('高低压各自展示实际四值，提示包含日期和首末次时间', (tester) async {
    final days = DayCandle.aggregate([
      reading(20, 125, 82),
      reading(12, 160, 95),
      reading(8, 130, 85),
      reading(16, 110, 70),
    ]);
    await showChart(tester, TrendCandleChart(points: days, query: query));
    expect(find.byType(LineChart), findsNothing);
    final chart = tester.widget<CandlestickChart>(
      find.byType(CandlestickChart),
    );
    final spots = chart.data.candlestickSpots;
    expect(spots, hasLength(2));
    expect(
      (spots.first.open, spots.first.close, spots.first.high, spots.first.low),
      (130, 125, 160, 110),
    );
    expect(
      (spots.last.open, spots.last.close, spots.last.high, spots.last.low),
      (85, 82, 95, 70),
    );
    expect(spots.first.x, lessThan(spots.last.x));
    final tooltip = chart.data.candlestickTouchData.touchTooltipData
        .getTooltipItems(chart.data.candlestickPainter, spots.first, 0)!
        .text;
    for (final text in [
      '2026-10-15',
      '首次 08:00: 130',
      '末次 20:00: 125',
      '最高: 160',
      '最低: 110',
      '测量次数: 4',
    ]) {
      expect(tooltip, contains(text));
    }
    expect(chart.data.minY, lessThan(70));
    expect(chart.data.maxY, greaterThan(160));
    expect(chart.data.gridData.getDrawingHorizontalLine(135).dashArray, [6, 4]);
    expect(chart.data.gridData.getDrawingHorizontalLine(85).dashArray, [6, 4]);
    final rect = tester.getRect(find.byType(CandlestickChart));
    final tapX = rect.left + 34 + (rect.width - 34) * 0.31;
    final gesture = await tester.startGesture(Offset(tapX, rect.center.dy));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await gesture.up();
  });

  testWidgets('首末相同或单次也保留蜡烛，脉搏不补零', (tester) async {
    final days = DayCandle.aggregate([
      reading(8, 120, 80),
      reading(12, 130, 85, pulse: 78),
      reading(20, 120, 80),
    ]);
    await showChart(
      tester,
      PulseCandleChart(points: days, query: query),
      locale: 'en',
    );
    final chart = tester.widget<CandlestickChart>(
      find.byType(CandlestickChart),
    );
    final spot = chart.data.candlestickSpots.single;
    expect((spot.open, spot.close, spot.high, spot.low), (78, 78, 78, 78));
    final tooltip = chart.data.candlestickTouchData.touchTooltipData
        .getTooltipItems(chart.data.candlestickPainter, spot, 0)!
        .text;
    expect(tooltip, contains('First 12:00: 78 bpm'));
    expect(tooltip, contains('Measurements: 1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('无脉搏或空范围显示空态', (tester) async {
    await showChart(
      tester,
      PulseCandleChart(
        points: DayCandle.aggregate([reading(8, 120, 80)]),
        query: query,
      ),
    );
    expect(find.byType(CandlestickChart), findsNothing);
    expect(find.text('该范围内没有脉搏数据'), findsOneWidget);
    await showChart(tester, TrendCandleChart(points: const [], query: query));
    expect(find.byType(CandlestickChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('英文窄屏长跨度不溢出且保留每次极值', (tester) async {
    final days = DayCandle.aggregate([
      reading(8, 120, 80),
      reading(20, 180, 100),
    ]);
    await showChart(
      tester,
      TrendCandleChart(points: days, query: const TrendQuery(days: 90)),
      locale: 'en',
      width: 280,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<CandlestickChart>(find.byType(CandlestickChart))
          .data
          .candlestickSpots
          .first
          .high,
      180,
    );
  });

  testWidgets('分享脉搏图使用脉搏范围与有效测量次数', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrendShareCard(
              title: '10月15日',
              query: query,
              pulse: true,
              points: DayCandle.aggregate([
                reading(8, 120, 80),
                reading(12, 125, 82, pulse: 72),
                reading(20, 130, 85, pulse: 80),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PulseCandleChart), findsOneWidget);
    expect(find.byType(TrendCandleChart), findsNothing);
    expect(find.text('72–80'), findsOneWidget);
    expect(find.text('测量次数: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
