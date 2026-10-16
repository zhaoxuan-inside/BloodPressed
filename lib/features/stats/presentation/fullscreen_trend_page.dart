import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/features/stats/presentation/analysis_text.dart';
import 'package:blood_pressed/features/stats/presentation/stats_share.dart';
import 'package:blood_pressed/features/stats/presentation/widgets/trend_chart.dart';

import 'controllers/trend_providers.dart';

import 'package:blood_pressed/l10n/app_localizations.dart';

enum _Series { bp, pulse }

/// 全屏横屏图表页：进入强制横屏、图表铺满可用区，返回恢复竖屏。
///
/// 小屏（及终端式窄屏）上看清蜡烛图的专用视图；查询参数由趋势页经
/// go_router extra 传入。
class FullscreenTrendPage extends ConsumerStatefulWidget {
  const FullscreenTrendPage({super.key, required this.query});

  final TrendQuery query;

  @override
  ConsumerState<FullscreenTrendPage> createState() =>
      _FullscreenTrendPageState();
}

class _FullscreenTrendPageState extends ConsumerState<FullscreenTrendPage> {
  _Series _series = _Series.bp;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  /// AI 分析：先 pop 本页（dispose 恢复竖屏），再进入助手页对话流。
  Future<void> _aiAnalyze(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final analysis = await ref.read(analysisDataProvider(widget.query).future);
    if (analysis.isEmpty || !context.mounted) return;
    final ok = await guardAndSendAnalysis(
      context,
      ref,
      prompt: l10n.aiAnalysisPrompt(
        trendRangeLabel(widget.query, l10n),
        analysisSummaryZh(analysis),
      ),
    );
    if (!ok || !context.mounted) return;
    context.pop(); // 全屏页 dispose → 恢复竖屏
    context.push('/assistant');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trend = ref.watch(trendDataProvider(widget.query));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部控制条：返回 + 分享 + 系列切换
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
              child: Row(
                children: [
                  BackButton(onPressed: () => context.pop()),
                  const Spacer(),
                  trend.maybeWhen(
                    data: (points) => points.isEmpty
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.statsAiAnalyze,
                                icon: const Icon(Icons.auto_awesome, size: 20),
                                onPressed: () => _aiAnalyze(context),
                              ),
                              IconButton(
                                tooltip: l10n.shareMore,
                                icon: const Icon(Icons.ios_share, size: 20),
                                onPressed: () {
                                  shareTrendChart(
                                    context,
                                    ref,
                                    pulse: _series == _Series.pulse,
                                    points: points,
                                    query: widget.query,
                                    title: l10n.statsTitle,
                                  );
                                },
                              ),
                            ],
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  SegmentedButton<_Series>(
                    segments: [
                      ButtonSegment(
                        value: _Series.bp,
                        label: Text(l10n.seriesBp),
                      ),
                      ButtonSegment(
                        value: _Series.pulse,
                        label: Text(l10n.seriesPulse),
                      ),
                    ],
                    selected: {_series},
                    onSelectionChanged: (s) =>
                        setState(() => _series = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            // 图表铺满余下空间
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 16, 8),
                child: trend.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) =>
                      Center(child: Text(l10n.trendLoadFailed('$e'))),
                  data: (points) {
                    if (points.isEmpty) {
                      return Center(child: Text(l10n.statsEmptyTitle));
                    }
                    return _series == _Series.bp
                        ? TrendCandleChart(points: points, query: widget.query)
                        : PulseCandleChart(points: points, query: widget.query);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
