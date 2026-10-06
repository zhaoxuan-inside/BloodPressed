import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'package:blood_pressed/features/export/data/csv_exporter.dart';
import 'package:blood_pressed/features/export/data/wechat_share_service.dart';
import 'share_card_widgets.dart';

enum _CardType { record, stats }

/// 数据导出与分享页。
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  final GlobalKey _cardKey = GlobalKey();
  _CardType _cardType = _CardType.record;
  int _statsDays = 30;
  bool _busy = false;

  ShareService? _shareService;

  ShareService get shareService {
    final settings = ref.read(appSettingsProvider);
    return _shareService ??= ShareService(
      wechatAppId: settings.wechatAppId,
      universalLink: settings.wechatUniversalLink,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = ref.watch(latestRecordProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('导出与分享')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader('卡片分享'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_CardType>(
              segments: const [
                ButtonSegment(
                    value: _CardType.record, label: Text('单次记录卡')),
                ButtonSegment(
                    value: _CardType.stats, label: Text('统计摘要卡')),
              ],
              selected: {_cardType},
              onSelectionChanged: (s) =>
                  setState(() => _cardType = s.first),
            ),
          ),
          if (_cardType == _CardType.stats)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: kStatsRanges
                    .take(3)
                    .map((r) => ChoiceChip(
                          label: Text(r.label),
                          selected: _statsDays == r.days,
                          onSelected: (_) =>
                              setState(() => _statsDays = r.days),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: _buildCard(latest),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('微信好友'),
                        onPressed: latest == null && _cardType == _CardType.record
                            ? null
                            : () => _shareCard(toTimeline: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.public, size: 18),
                        label: const Text('朋友圈'),
                        onPressed: latest == null && _cardType == _CardType.record
                            ? null
                            : () => _shareCard(toTimeline: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('更多方式分享'),
                  onPressed: latest == null && _cardType == _CardType.record
                      ? null
                      : () => _shareCard(system: true),
                ),
              ],
            ),
          ),
          const SectionHeader('数据导出'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_view, size: 18),
                  label: const Text('导出全部记录为 CSV（Excel 可打开）'),
                  onPressed: _exportCsv,
                ),
                const SizedBox(height: 8),
                Text(
                  'CSV 包含：时间、高压、低压、脉搏、测量臂、体位、备注、来源。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BpRecord? latest) {
    if (_cardType == _CardType.record) {
      if (latest == null) {
        return const EmptyState(
          icon: Icons.image_not_supported_outlined,
          title: '暂无记录',
          subtitle: '先添加一条血压记录再分享卡片',
        );
      }
      return RecordShareCard(record: latest);
    }
    return FutureBuilder<BpStats>(
      future: ref
          .read(recordsRepositoryProvider)
          .stats(from: DateTime.now().subtract(Duration(days: _statsDays))),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return StatsShareCard(stats: snap.data!, days: _statsDays);
      },
    );
  }

  Future<void> _shareCard({bool system = false, bool toTimeline = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await CardCapturer.capture(_cardKey);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/blood_pressed_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);

      final service = shareService;
      String result;
      if (system) {
        result = await service.shareFile(
          file,
          text: '我的血压记录（来自血压了么）',
        );
      } else {
        result = await service.shareImage(
          file,
          text: '我的血压记录（来自血压了么）',
          toTimeline: toTimeline,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('分享失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(recordsRepositoryProvider);
      final records = await repo.list();
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('暂无记录可导出')));
        }
        return;
      }
      final file = await const CsvExporter().exportToFile(records);
      final result = await shareService.shareFile(
        file,
        text: '血压了么 血压记录导出',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
