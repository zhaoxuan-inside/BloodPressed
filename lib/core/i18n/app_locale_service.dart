import 'package:flutter/material.dart';

/// 当前生效语言的进程级快照，供无 BuildContext 的取词场景使用：
/// 测量提醒通知、CSV 表头、分享卡片、Fmt 日期文案、枚举 label 兜底。
///
/// 由 app.dart 的 MaterialApp.builder 在每次 Localizations 变更时刷新；
/// 初始值与存量数据层中文文案一致。
class AppLocaleService {
  AppLocaleService._();

  static Locale current = const Locale('zh');

  static bool get isEn => current.languageCode == 'en';
}
