import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// 单项指标的实际读数范围及按测量时间确定的首末值。
class MeasurementSummary {
  const MeasurementSummary({
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

  static MeasurementSummary? _fromOrdered(
    List<BpRecord> records,
    int? Function(BpRecord) valueOf,
  ) {
    final values = [
      for (final record in records)
        if (valueOf(record) case final int value) (record.measuredAt, value),
    ];
    if (values.isEmpty) return null;
    final readings = values.map((v) => v.$2);
    return MeasurementSummary(
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

/// 每日原始测量和摘要；无数据的日期、缺失的脉搏不补值。
class DailyMeasurements {
  const DailyMeasurements({
    required this.date,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.records,
  });

  final DateTime date;
  final MeasurementSummary? systolic;
  final MeasurementSummary? diastolic;
  final MeasurementSummary? pulse;
  final List<BpRecord> records;
  int get count => records.length;

  static List<DailyMeasurements> aggregate(List<BpRecord> records) {
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
      return DailyMeasurements(
        date: entry.key,
        systolic: MeasurementSummary._fromOrdered(ordered, (r) => r.systolic),
        diastolic: MeasurementSummary._fromOrdered(ordered, (r) => r.diastolic),
        pulse: MeasurementSummary._fromOrdered(ordered, (r) => r.pulse),
        records: List.unmodifiable(ordered),
      );
    }).toList();
    days.sort((a, b) => a.date.compareTo(b.date));
    return days;
  }
}
