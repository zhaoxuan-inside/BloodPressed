import 'dart:ui';

import 'package:blood_pressed/core/utils/bp_category.dart';
import 'app_colors.dart';

/// 血压分级的视觉样式映射（颜色徽章/色条/建议色统一出处）。
abstract final class BpCategoryStyle {
  static Color colorOf(BpCategory category) => switch (category) {
        BpCategory.low => AppColors.bpLow,
        BpCategory.normal => AppColors.bpNormal,
        BpCategory.elevated => AppColors.bpElevated,
        BpCategory.grade1 => AppColors.bpGrade1,
        BpCategory.grade2 => AppColors.bpGrade2,
      };

  /// 徽章/淡色背景用（主色低透明度）。
  static Color containerOf(BpCategory category) =>
      colorOf(category).withValues(alpha: 0.12);
}
