import 'package:dio/dio.dart';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';

/// 魔搭社区（ModelScope）模型仓库客户端。
///
/// * 列文件：GET /api/v1/models/{id}/repo/files?Revision=master
/// * 下载：  GET /api/v1/models/{id}/repo?Revision=master&FilePath={path}
///          （302 → LFS CDN，支持 HTTP Range 断点续传，已实测验证）
class ModelScopeClient {
  ModelScopeClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
              followRedirects: true,
              maxRedirects: 5,
              validateStatus: (s) => s != null && (s < 300 || s == 302),
            ));

  final Dio _dio;

  static const String baseUrl = 'https://modelscope.cn';
  static const String apiBase = '$baseUrl/api/v1/models';

  /// 精选的手机端友好的 GGUF 模型仓库（全部为 Qwen 官方仓库，已验证可访问）。
  static const List<CuratedModel> curated = [
    CuratedModel(
      repoId: 'Qwen/Qwen3-0.6B-GGUF',
      title: 'Qwen3 0.6B',
      desc: '轻量首选 · 低端机可用 · 0.4~0.6GB',
      sizeHint: '约 0.4~0.7 GB',
    ),
    CuratedModel(
      repoId: 'Qwen/Qwen3-1.7B-GGUF',
      title: 'Qwen3 1.7B',
      desc: '效果与速度均衡 · 推荐中端及以上机型',
      sizeHint: '约 1.0~1.9 GB',
    ),
    CuratedModel(
      repoId: 'Qwen/Qwen3-4B-GGUF',
      title: 'Qwen3 4B',
      desc: '回答质量更好 · 需要 6GB+ 内存',
      sizeHint: '约 2.3~4.4 GB',
    ),
    CuratedModel(
      repoId: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
      title: 'Qwen2.5 0.5B Instruct',
      desc: '上一代小模型 · 省内存',
      sizeHint: '约 0.4~0.7 GB',
    ),
    CuratedModel(
      repoId: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      title: 'Qwen2.5 1.5B Instruct',
      desc: '上一代均衡之选',
      sizeHint: '约 0.9~1.8 GB',
    ),
    CuratedModel(
      repoId: 'Qwen/Qwen2.5-3B-Instruct-GGUF',
      title: 'Qwen2.5 3B Instruct',
      desc: '上一代质量档',
      sizeHint: '约 1.8~3.2 GB',
    ),
  ];

  /// 仓库下全部文件（含大小）。
  Future<List<ModelScopeFile>> listFiles(String repoId) async {
    final resp = await _dio.get<Map<String, Object?>>(
      '$apiBase/$repoId/repo/files',
      queryParameters: {'Revision': 'master'},
    );
    final code = resp.data?['Code'];
    if (code != 200) {
      throw InferenceException('魔搭返回错误（Code: $code），请检查模型ID是否正确');
    }
    final data = resp.data?['Data'] as Map<String, Object?>?;
    final files = data?['Files'] as List?;
    if (files == null) return [];
    return files
        .whereType<Map>()
        .map((f) => ModelScopeFile(
              path: (f['Path'] ?? f['Name'] ?? '') as String,
              size: (f['Size'] as num?)?.toInt() ?? 0,
              isLfs: f['IsLFS'] == true,
              sha256: f['Sha256'] as String?,
            ))
        .where((f) => f.path.isNotEmpty)
        .toList();
  }

  /// 过滤出可用的 GGUF 权重文件（排除 mmproj 等投影文件）。
  Future<List<ModelScopeFile>> listGgufFiles(String repoId) async {
    final files = await listFiles(repoId);
    return files
        .where((f) =>
            f.path.toLowerCase().endsWith('.gguf') &&
            !f.path.toLowerCase().contains('mmproj'))
        .toList();
  }

  /// 单文件直链下载地址（302 → CDN）。
  String downloadUrl(String repoId, String filePath) {
    return '$apiBase/$repoId/repo?Revision=master&FilePath=$filePath';
  }

  /// 带 Range 断点续传与逐块回调的下载。
  Future<void> downloadWithProgress({
    required String url,
    required int startFrom,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
    required void Function(List<int> bytes) onChunk,
  }) async {
    final headers = <String, String>{
      if (startFrom > 0) 'Range': 'bytes=$startFrom-',
    };
    final resp = await _dio.get<ResponseBody>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
    );
    final totalHeader = resp.headers.value('content-length');
    final total = totalHeader == null ? 0 : int.tryParse(totalHeader) ?? 0;
    var received = 0;
    await for (final chunk in resp.data!.stream.cast<List<int>>()) {
      if (cancelToken.isCancelled) {
        throw DioException(
          requestOptions: RequestOptions(path: url),
          error: 'cancelled',
        );
      }
      onChunk(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received, total);
    }
  }

  void dispose() => _dio.close();
}

class ModelScopeFile {
  const ModelScopeFile({
    required this.path,
    required this.size,
    this.isLfs = false,
    this.sha256,
  });

  final String path;
  final int size;
  final bool isLfs;
  final String? sha256;

  String get fileName => path.contains('/') ? path.split('/').last : path;
}

/// 精选模型条目。
class CuratedModel {
  const CuratedModel({
    required this.repoId,
    required this.title,
    required this.desc,
    required this.sizeHint,
  });

  final String repoId;
  final String title;
  final String desc;
  final String sizeHint;
}
