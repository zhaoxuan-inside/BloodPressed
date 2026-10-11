import 'package:dio/dio.dart';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/data/model_community.dart';

/// 模型社区一：魔搭（ModelScope）仓库客户端。
///
/// * 搜索：  PUT /api/v1/dolphin/models（body 键为 Name，实测 Query 键无效）
/// * 列文件：GET /api/v1/models/{id}/repo/files?Revision=master
/// * 下载：  GET /api/v1/models/{id}/repo?Revision=master&FilePath={path}
///          （302 → LFS CDN，支持 HTTP Range 断点续传，已实测验证）
class ModelScopeClient extends ModelCommunity {
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

  @override
  String get id => 'modelscope';

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

  /// 按名称搜索仓库（body 键为 Name——Query 键实测被服务端忽略）。
  @override
  Future<List<RepoSummary>> search(String query, {int limit = 20}) async {
    final resp = await _dio.put<Map<String, Object?>>(
      '$baseUrl/api/v1/dolphin/models',
      data: {
        'Name': query,
        'PageSize': limit,
        'PageNumber': 1,
      },
    );
    if (resp.data?['Code'] != 200) return const [];
    final data = resp.data?['Data'] as Map<String, Object?>?;
    final models =
        ((data?['Model'] as Map<String, Object?>?)?['Models'] as List?) ??
            const [];
    return models
        .whereType<Map>()
        .map((m) => RepoSummary(
              communityId: id,
              repoId: '${m['Path']}/${m['Name']}',
              downloads: (m['Downloads'] as num?)?.toInt() ?? 0,
            ))
        .where((r) => r.repoId.isNotEmpty && !r.repoId.startsWith('/'))
        .toList();
  }

  /// 仓库下全部文件（含大小）。
  ///
  /// 注意：魔搭对不存在的仓库返回 HTTP 404 + JSON 错误体
  /// （Code: 10010205001），需从错误响应中解析真实错误码。
  @override
  Future<List<ModelFileInfo>> listFiles(String repoId) async {
    Response<Map<String, Object?>> resp;
    try {
      resp = await _dio.get<Map<String, Object?>>(
        '$apiBase/$repoId/repo/files',
        queryParameters: {'Revision': 'master'},
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        throw InferenceException(_errorMessage(
          body['Code'],
          body['Message'] as String?,
        ));
      }
      rethrow;
    }
    final code = resp.data?['Code'];
    if (code != 200) {
      throw InferenceException(_errorMessage(
        code,
        resp.data?['Message'] as String?,
      ));
    }
    final data = resp.data?['Data'] as Map<String, Object?>?;
    final files = data?['Files'] as List?;
    if (files == null) return [];
    return files
        .whereType<Map>()
        .map((f) => ModelFileInfo(
              path: (f['Path'] ?? f['Name'] ?? '') as String,
              size: (f['Size'] as num?)?.toInt() ?? 0,
              isLfs: f['IsLFS'] == true,
              sha256: f['Sha256'] as String?,
            ))
        .where((f) => f.path.isNotEmpty)
        .toList();
  }

  static String _errorMessage(Object? code, String? message) {
    final hint = (message == null || message.isEmpty) ? '' : '，$message';
    return '获取模型文件失败（Code: $code$hint），请检查模型ID是否正确';
  }

  /// 单文件直链下载地址（302 → CDN）。
  @override
  String downloadUrl(String repoId, String filePath) {
    return '$apiBase/$repoId/repo?Revision=master&FilePath=$filePath';
  }

  /// 带 Range 断点续传与逐块回调的下载。
  ///
  /// [endByte] 可选：闭合区间下载（Range: bytes=start-end），
  /// 用于按需拉取文件头做魔数校验等场景；null 表示下载到文件末尾。
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
