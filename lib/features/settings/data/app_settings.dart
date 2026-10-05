import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/settings/domain/reminder_schedule.dart';

/// 测量提醒方式。
enum ReminderMode { off, daily, interval }

/// 应用设置（SharedPreferences KV）。
class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static const _kDeviceId = 'device_id';
  static const _kDefaultArm = 'default_arm';
  static const _kActiveLlmProfile = 'active_llm_profile';
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kReminderHour = 'reminder_hour';
  static const _kReminderMinute = 'reminder_minute';
  static const _kReminderMode = 'reminder_mode';
  static const _kIntervalStartHour = 'interval_start_hour';
  static const _kIntervalStartMinute = 'interval_start_minute';
  static const _kIntervalEndHour = 'interval_end_hour';
  static const _kIntervalEndMinute = 'interval_end_minute';
  static const _kIntervalMinutes = 'interval_minutes';
  static const _kThemeMode = 'theme_mode'; // system/light/dark
  static const _kWechatAppId = 'wechat_app_id';
  static const _kWechatUniversalLink = 'wechat_universal_link';
  static const _kKnowledgeFontScale = 'knowledge_font_scale';
  static const _kFavoriteArticles = 'favorite_articles';

  // ---- 设备标识（多端同步预留） ----
  Future<String> deviceId() async {
    var id = _prefs.getString(_kDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await _prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  // ---- 默认测量臂 ----
  MeasureArm get defaultArm =>
      _prefs.getString(_kDefaultArm) == 'right'
          ? MeasureArm.right
          : MeasureArm.left;
  Future<void> setDefaultArm(MeasureArm arm) =>
      _prefs.setString(_kDefaultArm, arm.name);

  // ---- 当前激活的 LLM 配置 ----
  String? get activeLlmProfileId => _prefs.getString(_kActiveLlmProfile);
  Future<void> setActiveLlmProfile(String? id) => id == null
      ? _prefs.remove(_kActiveLlmProfile)
      : _prefs.setString(_kActiveLlmProfile, id);

  // ---- 测量提醒 ----

  /// 旧版布尔开关（仅作迁移读取，新代码使用 [reminderMode]）。
  bool get reminderEnabled => _prefs.getBool(_kReminderEnabled) ?? false;
  Future<void> setReminderEnabled(bool v) =>
      _prefs.setBool(_kReminderEnabled, v);

  int get reminderHour => _prefs.getInt(_kReminderHour) ?? 8;
  int get reminderMinute => _prefs.getInt(_kReminderMinute) ?? 0;
  Future<void> setReminderTime(int hour, int minute) async {
    await _prefs.setInt(_kReminderHour, hour);
    await _prefs.setInt(_kReminderMinute, minute);
  }

  /// 提醒方式：旧版仅有布尔开关，未显式存储时按其值迁移。
  ReminderMode get reminderMode {
    final raw = _prefs.getString(_kReminderMode);
    if (raw != null) {
      return ReminderMode.values
          .firstWhere((m) => m.name == raw, orElse: () => ReminderMode.off);
    }
    return reminderEnabled ? ReminderMode.daily : ReminderMode.off;
  }

  Future<void> setReminderMode(ReminderMode mode) =>
      _prefs.setString(_kReminderMode, mode.name);

  // 周期提醒：提醒窗口（当日时刻，start < end）与提醒周期。
  int get intervalStartHour => _prefs.getInt(_kIntervalStartHour) ?? 8;
  int get intervalStartMinute => _prefs.getInt(_kIntervalStartMinute) ?? 0;
  int get intervalEndHour => _prefs.getInt(_kIntervalEndHour) ?? 20;
  int get intervalEndMinute => _prefs.getInt(_kIntervalEndMinute) ?? 0;
  int get intervalMinutes => _prefs.getInt(_kIntervalMinutes) ?? 30;

  Future<void> setIntervalWindow(
      int startHour, int startMinute, int endHour, int endMinute) async {
    await _prefs.setInt(_kIntervalStartHour, startHour);
    await _prefs.setInt(_kIntervalStartMinute, startMinute);
    await _prefs.setInt(_kIntervalEndHour, endHour);
    await _prefs.setInt(_kIntervalEndMinute, endMinute);
  }

  Future<void> setIntervalMinutes(int minutes) {
    if (minutes < IntervalReminderConfig.minIntervalMinutes) {
      throw ArgumentError.value(
          minutes, 'intervalMinutes', '提醒周期不得小于 '
          '${IntervalReminderConfig.minIntervalMinutes} 分钟');
    }
    return _prefs.setInt(_kIntervalMinutes, minutes);
  }

  // ---- 主题模式 ----
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  // ---- 微信开放平台（分享） ----
  String get wechatAppId => _prefs.getString(_kWechatAppId) ?? '';
  Future<void> setWechatAppId(String v) => _prefs.setString(_kWechatAppId, v);
  String get wechatUniversalLink =>
      _prefs.getString(_kWechatUniversalLink) ?? '';
  Future<void> setWechatUniversalLink(String v) =>
      _prefs.setString(_kWechatUniversalLink, v);

  // ---- 知识阅读字号 ----
  double get knowledgeFontScale =>
      _prefs.getDouble(_kKnowledgeFontScale) ?? 1.0;
  Future<void> setKnowledgeFontScale(double v) =>
      _prefs.setDouble(_kKnowledgeFontScale, v);

  // ---- 文章收藏 ----
  List<String> get favoriteArticles =>
      _prefs.getStringList(_kFavoriteArticles) ?? [];
  bool isFavorite(String articleId) =>
      favoriteArticles.contains(articleId);
  Future<void> toggleFavorite(String articleId) async {
    final list = [...favoriteArticles];
    if (list.contains(articleId)) {
      list.remove(articleId);
    } else {
      list.add(articleId);
    }
    await _prefs.setStringList(_kFavoriteArticles, list);
  }
}
