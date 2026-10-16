import 'package:flutter/material.dart';

import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 规律分析卡：折叠态一行结论，展开为时段条形 + 星期对比 + 峰值。
/// 「AI 分析」与「分享」由宿主页面注入回调。
class AnalysisCard extends StatefulWidget {
  const AnalysisCard({
    super.key,
    required this.analysis,
    required this.conclusion,
    required this.onAiAnalyze,
    required this.onShare,
  });

  final BpAnalysis analysis;
  final String conclusion;
  final VoidCallback onAiAnalyze;
  final VoidCallback onShare;

  @override
  State<AnalysisCard> createState() => _AnalysisCardState();
}

class _AnalysisCardState extends State<AnalysisCard> {
  bool _expanded = false;

  static String _bucketLabel(AppLocalizations l10n, TimeBucket b) =>
      switch (b) {
        TimeBucket.night => l10n.bucketNight,
        TimeBucket.morning => l10n.bucketMorning,
        TimeBucket.afternoon => l10n.bucketAfternoon,
        TimeBucket.evening => l10n.bucketEvening,
      };

  static String _weekdayLabel(AppLocalizations l10n, int weekday) {
    final zh = const ['一', '二', '三', '四', '五', '六', '日'];
    final en = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppLocaleService.isEn ? en[weekday - 1] : zh[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final a = widget.analysis;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.analysisTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.statsAiAnalyze,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  onPressed: widget.onAiAnalyze,
                ),
                IconButton(
                  tooltip: l10n.shareMore,
                  icon: const Icon(Icons.ios_share, size: 20),
                  onPressed: widget.onShare,
                ),
                IconButton(
                  tooltip: _expanded ? l10n.statsCustom : l10n.analysisTitle,
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 结论行（常显）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a.abnormalCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 15,
                  color: a.abnormalCount > 0
                      ? theme.colorScheme.error
                      : Colors.green,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.conclusion,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              // 时段条形
              for (final b in a.buckets) ...[
                _BucketRow(label: _bucketLabel(l10n, b.bucket), stats: b),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),
              // 星期对比
              if (a.weekdays.isNotEmpty)
                Row(
                  children: [
                    for (final w in a.weekdays)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              w.avgSystolic.toStringAsFixed(0),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: w.avgSystolic >= 135
                                    ? theme.colorScheme.error
                                    : null,
                              ),
                            ),
                            Text(
                              _weekdayLabel(l10n, w.weekday),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              // 峰值
              if (a.peakRecord != null)
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 14,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.analysisPeakLine(
                          a.peakRecord!.systolic!,
                          a.peakRecord!.diastolic!,
                          Fmt.full(a.peakRecord!.measuredAt),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 时段行：名称 + 平均高压条形（80~180 量程）+ 数值 + 达标计数。
class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.label, required this.stats});

  final String label;
  final BucketStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fraction = ((stats.avgSystolic - 80) / 100).clamp(0.0, 1.0);
    final barColor = stats.avgElevated
        ? BpCategoryStyle.colorOf(BpCategory.grade1)
        : BpCategoryStyle.colorOf(BpCategory.normal);

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            '${stats.avgSystolic.toStringAsFixed(0)}/${stats.avgDiastolic.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 62,
          child: Text(
            l10n.analysisOnTargetShort(stats.onTargetCount, stats.count),
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
