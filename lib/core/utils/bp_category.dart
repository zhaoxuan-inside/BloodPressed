/// 血压分级工具。
///
/// 采用《中国高血压防治指南》的家庭自测标准（家庭自测血压 ≥135/85 mmHg 视为升高），
/// 颜色语义与多数血压计保持一致：
/// 绿=正常，黄=正常高值，橙=1级（轻度升高），红=2级及以上（中重度升高），紫=偏低。
library;

enum BpCategory {
  low('偏低', '血压偏低，若无不适无需处理；若伴头晕乏力请咨询医生。'),
  normal('正常', '血压处于理想范围，请继续保持健康生活方式。'),
  elevated('正常高值', '血压偏高但未达高血压水平，建议限盐、运动并规律复测。'),
  grade1('轻度升高', '血压已达1级高血压水平（家庭自测），建议复测并咨询医生。'),
  grade2('中重度升高', '血压明显升高，建议尽快就医评估，切勿自行调整用药。');

  const BpCategory(this.label, this.advice);

  final String label;
  final String advice;

  /// 家庭自测阈值：高压 <135 且 低压 <85 视为正常。
  static const double homeElevatedSystolic = 135;
  static const double homeElevatedDiastolic = 85;

  static BpCategory fromValues(int systolic, int diastolic) {
    if (systolic < 90 || diastolic < 60) return BpCategory.low;
    if (systolic >= 160 || diastolic >= 100) return BpCategory.grade2;
    if (systolic >= 140 || diastolic >= 90) return BpCategory.grade1;
    if (systolic >= 130 || diastolic >= 85) return BpCategory.elevated;
    return BpCategory.normal;
  }

  /// 是否达到"需要关注"及以上水平（正常高值及以上）。
  bool get needsAttention =>
      this == BpCategory.elevated ||
      this == BpCategory.grade1 ||
      this == BpCategory.grade2;
}

/// 分级配色（亮/暗主题下均可读）。
class BpCategoryColor {
  static const int low = 0xFF7E57C2; // 紫
  static const int normal = 0xFF43A047; // 绿
  static const int elevated = 0xFFF9A825; // 黄
  static const int grade1 = 0xFFEF6C00; // 橙
  static const int grade2 = 0xFFD32F2F; // 红
}
