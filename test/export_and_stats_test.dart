import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/export/data/csv_exporter.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';

void main() {
  group('CSV 导出', () {
    test('包含 BOM 与表头', () {
      const exporter = CsvExporter();
      final csv = exporter.buildCsv([]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('测量时间,高压(mmHg),低压(mmHg),脉搏(次/分),测量臂'));
    });

    test('记录行格式', () {
      const exporter = CsvExporter();
      final now = DateTime(2026, 10, 3, 8, 5);
      final csv = exporter.buildCsv([
        BpRecord(
          id: 'r1',
          systolic: 135,
          diastolic: 85,
          pulse: 72,
          measuredAt: now,
          arm: MeasureArm.right,
          posture: MeasurePosture.sitting,
          note: '晨起',
          source: RecordSource.ocr,
          deviceId: 'dev',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[1], contains('135,85,72'));
      expect(lines[1], contains('右臂'));
      expect(lines[1], contains('坐位'));
      expect(lines[1], contains('拍照识别'));
    });

    test('备注含逗号/引号正确转义', () {
      const exporter = CsvExporter();
      final now = DateTime(2026, 10, 3);
      final csv = exporter.buildCsv([
        BpRecord(
          id: 'r1',
          systolic: 120,
          diastolic: 80,
          measuredAt: now,
          arm: MeasureArm.left,
          note: '运动后, 很快"测量"',
          source: RecordSource.manual,
          deviceId: 'dev',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      expect(csv, contains('"运动后, 很快""测量""'));
    });
  });

  group('BpStats 统计', () {
    BpRecord rec(int sys, int dia, {int? pulse}) {
      final now = DateTime.now();
      return BpRecord(
        id: 'r-$sys-$dia-${pulse ?? 0}-${now.microsecondsSinceEpoch}',
        systolic: sys,
        diastolic: dia,
        pulse: pulse,
        measuredAt: now,
        arm: MeasureArm.left,
        source: RecordSource.manual,
        deviceId: 'dev',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('空列表', () {
      final s = BpStats.compute([]);
      expect(s.count, 0);
      expect(s.avgPulse, isNull);
      expect(s.maxPulse, isNull);
      expect(s.minPulse, isNull);
    });

    test('均值/最值/达标率', () {
      final s = BpStats.compute([
        rec(120, 80, pulse: 70),
        rec(140, 90, pulse: 80),
        rec(130, 85, pulse: 75),
      ]);
      expect(s.count, 3);
      expect(s.avgSystolic, closeTo(130, 0.01));
      expect(s.avgDiastolic, closeTo(85, 0.01));
      expect(s.avgPulse, closeTo(75, 0.01));
      expect(s.maxSystolic, 140);
      expect(s.minSystolic, 120);
      expect(s.maxPulse, 80);
      expect(s.minPulse, 70);
      // 达标（<135/85）：仅 120/80 一条
      expect(s.normalRate, closeTo(1 / 3, 0.01));
    });
  });

  group('血压校验', () {
    test('非法组合', () {
      expect(
        validateBpValues(systolic: null, diastolic: 80),
        isNotNull,
      );
      expect(
        validateBpValues(systolic: 80, diastolic: 120),
        isNotNull,
      ); // 高压须大于低压
      expect(
        validateBpValues(systolic: 350, diastolic: 80),
        isNotNull,
      );
      expect(
        validateBpValues(systolic: 120, diastolic: 80, pulse: 400),
        isNotNull,
      );
      expect(
        validateBpValues(systolic: 120, diastolic: 80, pulse: 72),
        isNull,
      );
    });
  });
}
