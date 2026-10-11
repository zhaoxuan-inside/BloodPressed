import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';
import 'package:blood_pressed/features/llm/data/model_community.dart';
import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/data/modelscope_client.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';

/// 模型中心：搜索 / 下载 / 安装（下载完成自动建档）/ 推理（激活档案）。
///
/// 同时接入多个模型社区——搜索并行合并去重，自定义仓库 ID 双源查找，
/// 「能搜到哪个就用哪个」；UI 不暴露社区品牌。
class ModelCenterPage extends ConsumerStatefulWidget {
  const ModelCenterPage({super.key});

  @override
  ConsumerState<ModelCenterPage> createState() => _ModelCenterPageState();
}

class _ModelCenterPageState extends ConsumerState<ModelCenterPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customCtrl = TextEditingController();
  List<RepoSummary>? _searchResults;
  bool _searching = false;
  String? _openRepoKey;
  String? _customRepoId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty || _searching) return;
    setState(() => _searching = true);
    List<RepoSummary> results = const [];
    try {
      results = await ref.read(modelCenterServiceProvider).searchAll(q);
    } catch (_) {
      // 双社区均失败：空结果 + 提示
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResults = results;
      if (results.isNotEmpty) _openRepoKey = null;
    });
  }

  void _openCustom() {
    final id = _customCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _customRepoId = id;
      _openRepoKey = 'anywhere:$id';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final downloader = ref.watch(modelDownloaderProvider);
    final scopeCommunityId = ref.watch(modelscopeClientProvider).id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.marketTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              l10n.marketIntro,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.5),
            ),
          ),
          // —— 搜索 ——
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('modelSearchField'),
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.marketSearchHint,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: Text(l10n.searchTitle),
                ),
              ],
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_searchResults != null) ...[
            SectionHeader(l10n.marketSearchResults),
            if (_searchResults!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(l10n.marketNoResults,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              )
            else
              ..._searchResults!.take(10).map((r) => _RepoCard(
                    key: ValueKey('${r.communityId}:${r.repoId}'),
                    communityId: r.communityId,
                    repoId: r.repoId,
                    title: r.repoId,
                    subtitle:
                        '${r.downloads} ↓ · ${r.repoId.split('/').first}',
                    expanded: _openRepoKey == '${r.communityId}:${r.repoId}',
                    onToggle: () => setState(() {
                      final key = '${r.communityId}:${r.repoId}';
                      _openRepoKey = _openRepoKey == key ? null : key;
                    }),
                  )),
          ],
          if (downloader.tasks.isNotEmpty) ...[
            SectionHeader(l10n.sectionDownloads),
            ...downloader.tasks.map(_DownloadTile.new),
          ],
          SectionHeader(l10n.sectionCurated),
          ...ModelScopeClient.curated.map((m) => _RepoCard(
                key: ValueKey(m.repoId),
                communityId: scopeCommunityId,
                repoId: m.repoId,
                title: m.title,
                subtitle: '${m.repoId} · ${_sizeLabel(l10n, m)}',
                desc: _descLabel(l10n, m),
                expanded: _openRepoKey == m.repoId,
                onToggle: () => setState(() {
                  _openRepoKey = _openRepoKey == m.repoId ? null : m.repoId;
                }),
              )),
          SectionHeader(l10n.sectionOtherRepos),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('customRepoField'),
                    controller: _customCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.customRepoHint,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _openCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _openCustom,
                  child: Text(l10n.viewBtn),
                ),
              ],
            ),
          ),
          if (_customRepoId != null) ...[
            const SizedBox(height: 8),
            _RepoCard(
              // 双源查找卡：展开时 listGgufAnywhere 自动选首个可用社区
              key: ValueKey('anywhere:$_customRepoId'),
              communityId: null,
              repoId: _customRepoId!,
              title: _customRepoId!,
              subtitle: l10n.customRepo,
              desc: l10n.customRepoDesc,
              expanded: _openRepoKey == 'anywhere:$_customRepoId',
              onToggle: () => setState(() {
                _openRepoKey = _openRepoKey == 'anywhere:$_customRepoId'
                    ? null
                    : 'anywhere:$_customRepoId';
              }),
            ),
          ],
        ],
      ),
    );
  }

  static String _sizeLabel(AppLocalizations l10n, CuratedModel m) {
    if (AppLocaleService.isEn) {
      return switch (m.repoId) {
        'Qwen/Qwen3-0.6B-GGUF' => l10n.curatedSizeQwen3_0_6B_GGUF,
        'Qwen/Qwen3-1.7B-GGUF' => l10n.curatedSizeQwen3_1_7B_GGUF,
        'Qwen/Qwen3-4B-GGUF' => l10n.curatedSizeQwen3_4B_GGUF,
        'Qwen/Qwen2_5-0_5B-Instruct-GGUF' => l10n.curatedSizeQwen2_5_0_5B_Instruct_GGUF,
        'Qwen/Qwen2_5-1_5B-Instruct-GGUF' => l10n.curatedSizeQwen2_5_1_5B_Instruct_GGUF,
        'Qwen/Qwen2_5-3B-Instruct-GGUF' => l10n.curatedSizeQwen2_5_3B_Instruct_GGUF,
        _ => m.sizeHint,
      };
    }
    return m.sizeHint;
  }

  static String _descLabel(AppLocalizations l10n, CuratedModel m) {
    if (AppLocaleService.isEn) {
      return switch (m.repoId) {
        'Qwen/Qwen3-0.6B-GGUF' => l10n.curatedDescQwen3_0_6B_GGUF,
        'Qwen/Qwen3-1.7B-GGUF' => l10n.curatedDescQwen3_1_7B_GGUF,
        'Qwen/Qwen3-4B-GGUF' => l10n.curatedDescQwen3_4B_GGUF,
        'Qwen/Qwen2_5-0_5B-Instruct-GGUF' => l10n.curatedDescQwen2_5_0_5B_Instruct_GGUF,
        'Qwen/Qwen2_5-1_5B-Instruct-GGUF' => l10n.curatedDescQwen2_5_1_5B_Instruct_GGUF,
        'Qwen/Qwen2_5-3B-Instruct-GGUF' => l10n.curatedDescQwen2_5_3B_Instruct_GGUF,
        _ => m.desc,
      };
    }
    return m.desc;
  }
}

