import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';

import 'daily_candle_test.dart' show reading;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    AppDatabase.resetInstanceForTest();
    db = await AppDatabase.openForTest(
      await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath),
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.db.close();
    AppDatabase.resetInstanceForTest();
  });

  test('仅注入基础存储即可装配设置、模型及助手', () async {
    expect(container.read(appSettingsProvider).themeMode, 'system');
    final profiles = container.read(llmProfilesProvider.notifier);
    await profiles.refresh();
    expect(container.read(llmProfilesProvider).requireValue, isEmpty);
    final profile = await profiles.addRemote(
      name: 'Test',
      baseUrl: 'https://example.com/v1',
      apiKey: '',
      model: 'test',
    );
    expect(
      container.read(llmProfilesProvider).requireValue.single.id,
      profile.id,
    );
    expect(container.read(llmEngineProvider).status, LlmEngineStatus.idle);
    final assistant = container.read(assistantProvider.notifier);
    await assistant.clearConversation();
    expect(container.read(assistantProvider).messages, isEmpty);
  });

  test('每日蜡烛图按自然日筛选，不混入前一天的测量', () async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final repo = container.read(recordsRepositoryProvider);
    await repo.create(
      reading(8, 150, 95, id: 'previous').copyWith(
        measuredAt: midnight.subtract(const Duration(milliseconds: 1)),
      ),
    );
    await repo.create(
      reading(8, 120, 80, id: 'today').copyWith(measuredAt: midnight),
    );
    await container.read(recordsControllerProvider.notifier).refresh();
    const query = TrendQuery(days: 1);
    final subscription = container.listen(trendDataProvider(query), (_, _) {});
    addTearDown(subscription.close);
    final candles = await container.read(trendDataProvider(query).future);
    expect(candles, hasLength(1));
    expect(candles.single.date, midnight);
    expect(candles.single.count, 1);
    expect(candles.single.systolic.maximum, 120);
    expect(
      (await container.read(statsProvider(const StatsRange(1, '')).future))
          .count,
      1,
    );
    expect(
      (await container.read(analysisDataProvider(query).future)).totalCount,
      1,
    );
  });

  test('自定义日期包含当天最后一毫秒，不包含翌日', () async {
    final end = DateTime(2026, 10, 16);
    final repo = container.read(recordsRepositoryProvider);
    await repo.create(reading(8, 120, 80, id: 'morning'));
    await repo.create(
      reading(
        20,
        145,
        90,
        id: 'last',
      ).copyWith(measuredAt: end.subtract(const Duration(milliseconds: 1))),
    );
    await repo.create(
      reading(8, 180, 110, id: 'next').copyWith(measuredAt: end),
    );
    await container.read(recordsControllerProvider.notifier).refresh();
    final query = TrendQuery.custom(
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 15),
    );
    final subscription = container.listen(trendDataProvider(query), (_, _) {});
    addTearDown(subscription.close);
    final candles = await container.read(trendDataProvider(query).future);
    expect(candles.single.count, 2);
    expect(candles.single.systolic.first, 120);
    expect(candles.single.systolic.last, 145);
    expect(candles.single.systolic.maximum, 145);
    expect(
      (await container.read(
        statsProvider(
          StatsRange.custom(DateTime(2026, 10, 15), DateTime(2026, 10, 15)),
        ).future,
      )).count,
      2,
    );
    expect(
      (await container.read(analysisDataProvider(query).future)).totalCount,
      2,
    );
  });

  test('分析随记录新增、编辑和删除自动刷新', () async {
    final query = TrendQuery.custom(
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 15),
    );
    final provider = analysisDataProvider(query);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(recordsControllerProvider.notifier);
    await controller.refresh();
    expect((await container.read(provider.future)).totalCount, 0);

    await controller.save(
      systolic: 120,
      diastolic: 80,
      measuredAt: DateTime(2026, 10, 15, 8),
      arm: MeasureArm.left,
    );
    expect((await container.read(provider.future)).totalCount, 1);
    final id = container.read(recordsControllerProvider).requireValue.single.id;

    await controller.save(
      systolic: 150,
      diastolic: 95,
      editId: id,
      measuredAt: DateTime(2026, 10, 15, 8),
      arm: MeasureArm.left,
    );
    expect((await container.read(provider.future)).peakRecord!.systolic, 150);
    await controller.delete(id);
    expect((await container.read(provider.future)).totalCount, 0);
  });
}
