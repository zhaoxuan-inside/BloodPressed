/// 本地分析器单测：时段分桶、星期周期、峰值、达标口径、空与单条边界。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';

BpRecord rec(
  int hour, {
  int sys = 120,
  int dia = 80,
  int? pulse,
  DateTime? day,
  int? weekdayOffset,
}) {
  // 2026-10-05 是周一
  final base = DateTime(2026, 10, 5).add(Duration(days: weekdayOffset ?? 0));
  return BpRecord(
    id: 'r-$hour-$sys-$dia-${base.millisecondsSinceEpoch}',
    systolic: sys,
    diastolic: dia,
    pulse: pulse,
    measuredAt: DateTime(base.year, base.month, base.day, hour, 30),
    arm: MeasureArm.left,
    source: RecordSource.manual,
    deviceId: 'test',
    createdAt: base,
    updatedAt: base,
  );
}

void main() {
  group('时段分桶', () {
    test('四时段按 measuredAt.hour 前闭后开划分', () {
      final a = BpAnalyzer.analyze([
        rec(2), // night
        rec(7), // morning
        rec(14), // afternoon
        rec(21), // evening
      ]);
      expect(a.buckets, hasLength(4));
      final names = a.buckets.map((b) => b.bucket).toSet();
      expect(
          names,
          containsAll(
              [TimeBucket.night, TimeBucket.morning, TimeBucket.afternoon, TimeBucket.evening]));
      expect(a.totalCount, 4);
    });

    test('边界小时：6 点归清晨、18 点归晚间', () {
      final a = BpAnalyzer.analyze([rec(6), rec(18)]);
      expect(a.buckets.map((b) => b.bucket).toSet(),
          {TimeBucket.morning, TimeBucket.evening});
    });

    test('按平均高压降序：偏高峰值时段排最前', () {
      final a = BpAnalyzer.analyze([
        rec(8, sys: 142, dia: 92), // morning 高
        rec(15, sys: 118, dia: 76), // afternoon 低
      ]);
      expect(a.buckets.first.bucket, TimeBucket.morning);
      expect(a.buckets.first.avgElevated, isTrue);
    });

    test('平均与达标计数：morning 两读数一达标', () {
      final a = BpAnalyzer.analyze([
        rec(8, sys: 140, dia: 90),
        rec(9, sys: 120, dia: 78, pulse: 70),
      ]);
      final morning =
          a.buckets.firstWhere((b) => b.bucket == TimeBucket.morning);
      expect(morning.count, 2);
      expect(morning.avgSystolic, 130);
      expect(morning.avgDiastolic, 84);
      expect(morning.onTargetCount, 1);
      expect(morning.avgPulse, 70);
    });
  });

  group('星期周期', () {
    test('按周一~周日排序，仅含有数据的星期', () {
      // 2026-10-05 周一；周三 = +2；周日 = +6
      final a = BpAnalyzer.analyze([
        rec(9, weekdayOffset: 0), // Mon
        rec(9, weekdayOffset: 2), // Wed
        rec(9, weekdayOffset: 6), // Sun
      ]);
      expect(a.weekdays.map((w) => w.weekday).toList(), [1, 3, 7]);
    });

    test('周末/工作日均值可对比', () {
      final a = BpAnalyzer.analyze([
        rec(9, sys: 150, dia: 95, weekdayOffset: 0), // Mon 高
        rec(9, sys: 118, dia: 76, weekdayOffset: 6), // Sun 低
      ]);
      expect(a.weekdays.first.avgSystolic, 150);
      expect(a.weekdays.last.avgSystolic, 118);
    });
  });

  group('峰值与异常计数', () {
    test('峰值取收缩压最高读数（并列取时间较后者）', () {
      final a = BpAnalyzer.analyze([
        rec(8, sys: 150, dia: 95),
        rec(15, sys: 155, dia: 98, weekdayOffset: 1),
        rec(20, sys: 155, dia: 90, weekdayOffset: 2),
      ]);
      expect(a.peakRecord!.systolic, 155);
      expect(a.peakRecord!.measuredAt.hour, 20);
      expect(a.abnormalCount, 3); // 150/95、155/98、155/90 均异常
    });

    test('全部达标时 abnormalCount 为 0', () {
      final a = BpAnalyzer.analyze([rec(9, sys: 120, dia: 80)]);
      expect(a.abnormalCount, 0);
    });
  });

  group('边界', () {
    test('空输入：isEmpty 且无峰值', () {
      final a = BpAnalyzer.analyze(const []);
      expect(a.isEmpty, isTrue);
      expect(a.peakRecord, isNull);
      expect(a.buckets, isEmpty);
    });

    test('单条记录：单桶单星期', () {
      final a = BpAnalyzer.analyze([rec(7, sys: 126, dia: 82)]);
      expect(a.buckets, hasLength(1));
      expect(a.weekdays, hasLength(1));
      expect(a.peakRecord!.systolic, 126);
    });
  });
}
