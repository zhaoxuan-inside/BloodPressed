import 'package:blood_pressed/features/records/domain/bp_record.dart';

import 'daily_measurements.dart';

/// All readings in time order. Null entries explicitly break paths across unmeasured days.
class TrendTimeline {
  TrendTimeline(List<DailyMeasurements> days)
    : entries = List.unmodifiable(_entries(days));

  final List<BpRecord?> entries;

  static List<BpRecord?> _entries(List<DailyMeasurements> days) {
    final ordered = DailyMeasurements.aggregate(
      days.expand((d) => d.records).toList(),
    );
    final result = <BpRecord?>[];
    DateTime? previous;
    for (final day in ordered) {
      final date = DateTime.utc(day.date.year, day.date.month, day.date.day);
      if (previous != null && date.difference(previous).inDays > 1) {
        result.add(null);
      }
      result.addAll(day.records);
      previous = date;
    }
    return result;
  }

  /// Calendar days plus time of day: no distortion from DST or unequal sample counts.
  static double xOf(DateTime measuredAt, DateTime start) {
    final day = DateTime.utc(measuredAt.year, measuredAt.month, measuredAt.day);
    final origin = DateTime.utc(start.year, start.month, start.day);
    final micros =
        ((measuredAt.hour * 60 + measuredAt.minute) * 60 + measuredAt.second) *
            1000000 +
        measuredAt.millisecond * 1000 +
        measuredAt.microsecond;
    return day.difference(origin).inDays + micros / Duration.microsecondsPerDay;
  }
}