/// 仓库卡片：[communityId] 为 null 表示双源自动查找；展开后拉取文件列表。
class _RepoCard extends ConsumerStatefulWidget {
  const _RepoCard({
    super.key,
    required this.communityId,
    required this.repoId,
    required this.title,
    required this.subtitle,
    this.desc = '',
    required this.expanded,
    required this.onToggle,
  });

  final String? communityId;
  final String repoId;
  final String title;
  final String subtitle;
  final String desc;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  ConsumerState<_RepoCard> createState() => _RepoCardState();
}

class _RepoCardState extends ConsumerState<_RepoCard> {
  Future<({String communityId, List<ModelFileInfo> files})>? _filesFuture;

  @override
  void initState() {
    super.initState();
    // 卡片创建时即处于展开态（搜索结果/自定义仓库），需在首帧前就发起拉取
    if (widget.expanded) {
      _loadFiles();
    }
  }

  @override
  void didUpdateWidget(_RepoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded && _filesFuture == null) {
      _loadFiles();
    }
  }

  void _loadFiles() {
    setState(() {
      final service = ref.read(modelCenterServiceProvider);
      final communityId = widget.communityId;
      if (communityId != null) {
        _filesFuture = service
            .community(communityId)!
            .listGgufFiles(widget.repoId)
            .then((files) => (communityId: communityId, files: files));
      } else {
        // 双源查找：能搜到哪个社区就用哪个
        _filesFuture = service.listGgufAnywhere(widget.repoId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(widget.subtitle,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                  Icon(widget.expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                ],
              ),
              if (widget.expanded) ...[
                const SizedBox(height: 4),
                Text(widget.desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline)),
                const SizedBox(height: 8),
                FutureBuilder<({String communityId, List<ModelFileInfo> files})>(
                  key: ValueKey(_filesFuture),
                  future: _filesFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))),
                      );
                    }
                    if (snap.hasError) {
                      return _FileListError(
                        message: _describeError(snap.error!),
                        onRetry: _loadFiles,
                      );
                    }
                    final hit = snap.data;
                    final files = hit?.files ?? [];
                    if (files.isEmpty) {
                      return Text(AppLocalizations.of(context).noGgufFiles,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline));
                    }
                    return Column(
                      children: files.map((f) => _FileTile(
                            communityId: hit!.communityId,
                            repoId: widget.repoId,
                            file: f,
                          )).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _describeError(Object error) {
    if (error is InferenceException) return error.message;
    if (error is StateError) {
      return AppLocaleService.auto.marketNoResults;
    }
    if (error is DioException) {
      final cause = error.error;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          cause is SocketException) {
        return AppLocaleService.auto.marketConnError;
      }
    }
    return AppLocaleService.auto.listFilesFailed(error.toString());
  }
}

/// 文件列表加载失败占位：可读错误 + 重试按钮。
class _FileListError extends StatelessWidget {
  const _FileListError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry)),
        ],
      ),
    );
  }
}

/// 单个 GGUF 文件行：显示大小与下载状态。
class _FileTile extends ConsumerWidget {
  const _FileTile({
    required this.communityId,
    required this.repoId,
    required this.file,
  });

  final String communityId;
  final String repoId;
  final ModelFileInfo file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloader = ref.watch(modelDownloaderProvider);
    final key = '$communityId:$repoId/${file.path}';
    final task = downloader.task(key);

    Widget trailing;
    if (task == null) {
      trailing = IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: AppLocalizations.of(context).downloadTooltip,
        onPressed: () {
          ref
              .read(modelDownloaderProvider.notifier)
              .start(communityId, repoId, file);
        },
      );
    } else {
      switch (task.status) {
        case DownloadStatus.running:
          trailing = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    value: task.progress, strokeWidth: 2.4),
              ),
              IconButton(
                icon: const Icon(Icons.pause_circle_outline, size: 20),
                onPressed: () =>
                    ref.read(modelDownloaderProvider.notifier).pause(key),
              ),
            ],
          );
        case DownloadStatus.paused:
          trailing = Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${(task.progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall),
            IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 20),
              onPressed: () {
                ref
                    .read(modelDownloaderProvider.notifier)
                    .start(communityId, repoId, file);
              },
            ),
          ]);
        case DownloadStatus.completed:
          trailing = const Icon(Icons.check_circle,
              color: Colors.green, size: 20);
        case DownloadStatus.failed:
          trailing = IconButton(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 20),
            tooltip: task.error ?? AppLocalizations.of(context).failedTooltip,
            onPressed: () {
              ref
                  .read(modelDownloaderProvider.notifier)
                  .start(communityId, repoId, file);
            },
          );
        case DownloadStatus.queued:
          trailing = const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2));
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        file.fileName,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(Fmt.bytes(file.size),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline)),
      trailing: trailing,
    );
  }
}

/// 顶部下载任务进度条。
class _DownloadTile extends StatelessWidget {
  const _DownloadTile(this.task);

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.fileName,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${Fmt.bytes(task.receivedBytes)} / ${Fmt.bytes(task.totalBytes)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: task.status == DownloadStatus.completed
                ? 1
                : task.progress,
          ),
          if (task.error != null)
            Text(task.error!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}
