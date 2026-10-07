import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/widgets/quick_action.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/camera_ocr/presentation/ocr_flow.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'record_edit_page.dart';
import 'widgets/record_tile.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 首页：概览 + 快捷录入 + 记录列表。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordsControllerProvider);
    final today = ref.watch(todayRecordsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(l10n.loadDataFailed(e.toString())),
        data: (records) {
          final theme = Theme.of(context);
          final latest = records.isEmpty ? null : records.first;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _LatestCard(record: latest, todayCount: today.length),
              SectionHeader(l10n.sectionEntry),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: QuickAction(
                        icon: Icons.edit_note,
                        label: l10n.actionManual,
                        onTap: () => _openEdit(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.photo_camera_outlined,
                        label: l10n.actionCamera,
                        onTap: () => startCameraOcrFlow(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.photo_outlined,
                        label: l10n.actionGallery,
                        onTap: () => startGalleryOcrFlow(context),
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeader(l10n.sectionHistory),
              if (records.isEmpty)
                EmptyState(
                  icon: Icons.monitor_heart_outlined,
                  title: l10n.emptyHomeTitle,
                  subtitle: l10n.emptyHomeSubtitle,
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(l10n.historyHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline)),
                ),
                ..._groupedRecords(context, ref, records),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showEntrySheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _groupedRecords(
      BuildContext context, WidgetRef ref, List<BpRecord> records) {
    final widgets = <Widget>[];
    String? lastDay;
    for (final r in records) {
      final day = Fmt.friendlyDay(r.measuredAt);
      if (day != lastDay) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
          child: Text(day,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
        ));
        lastDay = day;
      }
      widgets.add(RecordTile(
        record: r,
        onTap: () => _openEdit(context, existing: r),
        onDelete: () => _delete(context, ref, r),
      ));
    }
    return widgets;
  }

  void _openEdit(BuildContext context, {BpRecord? existing}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecordEditPage(existing: existing),
      fullscreenDialog: true,
    ));
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, BpRecord r) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteRecordTitle,
      content: l10n.deleteRecordContent(
          Fmt.full(r.measuredAt), r.systolic, r.diastolic),
      confirmText: l10n.delete,
      danger: true,
    );
    if (confirmed) {
      await ref.read(recordsControllerProvider.notifier).delete(r.id);
    } else {
      ref.read(recordsControllerProvider.notifier).refresh();
    }
  }
}

/// 录入方式选择（FAB）。
void showEntrySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l10n.actionManual),
            subtitle: Text(l10n.sheetManualSubtitle),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RecordEditPage(),
                fullscreenDialog: true,
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.actionCamera),
            subtitle: Text(l10n.sheetCameraSubtitle),
            onTap: () {
              Navigator.of(ctx).pop();
              startCameraOcrFlow(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_outlined),
            title: Text(l10n.sheetGalleryTitle),
            subtitle: Text(l10n.sheetGallerySubtitle),
            onTap: () {
              Navigator.of(ctx).pop();
              startGalleryOcrFlow(context);
            },
          ),
        ],
      ),
      );
    },
  );
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.record, required this.todayCount});

  final BpRecord? record;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (record == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(l10n.welcomeTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(l10n.welcomeSubtitle),
            ],
          ),
        ),
      );
    }
    final r = record!;
    final category = BpCategory.fromValues(r.systolic, r.diastolic);
    final color = BpCategoryStyle.colorOf(category);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/stats'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.latestMeasurement,
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.outline)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      categoryLabel(l10n, category),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 窄屏（360dp）下大号数值 + 脉搏可能超宽，整体缩放避免溢出
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${r.systolic}',
                        style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800, color: color)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('/',
                          style: theme.textTheme.displaySmall?.copyWith(
                              color: theme.colorScheme.outline)),
                    ),
                    Text('${r.diastolic}',
                        style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('mmHg',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline)),
                    ),
                    const SizedBox(width: 12),
                    if (r.pulse != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.favorite,
                                size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text('${r.pulse} ${l10n.pulseUnit}',
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${Fmt.friendlyDay(r.measuredAt)} ${Fmt.time(r.measuredAt)} · ${armLabel(l10n, r.arm)}'
                '${todayCount > 1 ? ' · ${l10n.todayMeasuredTimes(todayCount)}' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Text(categoryAdvice(l10n, category),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

}

