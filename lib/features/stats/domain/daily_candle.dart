import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// 单项指标的实际读数范围及按测量时间确定的首末值。
class MeasurementCandle {
  const MeasurementCandle({
    required this.first,
    required this.last,
    required this.minimum,
    required this.maximum,
    required this.count,
    required this.firstMeasuredAt,
    required this.lastMeasuredAt,
  });

  final int first;
  final int last;
  final int minimum;
  final int maximum;
  final int count;
  final DateTime firstMeasuredAt;
  final DateTime lastMeasuredAt;

  static MeasurementCandle? _fromOrdered(
    List<BpRecord> records,
    int? Function(BpRecord) valueOf,
  ) {
    final values = [
      for (final record in records)
        if (valueOf(record) case final int value) (record.measuredAt, value),
    ];
    if (values.isEmpty) return null;
    final readings = values.map((v) => v.$2);
    return MeasurementCandle(
      first: values.first.$2,
      last: values.last.$2,
      minimum: readings.reduce((a, b) => a < b ? a : b),
      maximum: readings.reduce((a, b) => a > b ? a : b),
      count: values.length,
      firstMeasuredAt: values.first.$1,
      lastMeasuredAt: values.last.$1,
    );
  }
}

/// 一天的血压和脉搏蜡烛；无数据的日期、缺失的脉搏不补值。
class DayCandle {
  const DayCandle({
    required this.date,
    required this.systolic,
    required this.diastolic,
    this.pulse,
  });

  final DateTime date;
  final MeasurementCandle systolic;
  final MeasurementCandle diastolic;
  final MeasurementCandle? pulse;
  int get count => systolic.count;

  static List<DayCandle> aggregate(List<BpRecord> records) {
    final byDay = <DateTime, List<BpRecord>>{};
    for (final record in records) {
      if (record.isDeleted) continue;
      final time = record.measuredAt;
      final date = DateTime(time.year, time.month, time.day);
      byDay.putIfAbsent(date, () => []).add(record);
    }
    final days = byDay.entries.map((entry) {
      final ordered = entry.value
        ..sort((a, b) {
          final measured = a.measuredAt.compareTo(b.measuredAt);
          if (measured != 0) return measured;
          final created = a.createdAt.compareTo(b.createdAt);
          return created != 0 ? created : a.id.compareTo(b.id);
        });
      return DayCandle(
        date: entry.key,
        systolic: MeasurementCandle._fromOrdered(ordered, (r) => r.systolic)!,
        diastolic: MeasurementCandle._fromOrdered(ordered, (r) => r.diastolic)!,
        pulse: MeasurementCandle._fromOrdered(ordered, (r) => r.pulse),
      );
    }).toList();
    days.sort((a, b) => a.date.compareTo(b.date));
    return days;
  }
}
