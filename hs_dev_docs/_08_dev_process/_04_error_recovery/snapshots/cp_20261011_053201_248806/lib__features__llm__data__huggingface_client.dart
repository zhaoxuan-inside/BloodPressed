import 'package:dio/dio.dart';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/data/model_community.dart';

/// 模型社区二：HuggingFace 仓库客户端。
///
/// 直连在国内网络常不可用，按 [hosts] 顺序回退（默认镜像优先）：
/// 每次请求逐 host 尝试，首个成功者在该客户端实例内记忆复用。
///
/// * 搜索：  GET {host}/api/models?search={q}&limit={n}
/// * 列文件：GET {host}/api/models/{id}/tree/main
/// * 下载：  GET {host}/{id}/resolve/main/{path}（支持 Range 续传）
class HuggingFaceClient extends ModelCommunity {
  HuggingFaceClient({Dio? dio, List<String>? hosts})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 60),
              followRedirects: true,
              maxRedirects: 5,
              validateStatus: (s) => s != null && s < 400,
            )),
        hosts = hosts ?? ['https://hf-mirror.com', 'https://huggingface.co'];

  final Dio _dio;

  /// 按优先级排列的 API host（首个成功者被记忆，后续请求直达）。
  final List<String> hosts;
  String? _activeHost;

  String get _host => _activeHost ?? hosts.first;

  @override
  String get id => 'huggingface';

  /// 逐 host 尝试一次请求；全失败抛最后一个异常。
  Future<Response<T>> _get<T>(
    String path, {
    Map<String, Object?>? query,
  }) async {
    Object? lastError;
    final ordered = [
      ?_activeHost,
      ...hosts.where((h) => h != _activeHost),
    ];
    for (final host in ordered) {
      try {
        final resp = await _dio.get<T>('$host$path', queryParameters: query);
        _activeHost = host;
        return resp;
      } on DioException catch (e) {
        // 4xx 说明 host 可达但资源不存在——换 host 无意义，直接抛
        final status = e.response?.statusCode;
        if (status != null && status >= 400 && status < 500 && status != 429) {
          _activeHost = host;
          rethrow;
        }
        lastError = e;
      }
    }
    throw InferenceException('模型中心网络不可用', lastError);
  }

  /// 按名称搜索 GGUF 仓库（tag 含 gguf 或 id 含 gguf）。
  @override
  Future<List<RepoSummary>> search(String query, {int limit = 20}) async {
    final resp = await _get<List<Object?>>(
      '/api/models',
      query: {
        'search': query,
        'limit': limit,
      },
    );
    return parseSearch(resp.data ?? const []);
  }

  /// 解析搜索响应（static 便于无网络单测）：GGUF tag/id 过滤。
  static List<RepoSummary> parseSearch(List<Object?> items) {
    final out = <RepoSummary>[];
    for (final m in items.whereType<Map>()) {
      final repoId = (m['id'] ?? '') as String;
      if (repoId.isEmpty) continue;
      final tags = ((m['tags'] as List?) ?? const []).join(' ').toLowerCase();
      if (!repoId.toLowerCase().contains('gguf') && !tags.contains('gguf')) {
        continue;
      }
      out.add(RepoSummary(
        communityId: 'huggingface',
        repoId: repoId,
        downloads: (m['downloads'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  }

  /// 仓库下全部文件（HF tree API；LFS 大小在 lfs.size）。
  @override
  Future<List<ModelFileInfo>> listFiles(String repoId) async {
    final resp = await _get<List<Object?>>(
      '/api/models/$repoId/tree/main',
    );
    return parseTree(resp.data ?? const []);
  }

  /// 解析 tree 响应（static 便于无网络单测）：LFS 大小优先。
  static List<ModelFileInfo> parseTree(List<Object?> items) {
    return items
        .whereType<Map>()
        .where((f) => f['type'] == 'file')
        .map((f) {
      final lfs = f['lfs'] as Map?;
      return ModelFileInfo(
        path: (f['path'] ?? '') as String,
        size: lfs != null
            ? (lfs['size'] as num?)?.toInt() ?? 0
            : (f['size'] as num?)?.toInt() ?? 0,
        isLfs: lfs != null,
      );
    }).where((f) => f.path.isNotEmpty).toList();
  }

  @override
  String downloadUrl(String repoId, String filePath) {
    return '$_host/$repoId/resolve/main/$filePath';
  }

  @override
  Future<void> downloadWithProgress({
    required String url,
    required int startFrom,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
    required void Function(List<int> bytes) onChunk,
    int? endByte,
  }) {
    return streamDownload(
      _dio,
      url: url,
      startFrom: startFrom,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onChunk: onChunk,
      endByte: endByte,
    );
  }

  void dispose() => _dio.close();
}
