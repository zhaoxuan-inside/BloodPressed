/// 测量提醒测试：ReminderSchedule 纯逻辑（occurrence 计算）与 AppSettings 提醒配置。
///
/// ReminderSchedule 为 algorithm 纯函数（无 IO / 无时区依赖，使用本地 DateTime），
/// 覆盖：窗口未开始 / 窗口进行中 / 窗口已过、间隔不整除窗口、horizon 截断、
/// 上限截断、非法配置。AppSettings 覆盖旧版 reminderEnabled 布尔的迁移。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/settings/domain/reminder_schedule.dart';

IntervalReminderConfig _config({
  int startHour = 8,
  int startMinute = 0,
  int endHour = 10,
  int endMinute = 0,
  int intervalMinutes = 30,
}) =>
    IntervalReminderConfig(
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      intervalMinutes: intervalMinutes,
    );

DateTime _at(int year, int month, int day, int hour, [int minute = 0]) =>
    DateTime(year, month, day, hour, minute);

void main() {
  group('ReminderSchedule.occurrences', () {
    test('窗口未开始：从开始时刻起按间隔排程，结束时刻整除时包含', () {
      // 2026-10-04 06:00（窗口 8:00-10:00，间隔 30 分钟），水平 1 天 = 今天+明天
      final now = _at(2026, 10, 4, 6, 0);
      final list = ReminderSchedule.occurrences(
          config: _config(), now: now, horizonDays: 1);

      expect(list.first, _at(2026, 10, 4, 8, 0));
      // 今天 8:00..10:00 共 5 条 + 明天 5 条
      expect(list, hasLength(10));
      expect(list[4], _at(2026, 10, 4, 10, 0));
      expect(list.last, _at(2026, 10, 5, 10, 0));
    });

    test('窗口进行中：只排严格晚于 now 的触发时刻', () {
      // 08:50 在窗口内：下一个是 9:00（horizon 0 = 仅今天）
      final now = _at(2026, 10, 4, 8, 50);
      final list = ReminderSchedule.occurrences(
          config: _config(), now: now, horizonDays: 0);

      expect(list.first, _at(2026, 10, 4, 9, 0));
      expect(list, hasLength(3)); // 9:00, 9:30, 10:00
    });

    test('窗口已过：排到明天的窗口', () {
      final now = _at(2026, 10, 4, 11, 0);
      final list = ReminderSchedule.occurrences(
          config: _config(), now: now, horizonDays: 2);

      expect(list.first, _at(2026, 10, 5, 8, 0));
      // 明天 5 个 + 后天 5 个
      expect(list, hasLength(10));
      expect(list.last, _at(2026, 10, 6, 10, 0));
    });

    test('间隔不整除窗口：末次触发不晚于结束时刻', () {
      // 8:00-9:20 每 30 分钟：8:00, 8:30, 9:00（9:30 > 9:20 舍弃）
      final now = _at(2026, 10, 4, 6, 0);
      final list = ReminderSchedule.occurrences(
        config: _config(endHour: 9, endMinute: 20),
        now: now,
        horizonDays: 0,
      );

      expect(list, hasLength(3));
      expect(list.last, _at(2026, 10, 4, 9, 0));
    });

    test('horizonDays=0：只包含今天剩余触发时刻', () {
      final now = _at(2026, 10, 4, 8, 50);
      final list = ReminderSchedule.occurrences(
          config: _config(), now: now, horizonDays: 0);

      expect(list, hasLength(3)); // 9:00, 9:30, 10:00
    });

    test('上限截断：最多返回 max 条', () {
      // 0:00-23:59 每 15 分钟一天约 96 条，max=10 应截断
      final now = _at(2026, 10, 4, 0, 0);
      final list = ReminderSchedule.occurrences(
        config: _config(
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            intervalMinutes: 15),
        now: now,
        horizonDays: 2,
        max: 10,
      );

      expect(list, hasLength(10));
      // 严格递增
      for (var i = 1; i < list.length; i++) {
        expect(list[i].isAfter(list[i - 1]), isTrue);
      }
    });

    test('非法配置：间隔 < 15 分钟抛 ArgumentError，start >= end 抛 ArgumentError', () {
      final now = _at(2026, 10, 4, 6, 0);
      expect(
        () => ReminderSchedule.occurrences(
            config: _config(intervalMinutes: 10), now: now),
        throwsArgumentError,
      );
      expect(
        () => ReminderSchedule.occurrences(
            config: _config(startHour: 10, endHour: 8), now: now),
        throwsArgumentError,
      );
    });
  });

  group('AppSettings 提醒配置', () {
    test('旧配置迁移：reminder_enabled=true 迁移为 daily，false 为 off', () async {
      SharedPreferences.setMockInitialValues(
          {'reminder_enabled': true, 'reminder_hour': 7, 'reminder_minute': 30});
      final s = AppSettings(await SharedPreferences.getInstance());
      expect(s.reminderMode, ReminderMode.daily);
      expect(s.reminderHour, 7);
      expect(s.reminderMinute, 30);

      SharedPreferences.setMockInitialValues({'reminder_enabled': false});
      final s2 = AppSettings(await SharedPreferences.getInstance());
      expect(s2.reminderMode, ReminderMode.off);
    });

    test('周期提醒配置读写与校验往返', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings(await SharedPreferences.getInstance());

      expect(s.reminderMode, ReminderMode.off);
      expect(s.intervalStartHour, 8);
      expect(s.intervalStartMinute, 0);
      expect(s.intervalEndHour, 20);
      expect(s.intervalEndMinute, 0);
      expect(s.intervalMinutes, 30);

      await s.setReminderMode(ReminderMode.interval);
      await s.setIntervalWindow(9, 15, 21, 45);
      await s.setIntervalMinutes(60);

      expect(s.reminderMode, ReminderMode.interval);
      expect(s.intervalStartHour, 9);
      expect(s.intervalStartMinute, 15);
      expect(s.intervalEndHour, 21);
      expect(s.intervalEndMinute, 45);
      expect(s.intervalMinutes, 60);
    });

    test('intervalMinutes 非法值（<15）存储时抛 ArgumentError', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings(await SharedPreferences.getInstance());
      expect(() => s.setIntervalMinutes(10), throwsArgumentError);
    });
  });
}
