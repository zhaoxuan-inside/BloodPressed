import 'dart:ui';

/// 设计令牌：颜色。
///
/// 全应用的颜色唯一来源（Material Design 设计系统约定）：
/// 组件与页面禁止内联硬编码色值，一律引用此处或 ColorScheme。
abstract final class AppColors {
  // ---- 品牌 ----
  static const Color seed = Color(0xFF00897B);

  // ---- 血压分级色板（中国指南家庭自测标准） ----
  static const Color bpLow = Color(0xFF7E57C2); // 紫 · 偏低
  static const Color bpNormal = Color(0xFF43A047); // 绿 · 正常
  static const Color bpElevated = Color(0xFFF9A825); // 黄 · 正常高值
  static const Color bpGrade1 = Color(0xFFEF6C00); // 橙 · 轻度升高
  static const Color bpGrade2 = Color(0xFFD32F2F); // 红 · 中重度升高

  // ---- 图表系列色 ----
  static const Color chartSystolic = Color(0xFFE53935);
  static const Color chartDiastolic = Color(0xFF1E88E5);
  static const Color chartPulse = Color(0xFF43A047);
}
