/// 模型中心服务：并行查询多个模型社区，合并去重——
/// 「能搜到哪个就用哪个」。单社区失败不影响另一社区的结果。
library;

import 'dart:async';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/data/model_community.dart';

class ModelCenterService {
  ModelCenterService(Map<String, ModelCommunity> communities)
      : _communities = Map.of(communities);

  final Map<String, ModelCommunity> _communities;

  ModelCommunity? community(String id) => _communities[id];

  /// 并行搜索全部社区；单社区超时/失败静默降级为空结果。
  /// 合并后按 repoId 去重（同仓库多社区命中保留下载量高者），按下载量降序。
  Future<List<RepoSummary>> searchAll(
    String query, {
    int limitPerCommunity = 20,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final futures = _communities.values.map((c) async {
      try {
        return await c.search(q, limit: limitPerCommunity).timeout(timeout);
      } catch (_) {
        return const <RepoSummary>[];
      }
    });
    final perCommunity = await Future.wait(futures);
    final byRepo = <String, RepoSummary>{};
    for (final repo in perCommunity.expand((l) => l)) {
      final existing = byRepo[repo.repoId];
      if (existing == null || repo.downloads > existing.downloads) {
        byRepo[repo.repoId] = repo;
      }
    }
    final merged = byRepo.values.toList()
      ..sort((a, b) => b.downloads.compareTo(a.downloads));
    return merged;
  }

  /// 在全部社区中查找仓库的 GGUF 文件清单（并行，首个成功者胜出），
  /// 返回命中社区 id 与文件（下载需按社区分发 URL）。全部失败抛最后一个
  /// 异常；用于自定义仓库 ID 的双源查找。
  Future<({String communityId, List<ModelFileInfo> files})>
      listGgufAnywhere(String repoId) async {
    if (_communities.isEmpty) {
      throw StateError('未接入任何模型社区');
    }
    final errors = <Object>[];
    final futures = _communities.values.map((c) async {
      try {
        final files = await c.listGgufFiles(repoId).timeout(
              const Duration(seconds: 10),
            );
        return (communityId: c.id, files: files);
      } catch (e) {
        errors.add(e);
        return null;
      }
    });
    final results = await Future.wait(futures);
    for (final hit in results) {
      if (hit != null) return hit;
    }
    // 全部失败：优先抛可读的业务错误（如社区错误码「仓库不存在」），
    // 而非裸 DioException
    final readable = errors.whereType<InferenceException>().toList();
    throw readable.isNotEmpty
        ? readable.first
        : errors.isNotEmpty
            ? errors.last
            : StateError('所有社区均未找到仓库 $repoId 的 GGUF 文件');
  }
}
