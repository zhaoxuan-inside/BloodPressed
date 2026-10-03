import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:blood_pressed/features/records/domain/bp_record.dart';

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

  // ---- 每日测量提醒 ----
  bool get reminderEnabled => _prefs.getBool(_kReminderEnabled) ?? false;
  Future<void> setReminderEnabled(bool v) =>
      _prefs.setBool(_kReminderEnabled, v);

  int get reminderHour => _prefs.getInt(_kReminderHour) ?? 8;
  int get reminderMinute => _prefs.getInt(_kReminderMinute) ?? 0;
  Future<void> setReminderTime(int hour, int minute) async {
    await _prefs.setInt(_kReminderHour, hour);
    await _prefs.setInt(_kReminderMinute, minute);
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
