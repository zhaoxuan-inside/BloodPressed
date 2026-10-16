import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressed/features/export/presentation/share_card_widgets.dart';
import 'package:blood_pressed/features/stats/domain/daily_measurements.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/features/stats/presentation/widgets/trend_chart.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

import 'daily_measurements_test.dart' show reading;

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
          child: SizedBox(width: width, height: 380, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final query = TrendQuery.custom(
    DateTime(2026, 10, 15),
    DateTime(2026, 10, 17),
  );
  testWidgets('保留每次实际读数与真实时间，脉压差按同条记录计算', (tester) async {
    final days = DailyMeasurements.aggregate([
      reading(20, 125, 82),
      reading(12, 160, 95),
      reading(8, 130, 85),
      reading(16, 110, 70),
    ]);
    await showChart(tester, MeasurementTrendChart(points: days, query: query));
    final charts = tester
        .widgetList<LineChart>(find.byType(LineChart))
        .toList();
    expect(charts, hasLength(2));
    final bp = charts.first.data;
    final sys = bp.lineBarsData.first.spots;
    expect(sys.map((s) => s.y), [130, 160, 110, 125]);
    expect(sys.map((s) => s.x), [8 / 24, 12 / 24, 16 / 24, 20 / 24]);
    expect(charts.last.data.lineBarsData.single.spots.map((s) => s.y), [
      45,
      65,
      40,
      43,
    ]);
    expect(bp.extraLinesData.horizontalLines.map((l) => l.y), [135, 85]);
    expect(
      charts.first.transformationConfig.transformationController,
      same(charts.last.transformationConfig.transformationController),
    );
    expect(bp.lineBarsData.first.isCurved, isFalse);
    final text = bp.lineTouchData.touchTooltipData
        .getTooltipItems([LineBarSpot(bp.lineBarsData.first, 0, sys.first)])
        .single!
        .text;
    expect(text, contains('2026-10-15 08:00'));
    expect(text, contains('130/85'));
    expect(text, contains('脉压差: 45'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('整天缺测断线，缺失指标分别断线，单次点仍然保留', (tester) async {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, 80),
      reading(12, 130, 85).copyWith(diastolic: null),
      reading(20, 125, 82),
      reading(9, 140, 90, day: 17),
    ]);
    await showChart(tester, MeasurementTrendChart(points: days, query: query));
    final charts = tester
        .widgetList<LineChart>(find.byType(LineChart))
        .toList();
    final sys = charts.first.data.lineBarsData.first.spots;
    final dia = charts.first.data.lineBarsData.last.spots;
    final pp = charts.last.data.lineBarsData.single.spots;
    expect(sys, hasLength(5));
    expect(sys[3], FlSpot.nullSpot);
    expect(sys.last.x, 2 + 9 / 24);
    expect(sys.last.y, 140);
    expect(dia[1], FlSpot.nullSpot);
    expect(pp[1], FlSpot.nullSpot);
    expect(pp[3], FlSpot.nullSpot);
    expect(charts.first.data.lineBarsData.first.dotData.show, isTrue);
  });

  testWidgets('仅有单项血压也显示；无完整血压时显示压差空态', (tester) async {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, 80).copyWith(diastolic: null),
    ]);
    await showChart(tester, MeasurementTrendChart(points: days, query: query));
    expect(find.byType(LineChart), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.spots.single.y, 120);
    expect(chart.data.lineBarsData.last.spots.single, FlSpot.nullSpot);
    expect(find.text('没有同次完整有效的血压记录，无法计算脉压差'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('脉搏缺失不补零，单日轴标时间', (tester) async {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, 80),
      reading(12, 130, 85, pulse: 78),
      reading(20, 120, 80),
    ]);
    await showChart(
      tester,
      PulseTrendChart(
        points: days,
        query: TrendQuery.custom(
          DateTime(2026, 10, 15),
          DateTime(2026, 10, 15),
        ),
      ),
      locale: 'en',
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots, [
      FlSpot.nullSpot,
      const FlSpot(0.5, 78),
      FlSpot.nullSpot,
    ]);
    expect(find.text('12:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无脉搏或空范围显示空态', (tester) async {
    await showChart(
      tester,
      PulseTrendChart(
        points: DailyMeasurements.aggregate([reading(8, 120, 80)]),
        query: query,
      ),
    );
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('该范围内没有脉搏数据'), findsOneWidget);
    await showChart(
      tester,
      MeasurementTrendChart(points: const [], query: query),
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('英文窄屏长跨度保留峰值且不溢出', (tester) async {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, 80),
      reading(20, 180, 100),
    ]);
    await showChart(
      tester,
      MeasurementTrendChart(
        points: days,
        query: TrendQuery.custom(DateTime(2026, 8, 1), DateTime(2026, 10, 29)),
      ),
      locale: 'en',
      width: 280,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widgetList<LineChart>(find.byType(LineChart))
          .first
          .data
          .lineBarsData
          .first
          .spots
          .last
          .y,
      180,
    );
  });

  testWidgets('分享脉搏图使用有效范围与次数，静态卡禁用交互', (tester) async {
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
              points: DailyMeasurements.aggregate([
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
    expect(find.text('72–80'), findsOneWidget);
    expect(find.text('测量次数: 2'), findsOneWidget);
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineTouchData
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('同一时刻多条记录不覆盖，提示保留每条值', (tester) async {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, 80, id: 'a'),
      reading(8, 145, 95, id: 'b'),
    ]);
    await showChart(tester, MeasurementTrendChart(points: days, query: query));
    final data = tester
        .widgetList<LineChart>(find.byType(LineChart))
        .first
        .data;
    final bar = data.lineBarsData.first;
    expect(bar.spots, hasLength(2));
    expect(bar.spots.first.x, bar.spots.last.x);
    final text = data.lineTouchData.touchTooltipData
        .getTooltipItems([LineBarSpot(bar, 0, bar.spots.first)])
        .single!
        .text;
    expect(text, contains('120/80'));
    expect(text, contains('145/95'));
  });
}
