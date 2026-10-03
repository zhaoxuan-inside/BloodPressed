import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
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
    final profilesAsync = ref.watch(llmProfilesProvider);
    final activeId = ref.watch(activeLlmProfileIdProvider);
    final engineState = ref.watch(llmEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 模型')),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner('配置加载失败：$e'),
        data: (profiles) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  '配置本地或远端大模型后，可以使用健康指导、AI 识别血压照片等智能功能。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              if (engineState.error != null)
                ErrorBanner(engineState.error!),
              if (profiles.isEmpty)
                const EmptyState(
                  icon: Icons.smart_toy_outlined,
                  title: '尚未配置任何模型',
                  subtitle: '从魔搭社区下载一个本地模型（离线可用），\n或配置一个远端 API（能力更强）。',
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
                      label: const Text('从魔搭社区安装模型'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ModelMarketPage()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.dns_outlined),
                      label: const Text('添加远端模型 API'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RemoteProfileEditPage()),
                      ),
                    ),
                    if (_hasDownloadedFiles())
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('从已下载文件添加'),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已启用「${p.name}」')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _delete(LlmProfile p) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除模型配置',
      content: '删除「${p.name}」？'
          '${p.kind == LlmKind.local ? '\n模型文件不会被删除，可稍后重新添加。' : ''}',
      danger: true,
      confirmText: '删除',
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
          const SnackBar(content: Text('没有找到已下载的 .gguf 模型文件')));
      return;
    }
    final picked = await showDialog<File>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择模型文件'),
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
    final isLocal = profile.kind == LlmKind.local;
    final subtitle = isLocal
        ? '本地模型 · ${profile.modelPath.split(Platform.pathSeparator).last}'
        : '远端 API · ${profile.remoteModel}'
            '${profile.multimodal ? ' · 支持图片' : ''}';

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
                  engineBusy ? '加载中' : '使用中',
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
              const PopupMenuItem(value: 'activate', child: Text('启用')),
            if (onEdit != null)
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: active ? null : onActivate,
      ),
    );
  }
}
