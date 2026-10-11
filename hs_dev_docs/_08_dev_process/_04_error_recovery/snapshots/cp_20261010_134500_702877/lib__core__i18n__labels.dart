import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 枚举类文案的 l10n 映射助手（一物一名，避免各处散落 switch）。
///
/// UI 有 context 时传 `AppLocalizations.of(context)`；
/// 无 context 场景（CSV/分享卡/通知）传 `AppLocaleService.auto`。
String armLabel(AppLocalizations l10n, MeasureArm arm) =>
    arm == MeasureArm.left ? l10n.armLeft : l10n.armRight;

String postureLabel(AppLocalizations l10n, MeasurePosture? posture) =>
    switch (posture) {
      null => l10n.postureNotRecorded,
      MeasurePosture.lying => l10n.postureLying,
      MeasurePosture.sitting => l10n.postureSitting,
      MeasurePosture.standing => l10n.postureStanding,
    };

String sourceLabel(AppLocalizations l10n, RecordSource source) =>
    switch (source) {
      RecordSource.manual => l10n.sourceManual,
      RecordSource.ocr => l10n.sourceOcr,
      RecordSource.ai => l10n.sourceAi,
    };

String categoryLabel(AppLocalizations l10n, BpCategory category) =>
    switch (category) {
      BpCategory.low => l10n.categoryLow,
      BpCategory.normal => l10n.categoryNormal,
      BpCategory.elevated => l10n.categoryElevated,
      BpCategory.grade1 => l10n.categoryGrade1,
      BpCategory.grade2 => l10n.categoryGrade2,
    };

String categoryAdvice(AppLocalizations l10n, BpCategory category) =>
    switch (category) {
      BpCategory.low => l10n.adviceLow,
      BpCategory.normal => l10n.adviceNormal,
      BpCategory.elevated => l10n.adviceElevated,
      BpCategory.grade1 => l10n.adviceGrade1,
      BpCategory.grade2 => l10n.adviceGrade2,
    };

/// 统计范围标签（近7天/近30天/近90天/全部），对应 kStatsRanges 的 days。
String statsRangeLabel(AppLocalizations l10n, int days) {
  if (days <= 7) return l10n.range7;
  if (days <= 30) return l10n.range30;
  if (days <= 90) return l10n.range90;
  return l10n.rangeAll;
}
