import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'model_market_page.dart';
import 'remote_profile_edit_page.dart';

/// AI 模型配置页：本地模型（魔搭下载）+ 远端 API 统一管理。
class LlmSettingsPage extends ConsumerStatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  ConsumerState<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends ConsumerState<LlmSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final profilesAsync = ref.watch(llmProfilesProvider);
    final activeId = ref.watch(activeLlmProfileIdProvider);
    final engineState = ref.watch(llmEngineProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.llmTitle)),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(l10n.llmLoadFailed(e.toString())),
        data: (profiles) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  l10n.llmIntro,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              if (engineState.error != null)
                ErrorBanner(engineState.error!),
              if (profiles.isEmpty)
                EmptyState(
                  icon: Icons.smart_toy_outlined,
                  title: l10n.llmEmptyTitle,
                  subtitle: l10n.llmEmptySubtitle,
                )
              else
                ...profiles.map((p) => _ProfileCard(
                      profile: p,
                      active: p.id == activeId,
                      engineBusy: engineState.status == LlmEngineStatus.loading,
                      onActivate: () => _activate(p),
                      onDelete: () => _delete(p),
                      onEdit: p.kind == LlmKind.remote ? () => _edit(p) : null,
                    )),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(l10n.llmInstallFromMarket),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ModelMarketPage()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.dns_outlined),
                      label: Text(l10n.llmAddRemote),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RemoteProfileEditPage()),
                      ),
                    ),
                    if (_hasDownloadedFiles())
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.llmAddFromFile),
                        onPressed: _addFromFile,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasDownloadedFiles() {
    // 同步探测不可靠，这里交给异步对话框内扫描；按钮常显
    return true;
  }

  Future<void> _activate(LlmProfile p) async {
    final err = await ref.read(llmEngineProvider.notifier).activate(p);
    if (!mounted) return;
    if (err == null) {
      await ref.read(appSettingsProvider).setActiveLlmProfile(p.id);
      if (!mounted) return;
      ref.read(activeLlmProfileIdProvider.notifier).state = p.id;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.activatedProfile(p.name))));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _delete(LlmProfile p) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteProfileTitle,
      content: l10n.deleteProfileContent(
          p.name,
          p.kind == LlmKind.local ? l10n.deleteProfileKeepFile : ''),
      danger: true,
      confirmText: l10n.menuDelete,
    );
    if (!ok) return;
    final activeId = ref.read(activeLlmProfileIdProvider);
    if (activeId == p.id) {
      await ref.read(llmEngineProvider.notifier).deactivate();
      await ref.read(appSettingsProvider).setActiveLlmProfile(null);
      ref.read(activeLlmProfileIdProvider.notifier).state = null;
    }
    await ref.read(llmProfilesProvider.notifier).delete(p.id);
  }

  Future<void> _edit(LlmProfile p) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteProfileEditPage(existing: p),
    ));
  }

  Future<void> _addFromFile() async {
    final files = await _scanModelFiles();
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).noModelFiles)));
      return;
    }
    final picked = await showDialog<File>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx).pickModelFileTitle),
        children: files
            .map((f) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(f),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.uri.pathSegments.last),
                    subtitle: Text(
                        '${(f.lengthSync() / 1024 / 1024 / 1024).toStringAsFixed(2)} GB'),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(llmProfilesProvider.notifier).addLocalModel(
          name: picked.uri.pathSegments.last.replaceAll('.gguf', ''),
          modelPath: picked.path,
        );
  }

  Future<List<File>> _scanModelFiles() async {
    final docs = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${docs.path}/models');
    if (!modelsDir.existsSync()) return [];
    final out = <File>[];
    await for (final sub in modelsDir.list(recursive: true)) {
      if (sub is File && sub.path.toLowerCase().endsWith('.gguf')) {
        out.add(sub);
      }
    }
    return out;
  }
}

/// 单个模型配置卡片。
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.active,
    required this.engineBusy,
    required this.onActivate,
    required this.onDelete,
    this.onEdit,
  });

  final LlmProfile profile;
  final bool active;
  final bool engineBusy;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLocal = profile.kind == LlmKind.local;
    final subtitle = isLocal
        ? l10n.profileLocalSubtitle(
            profile.modelPath.split(Platform.pathSeparator).last)
        : l10n.profileRemoteSubtitle(profile.remoteModel,
            profile.multimodal ? l10n.profileMultimodalSuffix : '');

    return Card(
      child: ListTile(
        leading: Icon(
          isLocal ? Icons.memory : Icons.dns_outlined,
          color: active ? theme.colorScheme.primary : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                profile.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  engineBusy ? l10n.engineLoading : l10n.engineActive,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'activate':
                onActivate();
              case 'edit':
                onEdit?.call();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (ctx) => [
            if (!active)
              PopupMenuItem(
                  value: 'activate',
                  child: Text(AppLocalizations.of(ctx).menuActivate)),
            if (onEdit != null)
              PopupMenuItem(
                  value: 'edit',
                  child: Text(AppLocalizations.of(ctx).menuEdit)),
            PopupMenuItem(
                value: 'delete',
                child: Text(AppLocalizations.of(ctx).menuDelete)),
          ],
        ),
        onTap: active ? null : onActivate,
      ),
    );
  }
}
