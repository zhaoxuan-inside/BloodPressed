import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/sync/data/local_only_sync_service.dart';

/// 云同步页（增值服务占位：能力已预留，平台待接入）。
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sync = ref.watch(syncServiceProvider);
    final outboxCount = ref.watch(outboxCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('云同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sync.enabled
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: sync.enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        sync.enabled ? '已开启' : '未开启',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Switch(
                        value: sync.enabled,
                        onChanged: null, // 云平台接入前不可开启
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sync.enabled
                        ? '数据将自动同步到云端。'
                        : '云同步是增值服务，当前版本尚未接入云平台。你的所有数据仍完整保存在本机，'
                            '可通过"导出与分享"随时备份 CSV。',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('同步能力准备情况'),
          Card(
            child: Column(
              children: [
                _ReadyTile('本机数据保护（软删除 + updated_at 时间戳）', true),
                _ReadyTile('跨设备唯一标识（UUID 主键 + 设备ID）', true),
                _ReadyTile('离线变更日志（Outbox，待同步 $outboxCount 条）', true),
                _ReadyTile('云平台接入（候选：Supabase / 自建 API 等）', false),
                _ReadyTile('端到端加密传输', false),
              ],
            ),
          ),
          const SectionHeader('账号（预留）'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('未登录'),
              subtitle: const Text('云平台接入后可在此登录账号'),
              enabled: false,
              trailing: const Icon(Icons.lock_outline, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '说明：确定云平台后，只需实现 SyncService 接口并替换默认实现，'
            '本地数据模型与界面无需改动即可获得多设备同步能力。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Outbox 待同步条数。
final outboxCountProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(outboxDaoProvider);
  return dao.count();
});

class _ReadyTile extends StatelessWidget {
  const _ReadyTile(this.label, this.ready);

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        ready ? Icons.check_circle : Icons.radio_button_unchecked,
        color: ready ? Colors.green : Theme.of(context).colorScheme.outline,
        size: 20,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
