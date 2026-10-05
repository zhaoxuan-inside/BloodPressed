import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/widgets/quick_action.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/camera_ocr/presentation/ocr_flow.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'record_edit_page.dart';
import 'widgets/record_tile.dart';

/// 首页：概览 + 快捷录入 + 记录列表。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordsControllerProvider);
    final today = ref.watch(todayRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BloodPressed',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner('数据加载失败：$e'),
        data: (records) {
          final theme = Theme.of(context);
          final latest = records.isEmpty ? null : records.first;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _LatestCard(record: latest, todayCount: today.length),
              const SectionHeader('录入血压'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: QuickAction(
                        icon: Icons.edit_note,
                        label: '手动录入',
                        onTap: () => _openEdit(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.photo_camera_outlined,
                        label: '拍照识别',
                        onTap: () => startCameraOcrFlow(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.photo_outlined,
                        label: '相册识别',
                        onTap: () => startGalleryOcrFlow(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader('历史记录'),
              if (records.isEmpty)
                const EmptyState(
                  icon: Icons.monitor_heart_outlined,
                  title: '还没有血压记录',
                  subtitle: '从上方"手动录入"开始，或直接拍照识别血压计读数',
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('左滑删除 · 点击编辑',
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
    final confirmed = await showConfirmDialog(
      context,
      title: '删除记录',
      content:
          '删除 ${Fmt.full(r.measuredAt)} 的记录（${r.systolic}/${r.diastolic}）？删除后不可恢复。',
      confirmText: '删除',
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
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('手动录入'),
            subtitle: const Text('直接输入高压/低压/脉搏'),
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
            title: const Text('拍照识别'),
            subtitle: const Text('拍摄血压计屏幕，自动识别读数'),
            onTap: () {
              Navigator.of(ctx).pop();
              startCameraOcrFlow(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_outlined),
            title: const Text('从相册选择'),
            subtitle: const Text('识别已有的血压计照片'),
            onTap: () {
              Navigator.of(ctx).pop();
              startGalleryOcrFlow(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.record, required this.todayCount});

  final BpRecord? record;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (record == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('👋 欢迎使用 BloodPressed',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text('记录第一次血压，开始你的健康之旅'),
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
                  Text('最近一次测量',
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
                      category.label,
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
                            Text('${r.pulse} 次/分',
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${Fmt.friendlyDay(r.measuredAt)} ${Fmt.time(r.measuredAt)} · ${r.arm.label}'
                '${todayCount > 1 ? ' · 今日已测 $todayCount 次' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Text(category.advice,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

}

