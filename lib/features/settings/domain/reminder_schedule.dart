/// 测量提醒触发时刻计算（纯逻辑，无 IO / 无时区依赖，algorithm）。
///
/// 周期提醒在提醒窗口 [start, end] 内从开始时刻按提醒周期递增生成触发时刻，
/// 末次不晚于结束时刻；跨天排程由 [occurrences] 的 horizonDays 控制，
/// 时区转换由 ReminderService 完成。
library;

import 'package:flutter/foundation.dart';

/// 周期提醒配置（提醒窗口 + 提醒周期）。
@immutable
class IntervalReminderConfig {
  /// 校验失败的参数抛 ArgumentError：提醒周期不足下限、窗口开始不早于结束。
  IntervalReminderConfig({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
  }) {
    if (intervalMinutes < minIntervalMinutes) {
      throw ArgumentError.value(
          intervalMinutes, 'intervalMinutes', '提醒周期不得小于 $minIntervalMinutes 分钟');
    }
    if (startMinuteOfDay >= endMinuteOfDay) {
      throw ArgumentError('提醒窗口要求开始时刻早于结束时刻');
    }
  }

  /// 周期下限：与系统定时能力对齐，过密的提醒无实际意义。
  static const int minIntervalMinutes = 15;

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;

  int get startMinuteOfDay => startHour * 60 + startMinute;
  int get endMinuteOfDay => endHour * 60 + endMinute;
}

/// 触发时刻计算。
class ReminderSchedule {
  ReminderSchedule._();

  /// 本地通知待排上限（iOS UNUserNotificationCenter 上限 64，
  /// 预留 1 条给每日定时提醒）。
  static const int maxPendingNotifications = 64;

  /// 计算从 now 起最多 horizonDays 天内、严格晚于 now 的周期提醒触发时刻。
  ///
  /// 每天从窗口开始时刻按提醒周期递增到结束时刻（含整除的结束时刻）；
  /// 返回按时间升序、最多 [max] 条。
  static List<DateTime> occurrences({
    required IntervalReminderConfig config,
    required DateTime now,
    int horizonDays = 2,
    int max = maxPendingNotifications - 1,
  }) {
    if (horizonDays < 0) {
      throw ArgumentError.value(horizonDays, 'horizonDays', '不得为负');
    }
    if (max < 1) {
      throw ArgumentError.value(max, 'max', '至少为 1');
    }
    final result = <DateTime>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var dayOffset = 0;
        dayOffset <= horizonDays && result.length < max;
        dayOffset++) {
      final dayStart = today.add(Duration(days: dayOffset));
      for (var minute = config.startMinuteOfDay;
          minute <= config.endMinuteOfDay && result.length < max;
          minute += config.intervalMinutes) {
        final at = dayStart.add(Duration(minutes: minute));
        if (at.isAfter(now)) result.add(at);
      }
    }
    return result;
  }
}
