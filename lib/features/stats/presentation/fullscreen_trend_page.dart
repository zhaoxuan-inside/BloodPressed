import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/features/stats/presentation/stats_share.dart';
import 'package:blood_pressed/features/stats/presentation/widgets/trend_chart.dart';
import 'controllers/trend_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

enum _Series { bp, pulse }

/// 全屏横屏图表页：进入强制横屏、图表铺满可用区，返回恢复竖屏。
///
/// 小屏（及终端式窄屏）上看清折线的专用视图；查询参数由趋势页经
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
                        : IconButton(
                            tooltip: l10n.shareMore,
                            icon: const Icon(Icons.ios_share, size: 20),
                            onPressed: () {
                              final avgSys = points
                                      .map((p) => p.avgSystolic)
                                      .reduce((a, b) => a + b) /
                                  points.length;
                              final avgDia = points
                                      .map((p) => p.avgDiastolic)
                                      .reduce((a, b) => a + b) /
                                  points.length;
                              final count = points
                                  .fold<int>(0, (s, p) => s + p.count);
                              shareTrendChart(context, ref,
                                  points: points,
                                  query: widget.query,
                                  title: l10n.statsTitle,
                                  avgSystolic: avgSys,
                                  avgDiastolic: avgDia,
                                  count: count);
                            },
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  SegmentedButton<_Series>(
                    segments: [
                      ButtonSegment(
                          value: _Series.bp, label: Text(l10n.seriesBp)),
                      ButtonSegment(
                          value: _Series.pulse, label: Text(l10n.seriesPulse)),
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
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) =>
                      Center(child: Text(l10n.trendLoadFailed('$e'))),
                  data: (points) {
                    if (points.isEmpty) {
                      return Center(
                        child: Text(l10n.statsEmptyTitle),
                      );
                    }
                    return _series == _Series.bp
                        ? TrendLineChart(points: points, query: widget.query)
                        : PulseLineChart(points: points, query: widget.query);
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
