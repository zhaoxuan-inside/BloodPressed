import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'modelscope_client.dart';

enum DownloadStatus { queued, running, paused, completed, failed }

/// 一个下载任务的可观察状态。
class DownloadTask {
  DownloadTask({
    required this.key,
    required this.repoId,
    required this.filePath,
    required this.totalBytes,
    this.receivedBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
  });

  final String key; // repoId + filePath
  final String repoId;
  final String filePath;
  final int totalBytes;

  int receivedBytes;
  DownloadStatus status;
  String? error;

  double get progress =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  String get fileName {
    final p = filePath;
    return p.contains('/') ? p.split('/').last : p;
  }
}

/// 模型下载管理器：支持暂停/继续（HTTP Range 断点续传）、并发限制为 1。
class ModelDownloadService extends ChangeNotifier {
  ModelDownloadService(this._client);

  final ModelScopeClient _client;
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  String? _activeKey;

  /// 已完成的任务 key（本次会话内）。
  final Set<String> _completedKeys = {};

  List<DownloadTask> get tasks => _tasks.values.toList();

  DownloadTask? task(String key) => _tasks[key];

  bool hasActiveDownload() =>
      _tasks.values.any((t) => t.status == DownloadStatus.running);

  /// 本地存储目录：{docs}/models/{repoIdSafe}/{fileName}
  static Future<Directory> storageDirFor(String repoId) async {
    final docs = await getApplicationDocumentsDirectory();
    final safe = repoId.replaceAll('/', '_');
    final dir = Directory('${docs.path}${Platform.pathSeparator}models'
        '${Platform.pathSeparator}$safe');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 目标文件最终路径。
  static Future<String> targetPath(String repoId, String filePath) async {
    final dir = await storageDirFor(repoId);
    final name = filePath.contains('/')
        ? filePath.split('/').last
        : filePath;
    return '${dir.path}${Platform.pathSeparator}$name';
  }

  /// 开始（或继续）下载。
  Future<void> start(String repoId, ModelScopeFile file) async {
    final key = '$repoId/${file.path}';
    final existing = _tasks[key];
    if (existing != null &&
        (existing.status == DownloadStatus.running)) {
      return;
    }

    final target = await targetPath(repoId, file.path);
    final partFile = File('$target.part');
    var startFrom = 0;
    if (partFile.existsSync()) {
      startFrom = partFile.lengthSync();
      if (startFrom >= file.size && file.size > 0) {
        // 已完整，直接转正
        partFile.renameSync(target);
        _upsertTask(DownloadTask(
          key: key,
          repoId: repoId,
          filePath: file.path,
          totalBytes: file.size,
          receivedBytes: file.size,
          status: DownloadStatus.completed,
        ));
        notifyListeners();
        return;
      }
    } else if (File(target).existsSync() &&
        File(target).lengthSync() == file.size) {
      _upsertTask(DownloadTask(
        key: key,
        repoId: repoId,
        filePath: file.path,
        totalBytes: file.size,
        receivedBytes: file.size,
        status: DownloadStatus.completed,
      ));
      notifyListeners();
      return;
    }

    final task = DownloadTask(
      key: key,
      repoId: repoId,
      filePath: file.path,
      totalBytes: file.size,
      receivedBytes: startFrom,
      status: DownloadStatus.running,
    );
    _upsertTask(task);
    _activeKey = key;
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;

    try {
      final sink = partFile.openSync(mode: FileMode.append);
      try {
        await _client.downloadWithProgress(
          url: _client.downloadUrl(repoId, file.path),
          startFrom: startFrom,
          // 闭合 Range（bytes=start-end）：魔搭直连端点对开放 Range
          // （bytes=N-）会返回全量 Content-Length 却只发送剩余部分并断开，
          // 导致 dart:io 抛 Connection closed；闭合区间则两端都精确。
          endByte: file.size > 0 ? file.size - 1 : null,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            task.receivedBytes = startFrom + received;
            notifyListeners();
          },
          onChunk: (bytes) => sink.writeFromSync(bytes),
        );
      } finally {
        await sink.flush();
        sink.closeSync();
      }
      partFile.renameSync(target);
      task.status = DownloadStatus.completed;
      task.receivedBytes = task.totalBytes;
      _completedKeys.add(key);
      _activeKey = null;
      _startNextQueued();
      notifyListeners();
    } catch (e) {
      if (cancelToken.isCancelled) {
        task
          ..status = DownloadStatus.paused
          ..error = '已暂停';
      } else {
        task
          ..status = DownloadStatus.failed
          ..error = e.toString();
        _activeKey = null;
        _startNextQueued();
      }
      notifyListeners();
    }
  }

  Future<void> pause(String key) async {
    _cancelTokens[key]?.cancel('pause');
  }

  Future<void> removeTask(String key) async {
    _cancelTokens[key]?.cancel('remove');
    _cancelTokens.remove(key);
    _tasks.remove(key);
    notifyListeners();
  }

  /// 下载完成后模型文件的最终路径（completed 任务）。
  Future<String?> completedPath(String key) async {
    final t = _tasks[key];
    if (t == null || t.status != DownloadStatus.completed) return null;
    return targetPath(t.repoId, t.filePath);
  }

  void _upsertTask(DownloadTask t) => _tasks[t.key] = t;

  void _startNextQueued() {
    final next = _tasks.values
        .where((t) => t.status == DownloadStatus.queued)
        .toList();
    if (next.isEmpty || _activeKey != null) return;
    _startNextQueued0(next.first);
  }

  void _startNextQueued0(DownloadTask t) {
    // 延迟一拍，避免在 notifyListeners 过程中递归
    Future.microtask(() {
      final file = ModelScopeFile(path: t.filePath, size: t.totalBytes);
      start(t.repoId, file);
    });
  }

  @override
  void dispose() {
    for (final t in _cancelTokens.values) {
      t.cancel('dispose');
    }
    _client.dispose();
    super.dispose();
  }
}
