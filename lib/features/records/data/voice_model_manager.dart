/// 离线语音识别模型管理：下载、完整性校验、本地存储。
///
/// 模型为 sherpa-onnx streaming zipformer 中英双语 small 的 int8 版本，
/// 托管在 ModelScope 镜像（liaowenbin/sherpa-onnx-streaming-zipformer-
/// small-bilingual-zh-en-2023-02-16-mobile），单文件直下、走魔搭 LFS CDN，
/// 与内置 LLM 的模型下载共用同一网络环境假设，支持 Range 断点续传。
/// 总量约 50MB，免 tar.bz2 解压（避免低端机解压内存峰值）。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// 模型的单个组成文件。
class VoiceModelFile {
  const VoiceModelFile(this.remotePath, this.localName, this.size);

  /// 仓库内路径（魔搭 FilePath 参数）。
  final String remotePath;

  /// 落盘文件名（模型目录内平铺）。
  final String localName;

  /// 期望字节数（完整性校验用）。
  final int size;
}

/// 文件内已接收字节数回调（含断点续传的起始偏移）。
typedef VoiceModelFileProgress = void Function(int receivedInFile);

/// HTTP 传输 seam：测试注入假实现，默认 dio Range 续传下载。
typedef VoiceModelFetcher = Future<void> Function(
  String url,
  File target,
  int startFrom,
  VoiceModelFileProgress onReceived,
);

/// 模型存储接口：上层（provider）仅依赖此抽象，测试注入 Fake。
abstract interface class VoiceModelStore {
  /// 模型是否已完整下载（逐文件存在且字节数匹配）。
  Future<bool> isDownloaded();

  /// 是否有下载正在进行（页面关闭后仍继续）。
  bool get isDownloading;

  /// 当前下载进度 [0, 1]。
  double get progress;

  /// 下载全部模型文件（幂等：进行中时重复调用直接返回）。
  ///
  /// 失败时抛出异常（部分文件保留 .part，可续传）。
  Future<void> download();

  /// 订阅下载进度 [0, 1]（广播流；仅在下载期间有事件）。
  Stream<double> get progressStream;

  /// 模型目录路径（供引擎加载；目录不存在时创建）。
  Future<String> modelDir();
}

/// 基于 ModelScope 的默认实现。
class VoiceModelManager implements VoiceModelStore {
  VoiceModelManager({Dio? dio, VoiceModelFetcher? fetcher, String? docsPath})
    : _fetcher =
          fetcher ??
          ((url, target, startFrom, onReceived) =>
              _dioFetcher(url, target, startFrom, onReceived, dio: dio)),
      _docsPathOverride = docsPath;

  final VoiceModelFetcher _fetcher;
  final String? _docsPathOverride;

  /// 模型仓库 id（ModelScope）。
  static const String repoId =
      'liaowenbin/sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16-mobile';

  /// 下载端点：魔搭仓库直下（302 → LFS CDN，支持 Range 断点续传）。
  static String downloadUrl(String filePath) =>
      'https://modelscope.cn/api/v1/models/$repoId/repo'
      '?Revision=master&FilePath=$filePath';

  /// 组成文件（仓库 root 平铺变体：int8 encoder + fp32 decoder +
  /// int8 joiner + 词表，总计约 50MB）。
  static const List<VoiceModelFile> files = [
    VoiceModelFile(
      'encoder-epoch-99-avg-1.int8.onnx',
      'encoder.int8.onnx',
      32631819,
    ),
    VoiceModelFile('decoder-epoch-99-avg-1.onnx', 'decoder.onnx', 13877276),
    VoiceModelFile(
      'joiner-epoch-99-avg-1.int8.onnx',
      'joiner.int8.onnx',
      3228485,
    ),
    VoiceModelFile('tokens.txt', 'tokens.txt', 56317),
  ];

  /// 模型总字节数。
  static const int totalBytes = 32631819 + 13877276 + 3228485 + 56317;

  double _progress = 0;
  bool _downloading = false;
  final _progressController = StreamController<double>.broadcast();

  @override
  bool get isDownloading => _downloading;

