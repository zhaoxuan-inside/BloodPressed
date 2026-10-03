import 'package:flutter/material.dart';

/// 设计令牌：间距、圆角与组件尺寸。
abstract final class AppDimens {
  // ---- 间距（4pt 网格） ----
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 24;
  static const double spaceXxxl = 32;

  // ---- 圆角 ----
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;

  // ---- 组件 ----
  /// 列表分组的水平内边距（SectionHeader、卡片列表通用）。
  static const double listPaddingH = 16;

  /// 分级徽章内边距。
  static const EdgeInsets badgePadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 3);
}
