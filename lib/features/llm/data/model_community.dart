/// 模型社区抽象：模型中心同时接入多个模型社区（魔搭 / HuggingFace），
/// 「能搜到哪个就用哪个」。UI 不暴露社区品牌，本层只对内可见。
///
/// * [ModelCommunity.search]：按名称搜索仓库
/// * [ModelCommunity.listFiles] / [listGgufFiles]：仓库文件清单
/// * [ModelCommunity.downloadUrl] / [downloadWithProgress]：直链与断点续传下载
library;

import 'package:dio/dio.dart';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';

/// 一个仓库中的文件（统一两社区的清单形状）。
class ModelFileInfo {
  const ModelFileInfo({
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

/// 搜索命中的一条仓库摘要。
class RepoSummary {
  const RepoSummary({
    required this.communityId,
    required this.repoId,
    this.downloads = 0,
  });

  final String communityId;
  final String repoId;
  final int downloads;
}

/// 模型社区接口。实现方必须支持 HTTP Range 断点续传下载。
abstract class ModelCommunity {
  /// 社区标识（下载任务 key 前缀，避免两社区同仓库同文件撞 key）。
  String get id;

  /// 按名称搜索仓库（按下载量等社区自身排序返回）。
  Future<List<RepoSummary>> search(String query, {int limit = 20});

  /// 仓库下全部文件（含大小）。仓库不存在时抛 [InferenceException]。
  Future<List<ModelFileInfo>> listFiles(String repoId);

  /// 过滤出可用的 GGUF 权重文件（排除 mmproj 等投影文件）。
  Future<List<ModelFileInfo>> listGgufFiles(String repoId) async {
    final files = await listFiles(repoId);
    return files
        .where((f) =>
            f.path.toLowerCase().endsWith('.gguf') &&
            !f.path.toLowerCase().contains('mmproj'))
        .toList();
  }  /// 单文件直链下载地址。
  String downloadUrl(String repoId, String filePath);

  /// 带 Range 断点续传与逐块回调的下载。
  Future<void> downloadWithProgress({
    required String url,
    required int startFrom,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
    required void Function(List<int> bytes) onChunk,
    int? endByte,
  });
}

/// 共享的流式下载实现：各社区仅 URL 形态不同，传输行为一致。
/// 提取在此避免两份 Range/取消逻辑漂移。
Future<void> streamDownload(
  Dio dio, {
  required String url,
  required int startFrom,
  required CancelToken cancelToken,
  required void Function(int received, int total) onProgress,
  required void Function(List<int> bytes) onChunk,
  int? endByte,
}) async {
  final rangeEnd = endByte?.toString() ?? '';
  final headers = <String, String>{
    if (startFrom > 0 || endByte != null)
      'Range': 'bytes=$startFrom-$rangeEnd',
  };
  final resp = await dio.get<ResponseBody>(
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