  @override
  double get progress => _progress;

  @override
  Stream<double> get progressStream => _progressController.stream;

  Future<String> _resolveDocsPath() async {
    final override = _docsPathOverride;
    if (override != null) return override;
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  @override
  Future<String> modelDir() async {
    final docs = await _resolveDocsPath();
    final sep = Platform.pathSeparator;
    final safe = repoId.replaceAll('/', '_');
    final dir = Directory([docs, 'models', safe].join(sep));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  @override
  Future<bool> isDownloaded() async {
    final dir = await modelDir();
    for (final f in files) {
      final file = File('$dir${Platform.pathSeparator}${f.localName}');
      if (!file.existsSync() || file.lengthSync() != f.size) return false;
    }
    return true;
  }

  @override
  Future<void> download() async {
    if (_downloading) return;
    _downloading = true;
    try {
      final dir = await modelDir();
      // 已完整文件计入基数，进度从真实起点出发（断点续传友好）。
      var completedBytes = 0;
      for (final f in files) {
        final target = File('$dir${Platform.pathSeparator}${f.localName}');
        if (target.existsSync() && target.lengthSync() == f.size) {
          completedBytes += f.size;
        }
      }
      _reportProgress(completedBytes / totalBytes);

      for (final f in files) {
        final target = File('$dir${Platform.pathSeparator}${f.localName}');
        if (target.existsSync() && target.lengthSync() == f.size) continue;
        final part = File('${target.path}.part');
        // A corrupt oversized prefix can never be resumed into a valid file.
        if (part.existsSync() && part.lengthSync() > f.size) {
          part.deleteSync();
        }
        final startFrom = part.existsSync() ? part.lengthSync() : 0;
        if (startFrom < f.size) {
          await _fetcher(downloadUrl(f.remotePath), part, startFrom, (r) {
            _reportProgress((completedBytes + r) / totalBytes);
          });
        }
        // 完整性校验后转正
        final size = part.existsSync() ? part.lengthSync() : 0;
        if (size != f.size) {
          if (size > f.size) part.deleteSync();
          throw Exception('模型文件不完整: ${f.localName}');
        }
        if (target.existsSync()) target.deleteSync();
        part.renameSync(target.path);
        completedBytes += f.size;
        _reportProgress(completedBytes / totalBytes);
      }
      _progress = 1;
      _progressController.add(1);
    } finally {
      _downloading = false;
    }
  }

  void _reportProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    _progressController.add(_progress);
  }

  /// 默认 HTTP 实现：Range 续传 + 流式落盘。
  static Future<void> _dioFetcher(
    String url,
    File target,
    int startFrom,
    VoiceModelFileProgress onReceived, {
    Dio? dio,
  }) async {
    final client =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            // receiveTimeout 是两次读包间隔，不限制整体传输时长
            receiveTimeout: const Duration(seconds: 60),
            followRedirects: true,
            maxRedirects: 5,
          ),
        );
    try {
      final response = await client.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: startFrom > 0 ? {'range': 'bytes=$startFrom-'} : null,
        ),
      );
      final body = response.data!;
      var offset = 0;
      if (response.statusCode == 206) {
        final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(response.headers.value('content-range') ?? '');
        if (range == null ||
            int.parse(range[1]!) != startFrom ||
            int.parse(range[2]!) < startFrom ||
            int.parse(range[3]!) <= int.parse(range[2]!)) {
          await body.stream.listen(null).cancel();
          throw Exception('模型续传响应范围不匹配');
        }
        offset = startFrom;
      } else if (response.statusCode != 200) {
        await body.stream.listen(null).cancel();
        throw Exception('模型下载响应异常: ${response.statusCode}');
      }
      // A 200 response means Range was ignored: replace, never append.
      final sink = await target.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      try {
        onReceived(offset);
        await for (final chunk in body.stream) {
          await sink.writeFrom(chunk);
          offset += chunk.length;
          onReceived(offset);
        }
      } finally {
        await sink.close();
      }
    } finally {
      if (dio == null) client.close();
    }
  }
}
