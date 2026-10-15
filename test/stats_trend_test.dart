/// 趋势四件套 seam 测试：分析 provider（真实 SQLite 数据流）、
/// 助手页消费 pending 分析请求（跳转自动发送）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';
import 'package:blood_pressed/features/assistant/presentation/assistant_page.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDatabase.resetInstanceForTest();
    db = await AppDatabase.openForTest(
      await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath),
    );
  });

  tearDown(() async {
    await db.db.close();
    AppDatabase.resetInstanceForTest();
  });

  Future<void> seed(BpRecord r) async {
    await RecordsRepository(db, OutboxDao(db)).create(r);
  }

  BpRecord rec(int hour, int sys, int dia, {DateTime? day}) {
    final base = day ?? DateTime(2026, 10, 5);
    final now = DateTime.now();
    return BpRecord(
      id: 'r-$hour-$sys-$dia-${base.millisecondsSinceEpoch}',
      systolic: sys,
      diastolic: dia,
      measuredAt: DateTime(base.year, base.month, base.day, hour, 30),
      arm: MeasureArm.left,
      source: RecordSource.manual,
      deviceId: 'test',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('analysisDataProvider', () {
    test('按查询范围与臂过滤分析原始记录', () async {
      await seed(rec(8, 142, 92)); // 清晨偏高（周一）
      await seed(rec(15, 118, 76)); // 下午正常
      // 右臂记录，不进左臂过滤结果
      await seed(
        BpRecord(
          id: 'r-right',
          systolic: 160,
          diastolic: 100,
          measuredAt: DateTime(2026, 10, 5, 8, 30),
          arm: MeasureArm.right,
          source: RecordSource.manual,
          deviceId: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final query = TrendQuery.custom(
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 5),
        arm: MeasureArm.left,
      );
      final analysis = await container.read(analysisDataProvider(query).future);

      expect(analysis.totalCount, 2);
      expect(analysis.buckets.first.bucket, TimeBucket.morning);
      expect(analysis.buckets.first.avgElevated, isTrue);
    });

    test('无数据时 isEmpty', () async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final query = TrendQuery.custom(
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 5),
      );
      final analysis = await container.read(analysisDataProvider(query).future);
      expect(analysis.isEmpty, isTrue);
    });
  });

  group('助手页消费 pending 分析请求', () {
    testWidgets('跳转后自动发送一次并清空 pending', (tester) async {
      const remoteProfile = LlmProfile(
        id: 'remote-1',
        kind: LlmKind.remote,
        name: '远端',
        config: {
          'baseUrl': 'https://api.x.com',
          'model': 'm',
          'recipientName': 'Test recipient',
          'recipientPolicyUrl': 'https://example.com/privacy',
          'recipientRegion': 'mainland',
        },
      );
      await LlmProfileStore(db).upsert(remoteProfile);
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      await settings.setActiveLlmProfile(remoteProfile.id);
      await settings.acceptPrivacy();
      await settings.allowRemote(remoteProfile);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsProvider.overrideWithValue(settings),
          llmProfilesProvider.overrideWith(
            (ref) => LlmProfilesController(
              ref.watch(llmProfileStoreProvider),
              ref.watch(appSettingsProvider),
            ),
          ),
          activeLlmProfileIdProvider.overrideWith((ref) => remoteProfile.id),
          builtinModelReadyProvider.overrideWith((ref) => false),
          isBuiltinActiveProvider.overrideWith((ref) => true),
          llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
          assistantProvider.overrideWith(
            (ref) => AssistantController(
              ChatRepository(db),
              HealthContextBuilder(RecordsRepository(db, OutboxDao(db))),
              ref.read,
              gatedChatOverride: (messages, maxTokens) async => {
                'answer': '分析结论',
                'confidence': 95,
              },
            ),
          ),
          pendingAssistantPromptProvider.overrideWith((ref) => '请分析我近7天的血压数据'),
        ],
      );
      await container.read(llmProfilesProvider.notifier).refresh();
      await container.read(llmEngineProvider.notifier).activate(remoteProfile);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: AssistantPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // pending 已清空；用户消息 + 门禁回答均入库到会话状态
      expect(container.read(pendingAssistantPromptProvider), isNull);
      final state = container.read(assistantProvider);
      expect(
        state.messages.map((m) => m.role).toList(),
        containsAll([ChatRole.user, ChatRole.assistant]),
      );
      expect(state.messages.last.content, '分析结论');
    });

    testWidgets('无 pending 时助手页不自动发送', (tester) async {
      const remoteProfile = LlmProfile(
        id: 'remote-1',
        kind: LlmKind.remote,
        name: '远端',
        config: {
          'baseUrl': 'https://api.x.com',
          'model': 'm',
          'recipientName': 'Test recipient',
          'recipientPolicyUrl': 'https://example.com/privacy',
          'recipientRegion': 'mainland',
        },
      );
      await LlmProfileStore(db).upsert(remoteProfile);
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      await settings.setActiveLlmProfile(remoteProfile.id);
      await settings.acceptPrivacy();
      await settings.allowRemote(remoteProfile);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsProvider.overrideWithValue(settings),
          llmProfilesProvider.overrideWith(
            (ref) => LlmProfilesController(
              ref.watch(llmProfileStoreProvider),
              ref.watch(appSettingsProvider),
            ),
          ),
          activeLlmProfileIdProvider.overrideWith((ref) => remoteProfile.id),
          builtinModelReadyProvider.overrideWith((ref) => false),
          isBuiltinActiveProvider.overrideWith((ref) => true),
          llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
          assistantProvider.overrideWith(
            (ref) => AssistantController(
              ChatRepository(db),
              HealthContextBuilder(RecordsRepository(db, OutboxDao(db))),
              ref.read,
              gatedChatOverride: (messages, maxTokens) async => {
                'answer': '不该出现',
                'confidence': 95,
              },
            ),
          ),
          pendingAssistantPromptProvider.overrideWith((ref) => null),
        ],
      );
      await container.read(llmProfilesProvider.notifier).refresh();
      await container.read(llmEngineProvider.notifier).activate(remoteProfile);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: AssistantPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container
            .read(assistantProvider)
            .messages
            .where((m) => m.role == ChatRole.user),
        isEmpty,
      );
    });
  });
}
