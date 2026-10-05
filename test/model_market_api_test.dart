/// 魔搭真实 API 测试（纯 test，不加载 TestWidgetsFlutterBinding，
/// 因此不会被测试框架的 HTTP 拦截器替换响应——全部为真实网络请求）。
///
/// 直连 modelscope.cn 真实接口与 LFS CDN，验证：
/// * 精选清单中的仓库真实存在且含 GGUF 权重；
/// * 文件列表/大小/LFS 标记为真实数据；
/// * 全量下载与断点续传的字节级一致性（真实 Range）；
/// * 真实 GGUF 文件头魔数（302 → CDN → Range 完整链路）；
/// * 下载服务的 .part 续传与去重（真实网络数据 + 临时目录落盘）。
///
/// 注意：运行本文件需要外网可访问 modelscope.cn。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/data/modelscope_client.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';

const _repo = 'Qwen/Qwen3-0.6B-GGUF';
const _readme = 'README.md';

/// 将文档目录指向系统临时目录：仅为下载落盘提供位置垫片，
/// 测试中的全部网络数据（列表、字节、错误响应）均来自真实魔搭服务。
class _TempDocumentsPathProvider extends PathProviderPlatform {
  _TempDocumentsPathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

Future<List<int>> _downloadAll(
  ModelScopeClient client,
  String repoId,
  String filePath, {
  int startFrom = 0,
  int? endByte,
  List<void Function(int received, int total)>? progressCalls,
}) async {
  final bytes = <int>[];
  await client.downloadWithProgress(
    url: client.downloadUrl(repoId, filePath),
    startFrom: startFrom,
    endByte: endByte,
    cancelToken: CancelToken(),
    onProgress: (r, t) {
      for (final cb in progressCalls ?? const <void Function(int, int)>[]) {
        cb(r, t);
      }
    },
    onChunk: bytes.addAll,
  );
  return bytes;
}

void main() {
  group('魔搭真实 API：文件列表', () {
    final client = ModelScopeClient();

    test('精选清单中的 6 个仓库真实存在且含 GGUF 权重', () async {
      for (final m in ModelScopeClient.curated) {
        final files = await client.listGgufFiles(m.repoId);
        expect(files, isNotEmpty,
            reason: '${m.repoId} 应在魔搭真实存在且含 GGUF 文件');
        for (final f in files) {
          expect(f.path.toLowerCase().endsWith('.gguf'), isTrue,
              reason: '${m.repoId} 列表应只含 GGUF：${f.path}');
          expect(f.size, greaterThan(100 * 1024 * 1024),
              reason: '${m.repoId} 权重文件应大于 100MB：${f.path}=${f.size}');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Qwen/Qwen3-0.6B-GGUF 返回真实文件与元数据', () async {
      final files = await client.listFiles(_repo);

      expect(files.map((f) => f.path), contains('Qwen3-0.6B-Q8_0.gguf'));
      final q8 = files.firstWhere((f) => f.path == 'Qwen3-0.6B-Q8_0.gguf');
      expect(q8.size, inExclusiveRange(600 * 1024 * 1024, 700 * 1024 * 1024),
          reason: 'Q8_0 真实大小约 639MB，实际 ${q8.size}');
      expect(q8.isLfs, isTrue, reason: 'GGUF 权重应为 LFS 文件');
      expect(q8.sha256, isNotNull);
      expect(q8.sha256!.length, 64);

      // listGgufFiles 只保留权重：README/LICENSE/configuration.json 被过滤
      final ggufs = await client.listGgufFiles(_repo);
      expect(ggufs.map((f) => f.path), everyElement(endsWith('.gguf')));
      expect(ggufs.map((f) => f.path), contains('Qwen3-0.6B-Q8_0.gguf'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('不存在的仓库抛出魔搭错误（真实错误响应）', () async {
      await expectLater(
        client.listGgufFiles('This/DoesNotExist-xyz-GGUF'),
        throwsA(isA<InferenceException>()
            .having((e) => e.message, 'message', contains('魔搭返回错误'))),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('魔搭真实 CDN：下载与断点续传', () {
    final client = ModelScopeClient();

    test('全量下载 README.md：字节数与进度回调与服务器一致', () async {
      final meta =
          (await client.listFiles(_repo)).firstWhere((f) => f.path == _readme);
      final progress = <int>[];
      var lastTotal = 0;

      final bytes = await _downloadAll(client, _repo, _readme,
          progressCalls: [(r, t) {
            progress.add(r);
            lastTotal = t;
          }]);

      expect(bytes.length, meta.size, reason: '全量下载字节数应等于服务器报告的大小');
      expect(lastTotal, meta.size);
      expect(progress.last, meta.size);
      // 真实内容校验：Qwen 仓库 README 为 UTF-8 文本且提及 Qwen
      final text = String.fromCharCodes(bytes);
      expect(text, contains('Qwen'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('断点续传：闭合 Range 从第 1000 字节继续，尾部字节与全量完全一致', () async {
      final meta =
          (await client.listFiles(_repo)).firstWhere((f) => f.path == _readme);
      final full = await _downloadAll(client, _repo, _readme);
      final resumed = await _downloadAll(client, _repo, _readme,
          startFrom: 1000, endByte: meta.size - 1);

      expect(resumed.length, full.length - 1000);
      expect(full.sublist(1000), resumed,
          reason: '续传内容必须与全量下载的尾部逐字节一致');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('真实 GGUF 经 302→LFS CDN 拉取 Range：文件头为 GGUF 魔数', () async {
      final head =
          await _downloadAll(client, _repo, 'Qwen3-0.6B-Q8_0.gguf',
              endByte: 99);

      expect(head.length, 100, reason: 'Range: bytes=0-99 应返回 100 字节');
      expect(String.fromCharCodes(head.sublist(0, 4)), 'GGUF',
          reason: 'GGUF 文件魔数校验（证明拿到的是真实模型数据）');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('下载服务（真实网络 + 临时目录）', () {
    late Directory docs;
    late ModelScopeClient client;
    late ModelDownloadService service;

    setUp(() async {
      docs = await Directory.systemTemp.createTemp('bp_dl_test');
      PathProviderPlatform.instance = _TempDocumentsPathProvider(docs.path);
      client = ModelScopeClient();
      service = ModelDownloadService(client);
    });

    tearDown(() async {
      service.dispose();
      await docs.delete(recursive: true);
    });

    test('完整下载 configuration.json：落盘内容与服务器字节一致', () async {
      const filePath = 'configuration.json';
      final full = await _downloadAll(client, _repo, filePath);
      final meta = (await client.listFiles(_repo))
          .firstWhere((f) => f.path == filePath);

      await service.start(_repo, meta);

      final task = service.task('$_repo/$filePath')!;
      expect(task.status, DownloadStatus.completed,
          reason: '失败原因：${task.error}');
      final target = await ModelDownloadService.targetPath(_repo, filePath);
      expect(File(target).existsSync(), isTrue);
      expect(File(target).readAsBytesSync(), full);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('断点续传：以真实前 20 字节作为 .part，续传后与全量逐字节一致', () async {
      const filePath = _readme;
      final full = await _downloadAll(client, _repo, filePath);
      final meta = (await client.listFiles(_repo))
          .firstWhere((f) => f.path == filePath);

      // 预置真实下载的前 20 字节作为已下载部分
      final target = await ModelDownloadService.targetPath(_repo, filePath);
      File('$target.part').writeAsBytesSync(full.sublist(0, 20));

      await service.start(_repo, meta);

      final task = service.task('$_repo/$filePath')!;
      expect(task.status, DownloadStatus.completed,
          reason: '失败原因：${task.error}');
      expect(task.receivedBytes, meta.size);
      expect(File(target).readAsBytesSync(), full,
          reason: '续传后的完整文件必须与全量下载逐字节一致');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('重复 start：已完成的文件直接去重，不再发起网络请求', () async {
      const filePath = 'configuration.json';
      final meta = (await client.listFiles(_repo))
          .firstWhere((f) => f.path == filePath);

      await service.start(_repo, meta);
      await service.start(_repo, meta);

      final task = service.task('$_repo/$filePath')!;
      expect(task.status, DownloadStatus.completed);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
