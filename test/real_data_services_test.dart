/// 非 UI 的真实数据测试：SQLite 仓库、内置知识 assets、健康上下文、
/// CSV 导出、远端推理端点（真实 HTTP，无 mock 响应）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';
import 'package:blood_pressed/features/camera_ocr/data/image_utils.dart';
import 'package:blood_pressed/features/export/data/csv_exporter.dart';
import 'package:blood_pressed/features/knowledge/data/knowledge_repository.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/data/remote_chat_engine.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/features/sync/data/local_only_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late RecordsRepository records;
  late OutboxDao outbox;

  setUp(() async {
    AppDatabase.resetInstanceForTest();
    db = await AppDatabase.openForTest(
        await databaseFactory.openDatabase(inMemoryDatabasePath));
    outbox = OutboxDao(db);
    records = RecordsRepository(db, outbox);
  });

  tearDown(() async {
    await db.db.close();
    AppDatabase.resetInstanceForTest();
  });

  Future<BpRecord> add({
    required int sys,
    required int dia,
    int? pulse,
    DateTime? at,
    MeasureArm arm = MeasureArm.left,
  }) {
    final now = DateTime.now();
    return records.create(BpRecord(
      id: 'r-$sys-$dia-${now.microsecondsSinceEpoch}',
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      measuredAt: at ?? now,
      arm: arm,
      source: RecordSource.manual,
      deviceId: 'svc-test',
      createdAt: now,
      updatedAt: now,
    ));
  }

  group('健康知识真实 assets', () {
    test('13 篇文章均可从 bundle 读出非空 Markdown', () async {
      const repo = KnowledgeRepository();
      expect(KnowledgeArticle.all, hasLength(13));
      expect(KnowledgeArticle.categories, hasLength(4));
      for (final article in KnowledgeArticle.all) {
        final body = await repo.loadContent(article);
        expect(body.trim(), isNotEmpty, reason: article.assetPath);
        expect(body, contains(RegExp(r'[#\-\w\u4e00-\u9fff]')));
      }
    });
  });

  group('LLM 配置与会话真实 SQLite', () {
    test('远端档案 upsert / 查询 / 删除', () async {
      final store = LlmProfileStore(db);
      final profile = LlmProfile(
        id: 'p1',
        kind: LlmKind.remote,
        name: 'DeepSeek',
        config: {
          'baseUrl': 'https://api.deepseek.com/v1',
          'apiKey': 'sk-test',
          'model': 'deepseek-chat',
          'multimodal': false,
        },
      );
      await store.upsert(profile);
      final listed = await store.list();
      expect(listed, hasLength(1));
      expect(listed.first.remoteModel, 'deepseek-chat');
      expect((await store.byId('p1'))!.name, 'DeepSeek');
      await store.delete('p1');
      expect(await store.list(), isEmpty);
    });

    test('聊天记录追加、读取、清空', () async {
      final chat = ChatRepository(db);
      await chat.append(ChatRole.user, '最近血压怎么样');
      await chat.append(ChatRole.assistant, '先保持规律测量。');
      final history = await chat.history();
      expect(history, hasLength(2));
      expect(history.first.role, ChatRole.user);
      expect(history.last.content, contains('规律测量'));
      await chat.clear();
      expect(await chat.history(), isEmpty);
    });
  });

  group('健康上下文与导出', () {
    test('近 30 天摘要包含均值、达标率与双臂对比', () async {
      final now = DateTime.now();
      await add(sys: 120, dia: 78, pulse: 70, at: now, arm: MeasureArm.left);
      await add(
          sys: 138, dia: 88, pulse: 76, at: now, arm: MeasureArm.right);
      final prompt = await HealthContextBuilder(records).buildSystemPrompt();
      expect(prompt, contains('测量次数：2 次'));
      expect(prompt, contains('家庭自测达标率'));
      expect(prompt, contains('左臂平均'));
      expect(prompt, contains('右臂平均'));
    });

    test('CSV 从仓库真实记录生成且含 BOM', () async {
      await add(sys: 132, dia: 86, pulse: 75);
      const exporter = CsvExporter();
      final csv = exporter.buildCsv(await records.list());
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('132,86,75'));
      expect(csv, contains('左臂'));
    });

    test('趋势按天聚合来自真实记录', () async {
      final now = DateTime.now();
      await add(sys: 120, dia: 80, pulse: 70, at: now);
      await add(
        sys: 130,
        dia: 84,
        pulse: 74,
        at: now.subtract(const Duration(days: 1)),
      );
      final points = DayPoint.aggregate(await records.list(), 7);
      expect(points, hasLength(2));
      expect(points.last.avgSystolic, 120);
    });

    test('无记录时健康上下文引导先测量', () async {
      final prompt = await HealthContextBuilder(records).buildSystemPrompt();
      expect(prompt, contains('暂无记录'));
      expect(prompt, contains('用中文回答'));
    });
  });

  group('设置、同步占位、格式化、图片压缩', () {
    test('AppSettings 真实键值读写', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance());
      final id = await settings.deviceId();
      expect(id, isNotEmpty);
      expect(await settings.deviceId(), id);

      await settings.setDefaultArm(MeasureArm.right);
      expect(settings.defaultArm, MeasureArm.right);
      await settings.setThemeMode('dark');
      expect(settings.themeMode, 'dark');
      await settings.setReminderEnabled(true);
      await settings.setReminderTime(7, 30);
      expect(settings.reminderEnabled, isTrue);
      expect(settings.reminderHour, 7);
      expect(settings.reminderMinute, 30);
      await settings.toggleFavorite('measure-guide');
      expect(settings.isFavorite('measure-guide'), isTrue);
      await settings.toggleFavorite('measure-guide');
      expect(settings.isFavorite('measure-guide'), isFalse);
      await settings.setKnowledgeFontScale(1.25);
      expect(settings.knowledgeFontScale, closeTo(1.25, 0.001));
    });

    test('LocalOnlySyncService 未开启且 push/pull 拒绝', () async {
      const sync = LocalOnlySyncService();
      expect(sync.enabled, isFalse);
      expect(sync.syncing, isFalse);
      await expectLater(sync.push(const []), throwsUnsupportedError);
      await expectLater(sync.pull(null), throwsUnsupportedError);
    });

    test('Outbox 取出后可按 id 删除', () async {
      await add(sys: 118, dia: 76);
      expect(await outbox.count(), 1);
      final entries = await outbox.take(10);
      await outbox.deleteByIds([entries.first.id]);
      expect(await outbox.count(), 0);
    });

    test('Fmt 日期与文件大小', () {
      final today = DateTime.now();
      expect(Fmt.friendlyDay(today), '今天');
      expect(Fmt.friendlyDay(today.subtract(const Duration(days: 1))), '昨天');
      expect(Fmt.bytes(512), '512 B');
      expect(Fmt.bytes(2048), contains('KB'));
    });

    test('ImageUtils 压缩真实 JPEG 像素', () async {
      final dir = await Directory.systemTemp.createTemp('bp_img');
      addTearDown(() => dir.delete(recursive: true));
      final image = img.Image(width: 1600, height: 1200);
      img.fill(image, color: img.ColorRgb8(40, 80, 120));
      final src = File('${dir.path}/bp.jpg')
        ..writeAsBytesSync(img.encodeJpg(image, quality: 95));
      final compressed = await ImageUtils.compressForAi(src.path, maxSide: 640);
      final decoded = img.decodeJpg(compressed);
      expect(decoded, isNotNull);
      expect(decoded!.width, 640);
      expect(decoded.height, 480);
      expect(compressed.length, lessThan(src.lengthSync()));
    });

    test('CSV exportToFile 写入临时目录真实文件', () async {
      final dir = await Directory.systemTemp.createTemp('bp_csv');
      addTearDown(() => dir.delete(recursive: true));
      PathProviderPlatform.instance = _TempPathProvider(dir.path);
      await add(sys: 124, dia: 81, pulse: 69);
      final file = await const CsvExporter().exportToFile(await records.list());
      expect(file.existsSync(), isTrue);
      // 新版 Dart 的 utf8 解码会剥离行首 BOM，字节级断言才反映 Excel 看到的内容
      final bytes = file.readAsBytesSync();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final text = file.readAsStringSync();
      expect(text, contains('124,81,69'));
    });
  });

  group('远端推理真实 HTTP', () {
    test('魔搭推理 GET /models 对无效 Token 返回真实错误', () async {
      final engine = RemoteChatEngine(const LlmProfile(
        id: 'live',
        kind: LlmKind.remote,
        name: 'modelscope',
        config: {
          'baseUrl': 'https://api-inference.modelscope.cn/v1',
          'apiKey': 'invalid-token-bloodpressed-test',
          'model': 'Qwen/Qwen3-32B',
        },
      ));
      addTearDown(engine.dispose);
      await expectLater(
        engine.listModels(),
        throwsA(isA<InferenceException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('无效 Token 流式对话返回真实服务端错误', () async {
      final engine = RemoteChatEngine(const LlmProfile(
        id: 'live-chat',
        kind: LlmKind.remote,
        name: 'modelscope',
        config: {
          'baseUrl': 'https://api-inference.modelscope.cn/v1',
          'apiKey': 'invalid-token-bloodpressed-test',
          'model': 'Qwen/Qwen3-32B',
        },
      ));
      addTearDown(engine.dispose);
      await expectLater(
        engine
            .chatStream([
              ChatMessage(
                id: 'u1',
                role: ChatRole.user,
                content: '用一句话说明家庭自测血压达标标准',
                createdAt: DateTime.now(),
              ),
            ])
            .toList(),
        throwsA(isA<InferenceException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('配置了真实 Token 时可拉取模型列表', () async {
      final token = Platform.environment['MODELSCOPE_SDK_TOKEN'] ??
          Platform.environment['DASHSCOPE_API_KEY'] ??
          '';
      if (token.isEmpty) {
        return;
      }
      final isDash = Platform.environment['DASHSCOPE_API_KEY']?.isNotEmpty ==
          true;
      final engine = RemoteChatEngine(LlmProfile(
        id: 'env',
        kind: LlmKind.remote,
        name: 'env',
        config: {
          'baseUrl': isDash
              ? 'https://dashscope.aliyuncs.com/compatible-mode/v1'
              : 'https://api-inference.modelscope.cn/v1',
          'apiKey': token,
          'model': isDash ? 'qwen-plus' : 'Qwen/Qwen3-32B',
        },
      ));
      addTearDown(engine.dispose);
      final models = await engine.listModels();
      expect(models, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('配置了真实 Token 时可完成一轮健康指导对话', () async {
      final token = Platform.environment['MODELSCOPE_SDK_TOKEN'] ??
          Platform.environment['DASHSCOPE_API_KEY'] ??
          '';
      if (token.isEmpty) {
        return;
      }
      final isDash =
          Platform.environment['DASHSCOPE_API_KEY']?.isNotEmpty == true;
      final engine = RemoteChatEngine(LlmProfile(
        id: 'env-chat',
        kind: LlmKind.remote,
        name: 'env',
        config: {
          'baseUrl': isDash
              ? 'https://dashscope.aliyuncs.com/compatible-mode/v1'
              : 'https://api-inference.modelscope.cn/v1',
          'apiKey': token,
          'model': isDash ? 'qwen-plus' : 'Qwen/Qwen3-32B',
        },
      ));
      addTearDown(engine.dispose);
      final chunks = await engine
          .chatStream([
            ChatMessage(
              id: 'sys',
              role: ChatRole.system,
              content: '你是血压健康助手，用中文简短回答。',
              createdAt: DateTime.now(),
            ),
            ChatMessage(
              id: 'u',
              role: ChatRole.user,
              content: '家庭自测血压低于多少算达标？只回答数字阈值。',
              createdAt: DateTime.now(),
            ),
          ], maxTokens: 128)
          .toList();
      final text = chunks.join();
      expect(text.trim(), isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
