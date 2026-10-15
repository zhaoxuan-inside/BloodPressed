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
