import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'package:blood_pressed/features/export/data/csv_exporter.dart';
import 'package:blood_pressed/features/export/data/wechat_share_service.dart';
import 'share_card_widgets.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final latest = ref.watch(latestRecordProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(l10n.sectionCardShare),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_CardType>(
              segments: [
                ButtonSegment(
                    value: _CardType.record, label: Text(l10n.cardTypeRecord)),
                ButtonSegment(
                    value: _CardType.stats, label: Text(l10n.cardTypeStats)),
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
                          label: Text(statsRangeLabel(l10n, r.days)),
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
                        label: Text(l10n.shareWechat),
                        onPressed: latest == null && _cardType == _CardType.record
                            ? null
                            : () => _shareCard(toTimeline: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.public, size: 18),
                        label: Text(l10n.shareMoments),
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
                  label: Text(l10n.shareMore),
                  onPressed: latest == null && _cardType == _CardType.record
                      ? null
                      : () => _shareCard(system: true),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.sectionDataExport),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_view, size: 18),
                  label: Text(l10n.exportCsvButton),
                  onPressed: _exportCsv,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.csvContentsHint,
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
        final l10n = AppLocalizations.of(context);
        return EmptyState(
          icon: Icons.image_not_supported_outlined,
          title: l10n.emptyExportTitle,
          subtitle: l10n.emptyExportSubtitle,
        );
      }
      return _stage(const Color(0xFF07211C), RecordShareCard(record: latest));
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
        return _stage(
            const Color(0xFF081E33), StatsShareCard(stats: snap.data!, days: _statsDays));
      },
    );
  }

  /// 深色方形底衬：卡片圆角外不再透出页面白底，
  /// 导出 PNG 为完整不透明矩形（预览与导出所见即所得）。
  Widget _stage(Color backdrop, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: backdrop,
      child: child,
    );
  }

  Future<void> _shareCard({bool system = false, bool toTimeline = false}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
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
          text: l10n.shareText,
        );
      } else {
        result = await service.shareImage(
          file,
          text: l10n.shareText,
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
            .showSnackBar(SnackBar(content: Text(l10n.shareFailed(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final repo = ref.read(recordsRepositoryProvider);
      final records = await repo.list();
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.exportEmpty)));
        }
        return;
      }
      final file = await const CsvExporter().exportToFile(records);
      final result = await shareService.shareFile(
        file,
        text: l10n.csvShareText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportFailed(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
