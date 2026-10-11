/// 内置默认模型域单测：路径规则、virtual 档案、生效档案解析优先级、
/// 激活双写不变量（activateAndPersist）。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/domain/builtin_model.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

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

  String expectedBuiltinPath(String docsDir) {
    final sep = Platform.pathSeparator;
    return '$docsDir${sep}models${sep}Qwen_Qwen3-1.7B-GGUF'
        '$sep$kBuiltinFileName';
  }

  group('内置模型域模型', () {
    test('builtinModelFilePath 与下载服务落盘规则一致', () {
      final path = builtinModelFilePath(r'C:\docs');
      expect(path, expectedBuiltinPath(r'C:\docs'));
      expect(builtinDownloadKey(), 'Qwen/Qwen3-1.7B-GGUF/$kBuiltinFileName');
    });

    test('builtinProfile：固定 id、本地类型、可直用', () {
      final p = builtinProfile(expectedBuiltinPath(r'C:\docs'));
      expect(p.id, kBuiltinProfileId);
      expect(p.kind, LlmKind.local);
      expect(p.contextSize, 2048);
      expect(p.threads, 0);
      expect(p.usable, isTrue);
      expect(isBuiltinProfile(p), isTrue);
      expect(isBuiltinProfile(p.copyWithConfig({'modelPath': 'x'})), isTrue);
    });
  });

  group('生效档案解析', () {
    Future<ProviderContainer> container({
      String? activeId,
      required bool builtinReady,
    }) async {
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      if (activeId != null) await settings.setActiveLlmProfile(activeId);
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsProvider.overrideWithValue(settings),
        llmProfilesProvider.overrideWith((ref) => LlmProfilesController(
              ref.watch(llmProfileStoreProvider),
              ref.watch(appSettingsProvider),
            )),
        activeLlmProfileIdProvider.overrideWith((ref) => activeId),
        builtinModelPathProvider
            .overrideWith((ref) => expectedBuiltinPath(r'C:\docs')),
        builtinModelReadyProvider.overrideWith((ref) => builtinReady),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('用户激活档案优先于内置默认', () async {
      final store = LlmProfileStore(db);
      await store.upsert(const LlmProfile(
        id: 'user-1',
        kind: LlmKind.remote,
        name: '远端',
        config: {'baseUrl': 'https://api.x.com', 'model': 'm'},
      ));
      final c = await container(activeId: 'user-1', builtinReady: true);
      // 控制器构造时的 refresh() 是异步的，等待档案列表就绪
      await c.read(llmProfilesProvider.notifier).refresh();

      final effective = c.read(effectiveLlmProfileProvider);
      expect(effective?.id, 'user-1');
      expect(c.read(isBuiltinActiveProvider), isFalse);
    });

    test('无用户档案且内置就绪 → 生效档案为内置', () async {
      final c = await container(activeId: null, builtinReady: true);
      expect(c.read(effectiveLlmProfileProvider)?.id, kBuiltinProfileId);
      expect(c.read(isBuiltinActiveProvider), isTrue);
    });

    test('无用户档案且内置未就绪 → 无生效档案', () async {
      final c = await container(activeId: null, builtinReady: false);
      expect(c.read(effectiveLlmProfileProvider), isNull);
      expect(c.read(isBuiltinActiveProvider), isFalse);
    });

    test('激活档案 id 失效（档案被删）→ 回落内置', () async {
      final c = await container(activeId: 'ghost', builtinReady: true);
      expect(c.read(effectiveLlmProfileProvider)?.id, kBuiltinProfileId);
    });
  });

  group('activateAndPersist 双写不变量', () {
    Future<(ProviderContainer, List<String?>)> container() async {
      final captured = <String?>[];
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsProvider.overrideWithValue(settings),
        llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
      ]);
      addTearDown(c.dispose);
      return (c, captured);
    }

    test('成功：内存回调与持久化存储同时写入', () async {
      final (c, captured) = await container();
      final profile = const LlmProfile(
        id: 'remote-1',
        kind: LlmKind.remote,
        name: 'r',
        config: {'baseUrl': 'https://api.x.com', 'model': 'm'},
      );

      final err = await activateAndPersist(
        engine: c.read(llmEngineProvider.notifier),
        settings: c.read(appSettingsProvider),
        setActiveId: captured.add,
        profile: profile,
      );

      expect(err, isNull);
      expect(captured, ['remote-1']);
      expect(c.read(appSettingsProvider).activeLlmProfileId, 'remote-1');
    });

    test('失败（本地文件不存在）：返回错误且不写任何激活态', () async {
      final (c, captured) = await container();
      final profile = const LlmProfile(
        id: 'local-bad',
        kind: LlmKind.local,
        name: 'l',
        config: {'modelPath': 'Z:/no/such/model.gguf'},
      );

      final err = await activateAndPersist(
        engine: c.read(llmEngineProvider.notifier),
        settings: c.read(appSettingsProvider),
        setActiveId: captured.add,
        profile: profile,
      );

      expect(err, isNotNull);
      expect(captured, isEmpty);
      expect(c.read(appSettingsProvider).activeLlmProfileId, isNull);
    });
  });
}
