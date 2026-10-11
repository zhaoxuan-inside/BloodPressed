/// 模型中心单测（无网络）：HF 客户端解析（fixture）、双社区搜索合并去重、
/// 下载 key 社区前缀、自动建档幂等。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/llm/data/huggingface_client.dart';
import 'package:blood_pressed/features/llm/data/model_center_service.dart';
import 'package:blood_pressed/features/llm/data/model_community.dart';
import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';

class _FakeCommunity extends ModelCommunity {
  _FakeCommunity(this.id, {this.fail = false, this.repos = const []});
  @override
  final String id;
  final bool fail;
  final List<RepoSummary> repos;
  int searchCalls = 0;

  @override
  Future<List<RepoSummary>> search(String query, {int limit = 20}) async {
    searchCalls++;
    if (fail) throw StateError('community down');
    return repos;
  }

  @override
  Future<List<ModelFileInfo>> listFiles(String repoId) async =>
      const [ModelFileInfo(path: 'a.gguf', size: 1)];

  @override
  String downloadUrl(String repoId, String filePath) => '$id://$repoId/$filePath';

  @override
  Future<void> downloadWithProgress({
    required String url,
    required int startFrom,
    required dynamic cancelToken,
    required void Function(int received, int total) onProgress,
    required void Function(List<int> bytes) onChunk,
    int? endByte,
  }) async {}
}

void main() {
  group('HuggingFaceClient 解析（fixture，无网络）', () {
    test('parseSearch：GGUF tag/id 过滤 + 下载量解析', () {
      final repos = HuggingFaceClient.parseSearch([
        {
          'id': 'Qwen/Qwen3-1.7B-GGUF',
          'downloads': 144910,
          'tags': ['gguf'],
        },
        {
          'id': 'some/PlainModel',
          'downloads': 999,
          'tags': ['text-generation'],
        },
        {
          'id': 'mradermacher/Foo-GGUF',
          'downloads': 630,
          'tags': ['text-generation'],
        },
      ]);
      expect(repos.map((r) => r.repoId).toList(),
          ['Qwen/Qwen3-1.7B-GGUF', 'mradermacher/Foo-GGUF']);
      expect(repos.first.downloads, 144910);
      expect(repos.first.communityId, 'huggingface');
    });

    test('parseTree：LFS 大小优先于占位 size，目录被滤除', () {
      final files = HuggingFaceClient.parseTree([
        {'type': 'file', 'path': 'm.gguf', 'size': 100,
         'lfs': {'size': 1834426016}},
        {'type': 'directory', 'path': 'x'},
      ]);
      expect(files, hasLength(1));
      expect(files.first.size, 1834426016);
      expect(files.first.isLfs, isTrue);
    });

    test('downloadUrl 默认走镜像 host', () {
      final dio0 = HuggingFaceClient();
      expect(dio0.downloadUrl('a/b', 'c.gguf'),
          startsWith('https://hf-mirror.com/a/b/resolve/main/'));
    });
  });

  group('ModelCenterService 双社区搜索', () {
    test('并行合并 + 按 repoId 去重保留高下载量 + 降序', () async {
      final service = ModelCenterService({
        'a': _FakeCommunity('a', repos: [
          const RepoSummary(communityId: 'a', repoId: 'org/dupe', downloads: 10),
          const RepoSummary(communityId: 'a', repoId: 'org/onlyA', downloads: 5),
        ]),
        'b': _FakeCommunity('b', repos: [
          const RepoSummary(communityId: 'b', repoId: 'org/dupe', downloads: 99),
          const RepoSummary(communityId: 'b', repoId: 'org/onlyB', downloads: 1),
        ]),
      });

      final merged = await service.searchAll('q');
      expect(merged.map((r) => r.repoId).toList(),
          ['org/dupe', 'org/onlyA', 'org/onlyB']);
      expect(merged.first.communityId, 'b');
    });

    test('单社区失败静默降级，另一社区结果不受影响', () async {
      final service = ModelCenterService({
        'down': _FakeCommunity('down', fail: true),
        'ok': _FakeCommunity('ok', repos: [
          const RepoSummary(communityId: 'ok', repoId: 'org/x', downloads: 7),
        ]),
      });

      final merged = await service.searchAll('q');
      expect(merged.map((r) => r.repoId), ['org/x']);
    });

    test('listGgufAnywhere 返回首个命中社区', () async {
      final service = ModelCenterService({
        'a': _FakeCommunity('a'),
        'b': _FakeCommunity('b'),
      });
      final hit = await service.listGgufAnywhere('org/repo');
      expect(hit.communityId, 'a');
      expect(hit.files.first.path, 'a.gguf');
    });
  });

  group('下载任务 key 社区前缀', () {
    test('DownloadTask key 含社区 id（跨社区同仓库不撞 key）', () {
      final t1 = DownloadTask(
        communityId: 'modelscope',
        key: 'modelscope:org/r/f.gguf',
        repoId: 'org/r',
        filePath: 'f.gguf',
        totalBytes: 1,
      );
      final t2 = DownloadTask(
        communityId: 'huggingface',
        key: 'huggingface:org/r/f.gguf',
        repoId: 'org/r',
        filePath: 'f.gguf',
        totalBytes: 1,
      );
      expect(t1.key, isNot(t2.key));
      expect(t1.key.startsWith('modelscope:'), isTrue);
    });
  });

  group('自动建档（安装）幂等', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppDatabase.resetInstanceForTest();
      db = await AppDatabase.openForTest(
          await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath));
    });

    tearDown(() async {
      await db.db.close();
      AppDatabase.resetInstanceForTest();
    });

    test('ensureLocalProfileForFile：首次建档，同路径幂等', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsProvider.overrideWithValue(AppSettings(prefs)),
        llmProfilesProvider.overrideWith((ref) => LlmProfilesController(
              ref.watch(llmProfileStoreProvider),
              ref.watch(appSettingsProvider),
            )),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(llmProfilesProvider.notifier);

      expect(
        await controller.ensureLocalProfileForFile(r'C:\m\a.gguf', 'a'),
        isTrue,
      );
      expect(
        await controller.ensureLocalProfileForFile(r'C:\m\a.gguf', 'a'),
        isFalse,
        reason: '同一路径二次安装不应重复建档',
      );
      final profiles =
          await container.read(llmProfileStoreProvider).list();
      expect(profiles.where((p) => p.modelPath == r'C:\m\a.gguf'),
          hasLength(1));
    });
  });
}
