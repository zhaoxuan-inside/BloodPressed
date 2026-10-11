/// 门槛问答控制器行为测试：≥90 答案入库、<90 拒答入库、异常转错误态、
/// 门槛指令注入。真实模型生成属真机冒烟范畴。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';
import 'package:blood_pressed/features/assistant/domain/gated_answer.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late AppDatabase db;
  late ChatRepository chatRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDatabase.resetInstanceForTest();
    db = await AppDatabase.openForTest(
        await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath));
    chatRepo = ChatRepository(db);
  });

  tearDown(() async {
    await db.db.close();
    AppDatabase.resetInstanceForTest();
  });

  Future<(AssistantController, List<List<ChatMessage>>)> controller({
    required Map<String, Object?> Function(List<ChatMessage>, int)? reply,
  }) async {
    final captured = <List<ChatMessage>>[];
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    // 预置一份远端用户档案并预激活（无网络副作用），让 ensureReady 直接就绪
    const remoteProfile = LlmProfile(
      id: 'remote-1',
      kind: LlmKind.remote,
      name: '远端',
      config: {'baseUrl': 'https://api.x.com', 'model': 'm'},
    );
    await LlmProfileStore(db).upsert(remoteProfile);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appSettingsProvider.overrideWithValue(settings),
      llmProfilesProvider.overrideWith((ref) => LlmProfilesController(
            LlmProfileStore(db),
            settings,
          )),
      activeLlmProfileIdProvider.overrideWith((ref) => remoteProfile.id),
      builtinModelReadyProvider.overrideWith((ref) => false),
      llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
      // 门槛开关独立覆写：即便引擎挂的是远端档案，门槛分支也强制生效
      isBuiltinActiveProvider.overrideWith((ref) => true),
    ]);
    addTearDown(container.dispose);
    await container.read(llmProfilesProvider.notifier).refresh();
    await container.read(llmEngineProvider.notifier).activate(remoteProfile);
    final controller = AssistantController(
      chatRepo,
      HealthContextBuilder(
          RecordsRepository(db, OutboxDao(db))),
      container.read,
      gatedChatOverride: reply == null
          ? null
          : (messages, maxTokens) {
              captured.add(messages);
              return Future.value(reply(messages, maxTokens));
            },
    );
    await Future<void>.delayed(Duration.zero); // 等 _load 完成
    return (controller, captured);
  }

  test('置信度 ≥90：答案入库，sending 复位', () async {
    final (c, _) = await controller(
      reply: (messages, maxTokens) =>
          {'answer': '建议低盐饮食、规律作息。', 'confidence': 95},
    );

    await c.send('我该注意什么？');

    expect(c.state.sending, isFalse);
    expect(c.state.error, isNull);
    expect(c.state.messages.last.role, ChatRole.assistant);
    expect(c.state.messages.last.content, '建议低盐饮食、规律作息。');
  });

  test('置信度 <90：拒答文案入库', () async {
    final (c, _) = await controller(
      reply: (messages, maxTokens) =>
          {'answer': '可能是心律问题', 'confidence': 40},
    );

    await c.send('我是不是有心脏病？');

    expect(c.state.sending, isFalse);
    expect(c.state.messages.last.role, ChatRole.assistant);
    expect(c.state.messages.last.content, AppLocaleService.auto.gatedRefusal);
  });

  test('解析失败（空答案）：按拒答处理', () async {
    final (c, _) = await controller(
      reply: (messages, maxTokens) => {'answer': '', 'confidence': 99},
    );

    await c.send('任意问题');

    expect(c.state.messages.last.content, AppLocaleService.auto.gatedRefusal);
  });

  test('门槛出口抛错：转错误态且不入库', () async {
    final (c, _) = await controller(
      reply: (messages, maxTokens) => throw const InferenceException('模型炸了'),
    );

    await c.send('任意问题');

    expect(c.state.sending, isFalse);
    expect(c.state.error, isNotNull);
    final assistantMsgs = c.state.messages
        .where((m) => m.role == ChatRole.assistant)
        .toList();
    expect(assistantMsgs, isEmpty);
  });

  test('系统提示注入门槛输出指令，历史裁剪到最近 8 条', () async {
    // 先播种 20 条历史，控制器构造时加载
    for (var i = 0; i < 10; i++) {
      await chatRepo.append(ChatRole.user, '历史问题 $i');
      await chatRepo.append(ChatRole.assistant, '历史回答 $i');
    }
    final (c, captured) = await controller(
      reply: (messages, maxTokens) =>
          {'answer': 'ok', 'confidence': 91},
    );

    await c.send('新问题');
    expect(captured, hasLength(1));
    final sent = captured.first;
    expect(sent.first.role, ChatRole.system);
    expect(sent.first.content, contains('confidence'));
    // system + 最近 8 条（含本次新消息）
    expect(sent.length, 1 + kGatedHistoryLimit);
    expect(sent.last.content, '新问题');
  });
}
