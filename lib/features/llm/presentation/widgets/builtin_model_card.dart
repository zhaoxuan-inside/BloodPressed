import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/data/modelscope_client.dart';
import 'package:blood_pressed/features/llm/domain/builtin_model.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 内置默认模型卡片：下载引导 / 下载进度 / 就绪态三态合一。
///
/// 「我的 → AI 模型」常驻展示；助手页在无任何模型且内置未下载时复用为
/// 下载引导。下载完成把 [builtinModelReadyProvider] 置真（会话内即生效，
/// 重启由 main() 按文件存在性播种），并在用户无激活档案时立即激活内置
/// 引擎——不走 [activateAndPersist]：内置档案不持久化激活 id，保持
/// 「用户档案永远优先」的解析语义。
class BuiltinModelCard extends ConsumerWidget {
  const BuiltinModelCard({super.key, this.subtitleOverride});

  /// 覆盖副标题文案（助手页引导场景用完整说明替代状态文案）。
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(builtinModelReadyProvider);
    final task = ref.watch(modelDownloaderProvider).task(builtinDownloadKey());
    final activeNow =
        ref.watch(llmEngineProvider).activeProfileId == kBuiltinProfileId;
    final hasUserModel = ref.watch(activeLlmProfileProvider) != null;

    ref.listen(modelDownloaderProvider, (_, _) {
      final t = ref.read(modelDownloaderProvider).task(builtinDownloadKey());
      if (t?.status == DownloadStatus.completed &&
          !ref.read(builtinModelReadyProvider)) {
        ref.read(builtinModelReadyProvider.notifier).state = true;
        // 无用户激活档案时立即激活内置引擎（懒激活的提前量，非持久化）
        if (ref.read(activeLlmProfileProvider) == null) {
          final profile = ref.read(builtinLlmProfileProvider);
          if (profile != null) {
            ref.read(llmEngineProvider.notifier).activate(profile);
          }
        }
      }
    });

    return BuiltinModelCardView(
      ready: ready,
      activeNow: activeNow,
      hasUserModel: hasUserModel,
      progress: task?.status == DownloadStatus.running ||
              task?.status == DownloadStatus.queued
          ? task!.progress
          : null,
      paused: task?.status == DownloadStatus.paused,
      failed: task?.status == DownloadStatus.failed,
      subtitleOverride: subtitleOverride,
      onDownload: () => _startDownload(context, ref),
      onPause: () => ref.read(modelDownloaderProvider).pause(builtinDownloadKey()),
      onResume: () => _startDownload(context, ref, silent: true),
      onActivate: () {
        final profile = ref.read(builtinLlmProfileProvider);
        if (profile != null) {
          ref.read(llmEngineProvider.notifier).activate(profile);
        }
      },
      onRetryErrorDismiss: () =>
          ref.read(modelDownloaderProvider).removeTask(builtinDownloadKey()),
    );
  }

  /// 开始（或断点续传）内置模型下载。先经确认弹窗（体积/流量告知），
  /// [silent] 用于暂停后续传，不再重复弹窗。
  Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref, {
    bool silent = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (!silent) {
      final ok = await showConfirmDialog(
        context,
        title: l10n.builtinDownloadTitle,
        content: l10n.builtinDownloadBody,
        confirmText: l10n.builtinDownloadConfirm,
      );
      if (!ok) return;
    }
    final files = await ref.read(modelscopeClientProvider).listGgufFiles(
          kBuiltinRepoId,
        );
    ModelScopeFile? file;
    for (final f in files) {
      if (f.path == kBuiltinFileName ||
          f.path.endsWith('/$kBuiltinFileName')) {
        file = f;
      }
    }
    if (!context.mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.builtinDownloadFailed)));
      return;
    }
    await ref.read(modelDownloaderProvider).start(kBuiltinRepoId, file);
  }
}

/// 卡片纯展示层（状态由 props 驱动，便于无网络单测）。
class BuiltinModelCardView extends StatelessWidget {
  const BuiltinModelCardView({
    super.key,
    required this.ready,
    required this.activeNow,
    required this.hasUserModel,
    this.progress,
    this.paused = false,
    this.failed = false,
    this.subtitleOverride,
    this.onDownload,
    this.onPause,
    this.onResume,
    this.onActivate,
    this.onRetryErrorDismiss,
  });

  final bool ready;
  final bool activeNow;
  final bool hasUserModel;
  final double? progress;
  final bool paused;
  final bool failed;
  final String? subtitleOverride;
  final VoidCallback? onDownload;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onActivate;
  final VoidCallback? onRetryErrorDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final downloading = progress != null;

    final String subtitle;
    if (subtitleOverride != null) {
      subtitle = subtitleOverride!;
    } else if (downloading) {
      subtitle = l10n.builtinDownloading((progress! * 100).round());
    } else if (paused) {
      subtitle = l10n.builtinDownloadPaused;
    } else if (ready) {
      subtitle = l10n.builtinModelReadySubtitle;
    } else {
      subtitle = l10n.builtinModelMissingSubtitle;
    }

    Widget? trailing;
    if (downloading) {
      trailing = IconButton(
        tooltip: l10n.builtinDownloadPaused,
        icon: const Icon(Icons.pause_circle_outline),
        onPressed: onPause,
      );
    } else if (paused) {
      trailing = IconButton(
        tooltip: l10n.builtinDownloadConfirm,
        icon: const Icon(Icons.play_circle_outline),
        onPressed: onResume,
      );
    } else if (!ready) {
      trailing = onDownload == null
          ? null
          : FilledButton.tonal(
              onPressed: onDownload,
              child: Text(l10n.builtinDownloadConfirm),
            );
    } else if (!activeNow && !hasUserModel) {
      trailing = onActivate == null
          ? null
          : FilledButton.tonal(
              onPressed: onActivate,
              child: Text(l10n.builtinUseNow),
            );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        leading: Icon(
          ready ? Icons.verified_outlined : Icons.cloud_download_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(l10n.builtinModelTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (downloading)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: progress),
              ),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      l10n.builtinDownloadFailed,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    TextButton(
                      onPressed: onRetryErrorDismiss,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: downloading || failed,
        trailing: trailing,
      ),
    );
  }
}
