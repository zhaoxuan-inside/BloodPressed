import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/stats/domain/daily_measurements.dart';

BpRecord reading(
  int hour,
  int? sys,
  int? dia, {
  int? pulse,
  int day = 15,
  String? id,
  DateTime? createdAt,
  DateTime? deletedAt,
}) => BpRecord(
  id: id ?? '$day-$hour-$sys',
  systolic: sys,
  diastolic: dia,
  pulse: pulse,
  measuredAt: DateTime(2026, 10, day, hour),
  arm: MeasureArm.left,
  source: RecordSource.manual,
  deviceId: 'test-device',
  createdAt: createdAt ?? DateTime(2026, 10, day, hour),
  updatedAt: DateTime(2026, 10, day, hour),
  deletedAt: deletedAt,
);

void main() {
  test('每天使用测量时间的首次/末次和实际极值，不计算平均值', () {
    final records = [
      reading(20, 125, 82, pulse: 72),
      reading(12, 160, 95, pulse: 90),
      reading(8, 130, 85, pulse: 75),
      reading(16, 110, 70, pulse: 60),
    ];
    final day = DailyMeasurements.aggregate(records).single;
    expect(day.systolic!.first, 130);
    expect(day.systolic!.last, 125);
    expect(day.systolic!.maximum, 160);
    expect(day.systolic!.minimum, 110);
    expect(day.diastolic!.first, 85);
    expect(day.diastolic!.last, 82);
    expect(day.diastolic!.maximum, 95);
    expect(day.diastolic!.minimum, 70);
    expect(day.pulse!.first, 75);
    expect(day.pulse!.last, 72);
    expect(day.pulse!.minimum, 60);
    expect(day.pulse!.maximum, 90);
    expect(day.count, 4);
    expect(day.systolic!.firstMeasuredAt.hour, 8);
    expect(day.systolic!.lastMeasuredAt.hour, 20);
    expect(records.first.measuredAt.hour, 20, reason: '不修改调用方输入');
  });

  test('缺失脉搏不补零，首末次取当天有脉搏的测量', () {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, 80),
      reading(12, 130, 85, pulse: 78),
      reading(20, 125, 82),
      reading(8, 115, 75, day: 16),
    ]);
    final pulse = days.first.pulse!;
    expect(
      (pulse.first, pulse.last, pulse.minimum, pulse.maximum),
      (78, 78, 78, 78),
    );
    expect(pulse.count, 1);
    expect(pulse.firstMeasuredAt.hour, 12);
    expect(pulse.lastMeasuredAt.hour, 12);
    expect(days.last.pulse, isNull);
  });

  test('单次测量四值相同，日期排序且缺失日期留空', () {
    final days = DailyMeasurements.aggregate([
      reading(9, 122, 81, day: 17),
      reading(8, 120, 80),
    ]);
    expect(days.map((d) => d.date.day), [15, 17]);
    final c = days.first.systolic!;
    expect((c.first, c.last, c.minimum, c.maximum), (120, 120, 120, 120));
    expect(days.first.count, 1);
    expect(DailyMeasurements.aggregate([]), isEmpty);
  });

  test('同一测量时刻用创建时间及 ID 稳定排序', () {
    final older = reading(
      8,
      120,
      80,
      id: 'a',
      createdAt: DateTime(2026, 10, 15, 9),
    );
    final newer = reading(
      8,
      140,
      90,
      id: 'b',
      createdAt: DateTime(2026, 10, 15, 10),
    );
    final first = DailyMeasurements.aggregate([newer, older]).single;
    final second = DailyMeasurements.aggregate([older, newer]).single;
    expect(first.systolic!.first, 120);
    expect(first.systolic!.last, 140);
    expect(second.systolic!.first, first.systolic!.first);
    final sameCreated = reading(
      8,
      150,
      95,
      id: 'c',
      createdAt: newer.createdAt,
    );
    final tied = DailyMeasurements.aggregate([sameCreated, newer]).single;
    expect(tied.systolic!.first, 140);
    expect(tied.systolic!.last, 150);
  });

  test('软删除记录不进入趋势图', () {
    expect(
      DailyMeasurements.aggregate([
        reading(8, 200, 120, deletedAt: DateTime(2026, 10, 15, 9)),
      ]),
      isEmpty,
    );
  });
}
