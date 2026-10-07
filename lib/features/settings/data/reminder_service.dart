import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/settings/domain/reminder_schedule.dart';

/// 定时通知触发时的后台回调入口（顶层函数 + entry-point 标注，
/// 防止 release AOT 被 tree-shaking 剥离导致通知静默丢失）。
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse details) async {}

/// 测量提醒（本地通知）：每日定时提醒 + 周期提醒（提醒窗口内按提醒周期）。
///
/// 周期提醒采用"批量预排一次性通知"：以 2 天为水平按触发时刻逐条排程
/// （上限 [ReminderSchedule.maxPendingNotifications] - 1 条，为每日提醒留位），
/// 应用启动、设置变更时整体重排。
class ReminderService {
  ReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyId = 1001;
  static const int _intervalIdBase = 2000;
  static const int _intervalHorizonDays = 2;
  static bool _initialized = false;

  static NotificationDetails get _dailyDetails {
    final l10n = AppLocaleService.auto;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        l10n.channelDailyName,
        channelDescription: l10n.channelDailyDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  static NotificationDetails get _intervalDetails {
    final l10n = AppLocaleService.auto;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'interval_reminder',
        l10n.channelIntervalName,
        channelDescription: l10n.channelIntervalDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 兜底：无法获取时区时使用 UTC，提醒时刻可能偏移，但不崩溃
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _initialized = true;
    } catch (_) {
      // 通知插件不可用（如桌面/测试环境）时静默跳过
    }
  }

  /// 确保两个通知通道已创建（v19 的排程不再自动建通道，
  /// 缺 channel 会让通知静默丢失）。
  static Future<void> _ensureChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final l10n = AppLocaleService.auto;
    try {
      await android.createNotificationChannel(AndroidNotificationChannel(
        'daily_reminder',
        l10n.channelDailyName,
        description: l10n.channelDailyDesc,
        importance: Importance.high,
      ));
      await android.createNotificationChannel(AndroidNotificationChannel(
        'interval_reminder',
        l10n.channelIntervalName,
        description: l10n.channelIntervalDesc,
        importance: Importance.high,
      ));
    } catch (_) {}
  }

  /// Android 13+ 通知权限；Android 12+ 精确闹钟（SCHEDULE_EXACT_ALARM）。
  static Future<bool> requestExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final notif = await Permission.notification.request();
    return notif.isGranted;
  }

  /// 按当前设置重排全部提醒（先清空旧排程，再按提醒方式排程）。
  static Future<void> scheduleFromSettings(AppSettings settings) async {
    await init();
    await _ensureChannels();
    await cancelAllReminders();
    switch (settings.reminderMode) {
      case ReminderMode.off:
        return;
      case ReminderMode.daily:
        await _scheduleDaily(
            hour: settings.reminderHour, minute: settings.reminderMinute);
      case ReminderMode.interval:
        await _scheduleInterval(settings);
    }
  }

  static Future<void> _scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _zonedSchedule(
      _dailyId,
      scheduled,
      _dailyDetails,
      matchTime: true,
      payload: 'daily_reminder',
    );
  }

  static Future<void> _scheduleInterval(AppSettings settings) async {
    final config = IntervalReminderConfig(
      startHour: settings.intervalStartHour,
      startMinute: settings.intervalStartMinute,
      endHour: settings.intervalEndHour,
      endMinute: settings.intervalEndMinute,
      intervalMinutes: settings.intervalMinutes,
    );
    final occurrences = ReminderSchedule.occurrences(
      config: config,
      now: DateTime.now(),
      horizonDays: _intervalHorizonDays,
    );
    for (var i = 0; i < occurrences.length; i++) {
      final at = occurrences[i];
      final scheduled = tz.TZDateTime(
          tz.local, at.year, at.month, at.day, at.hour, at.minute);
      final ok = await _zonedSchedule(
        _intervalIdBase + i,
        scheduled,
        _intervalDetails,
        payload: 'interval_reminder',
      );
      if (!ok) return;
    }
  }

  /// 单条排程；通知插件不可用或系统拒绝时返回 false（静默跳过）。
  static Future<bool> _zonedSchedule(
    int id,
    tz.TZDateTime at,
    NotificationDetails details, {
    required String payload,
    bool matchTime = false,
  }) async {
    try {
      final l10n = AppLocaleService.auto;
      await _plugin.zonedSchedule(
        id,
        l10n.notifDailyTitle,
        l10n.notifDailyBody,
        at,
        details,
        // 提醒必须准时：使用精确闹钟（manifest 已声明 USE_EXACT_ALARM）
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            matchTime ? DateTimeComponents.time : null,
        payload: payload,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelAllReminders() async {
    try {
      await _plugin.cancel(_dailyId);
    } catch (_) {}
    for (var i = 0; i < ReminderSchedule.maxPendingNotifications; i++) {
      try {
        await _plugin.cancel(_intervalIdBase + i);
      } catch (_) {
        return;
      }
    }
  }
}
