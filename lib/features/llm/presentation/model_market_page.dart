import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/data/modelscope_client.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';

/// 魔搭社区模型市场：精选模型 + 自定义仓库 ID + GGUF 文件下载。
class ModelMarketPage extends ConsumerStatefulWidget {
  const ModelMarketPage({super.key});

  @override
  ConsumerState<ModelMarketPage> createState() => _ModelMarketPageState();
}

class _ModelMarketPageState extends ConsumerState<ModelMarketPage> {
  final TextEditingController _customCtrl = TextEditingController();
  String? _openRepoId;
  String? _customRepoId;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloader = ref.watch(modelDownloaderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('魔搭模型市场')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              '从魔搭社区（ModelScope）下载 GGUF 模型到手机，离线运行。'
              '建议选择 0.6B~2B 的 Q4 量化版本，兼顾效果与内存。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.5),
            ),
          ),
          if (downloader.tasks.isNotEmpty) ...[
            const SectionHeader('下载任务'),
            ...downloader.tasks.map(_DownloadTile.new),
          ],
          const SectionHeader('精选模型（Qwen 官方）'),
          ...ModelScopeClient.curated.map((m) => _RepoCard(
                repoId: m.repoId,
                title: m.title,
                subtitle: '${m.repoId} · ${m.sizeHint}',
                desc: m.desc,
                expanded: _openRepoId == m.repoId,
                onToggle: () => setState(() {
                  _openRepoId = _openRepoId == m.repoId ? null : m.repoId;
                }),
              )),
          const SectionHeader('其他仓库'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCtrl,
                    decoration: const InputDecoration(
                      hintText: '输入模型ID，如 Qwen/Qwen3-1.7B-GGUF',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _openCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _openCustom,
                  child: const Text('查看'),
                ),
              ],
            ),
          ),
          if (_customRepoId != null) ...[
            const SizedBox(height: 8),
            _RepoCard(
              // 换一个模型ID时按新ID重建卡片状态，避免残留上一个仓库的列表
              key: ValueKey(_customRepoId),
              repoId: _customRepoId!,
              title: _customRepoId!,
              subtitle: '自定义仓库',
              desc: '从魔搭拉取该仓库的 GGUF 文件列表',
              expanded: _openRepoId == _customRepoId,
              onToggle: () => setState(() {
                _openRepoId = _openRepoId == _customRepoId ? null : _customRepoId;
              }),
            ),
          ],
        ],
      ),
    );
  }

  void _openCustom() {
    final id = _customCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _customRepoId = id;
      _openRepoId = id;
    });
  }
}

/// 仓库卡片：展开后拉取文件列表；失败时给出可读错误与重试入口。
class _RepoCard extends ConsumerStatefulWidget {
  const _RepoCard({
    super.key,
    required this.repoId,
    required this.title,
    required this.subtitle,
    required this.desc,
    required this.expanded,
    required this.onToggle,
  });

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
  Future<List<ModelScopeFile>>? _filesFuture;

  @override
  void initState() {
    super.initState();
    // 自定义仓库卡片创建时即处于展开态，需在首帧前就发起拉取
    if (widget.expanded) {
      _filesFuture = ref
          .read(modelscopeClientProvider)
          .listGgufFiles(widget.repoId);
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
      _filesFuture =
          ref.read(modelscopeClientProvider).listGgufFiles(widget.repoId);
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
                FutureBuilder<List<ModelScopeFile>>(
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
                    final files = snap.data ?? [];
                    if (files.isEmpty) {
                      return Text('该仓库没有可用的 GGUF 权重文件',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline));
                    }
                    return Column(
                      children: files.map((f) => _FileTile(
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
    if (error is DioException) {
      final cause = error.error;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          cause is SocketException) {
        return '无法连接魔搭服务器，请检查网络后重试';
      }
    }
    return '获取文件列表失败：$error';
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
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// 单个 GGUF 文件行：显示大小与下载状态。
class _FileTile extends ConsumerWidget {
  const _FileTile({required this.repoId, required this.file});

  final String repoId;
  final ModelScopeFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloader = ref.watch(modelDownloaderProvider);
    final key = '$repoId/${file.path}';
    final task = downloader.task(key);

    Widget trailing;
    if (task == null) {
      trailing = IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: '下载',
        onPressed: () {
          ref
              .read(modelDownloaderProvider.notifier)
              .start(repoId, file);
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
                    .start(repoId, file);
              },
            ),
          ]);
        case DownloadStatus.completed:
          trailing = const Icon(Icons.check_circle,
              color: Colors.green, size: 20);
        case DownloadStatus.failed:
          trailing = IconButton(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 20),
            tooltip: task.error ?? '失败',
            onPressed: () {
              ref
                  .read(modelDownloaderProvider.notifier)
                  .start(repoId, file);
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
