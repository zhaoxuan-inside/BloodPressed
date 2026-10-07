import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/sync/data/local_only_sync_service.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 云同步页（增值服务占位：能力已预留，平台待接入）。
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sync = ref.watch(syncServiceProvider);
    final outboxCount = ref.watch(outboxCountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
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
                        sync.enabled ? l10n.syncOn : l10n.syncOff,
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
                        ? l10n.syncEnabledBody
                        : l10n.syncDisabledBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(l10n.syncReadiness),
          Card(
            child: Column(
              children: [
                _ReadyTile(l10n.readyLocal, true),
                _ReadyTile(l10n.readyDeviceId, true),
                _ReadyTile(
                    l10n.readyOutbox(outboxCount.valueOrNull ?? 0), true),
                _ReadyTile(l10n.readyPlatform, false),
                _ReadyTile(l10n.readyE2E, false),
              ],
            ),
          ),
          SectionHeader(l10n.sectionAccount),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(l10n.notLoggedIn),
              subtitle: Text(l10n.loginAfterPlatform),
              enabled: false,
              trailing: const Icon(Icons.lock_outline, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.syncNote,
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
