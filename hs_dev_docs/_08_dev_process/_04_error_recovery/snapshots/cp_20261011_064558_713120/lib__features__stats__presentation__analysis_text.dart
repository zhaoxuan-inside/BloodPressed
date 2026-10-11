/// 规律分析文案助手：结论规则、模型摘要、范围标签——趋势页与全屏
/// 图表页共用（此前在 stats_page 内私有，全屏页加入口时提取共享）。
library;

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 时段标签（l10n）。
String bucketLabel(AppLocalizations l10n, TimeBucket b) => switch (b) {
      TimeBucket.night => l10n.bucketNight,
      TimeBucket.morning => l10n.bucketMorning,
      TimeBucket.afternoon => l10n.bucketAfternoon,
      TimeBucket.evening => l10n.bucketEvening,
    };

/// 结论规则：时段均值达偏高口径（≥135/85）指出该时段；否则全部理想。
String analysisConclusion(BpAnalysis a, AppLocalizations l10n) {
  for (final b in a.buckets) {
    if (b.avgElevated) {
      return l10n.analysisConclusionElevated(bucketLabel(l10n, b.bucket),
          b.avgSystolic.toStringAsFixed(0), b.avgDiastolic.toStringAsFixed(0));
    }
  }
  return l10n.analysisConclusionIdeal;
}

/// 模型分析请求的数据摘要：紧凑中文数字串（模型侧中文上下文），
/// 不随 UI 语言变化——由「AI 分析」请求自带，供门禁与流式两条路径共用。
String analysisSummaryZh(BpAnalysis a) {
  const zhBucket = {
    TimeBucket.night: '夜间',
    TimeBucket.morning: '清晨',
    TimeBucket.afternoon: '下午',
    TimeBucket.evening: '晚间',
  };
  final parts = <String>['共${a.totalCount}次测量'];
  for (final b in a.buckets) {
    parts.add(
        '${zhBucket[b.bucket]}均${b.avgSystolic.round()}/${b.avgDiastolic.round()}（达标${b.onTargetCount}/${b.count}）');
  }
  if (a.peakRecord != null) {
    parts.add('最高单次${a.peakRecord!.systolic}/${a.peakRecord!.diastolic}');
  }
  final onTarget = a.totalCount - a.abnormalCount;
  parts.add('达标率${(onTarget * 100 / a.totalCount).round()}%');
  return '${parts.join('；')}。';
}

/// 查询范围标签：自定义「M月d日-M月d日」（en M/d-M/d），预设走
/// statsRangeLabel（近7天/近30天/…）。
String trendRangeLabel(TrendQuery q, AppLocalizations l10n) {
  if (!q.isCustom) return statsRangeLabel(l10n, q.days);
  String fmt(DateTime d) => AppLocaleService.isEn
      ? '${d.month}/${d.day}'
      : '${d.month}月${d.day}日';
  return '${fmt(q.from!)}-${fmt(DateTime(q.to!.year, q.to!.month, q.to!.day))}';
}
