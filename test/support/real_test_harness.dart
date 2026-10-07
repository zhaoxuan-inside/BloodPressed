/// 真实数据测试装配：内存 SQLite（sqflite_ffi）+ 真实仓库实现。
///
/// SharedPreferences 使用 flutter_test 的内存后端（`setMockInitialValues`），
/// 这是测试进程里唯一可用的 prefs 实现，写入的仍是真实键值，不是业务假数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/app.dart';
import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/router/app_router.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';

/// 关闭 flutter_test 全局 HTTP 拦截，允许真实网络。
class RealNetworkWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// 必须在 `main()` 的第一行调用（每个测试文件各自一次）。
void installRealNetworkBinding() {
  RealNetworkWidgetsBinding();
}

void initSqfliteFfi() {
  sqfliteFfiInit();
  // 关键：使用主 isolate 的同步 FFI 实现（databaseFactoryFfiNoIsolate），
  // 避免跨 isolate 回包在 testWidgets 的 FakeAsync 时区中无法交付
  // （ FFQ isolate 版的回包依赖真实事件循环，testWidgets 中会永久挂起）。
  databaseFactory = databaseFactoryFfiNoIsolate;
}

/// 在真实事件循环中驱动帧，直到 [until] 成立或超时。
Future<void> pumpUntilReal(
  WidgetTester tester,
  bool Function() until, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  await tester.runAsync(() async {
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (until()) return;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  });
  await tester.pump();
}

/// 真实 SQLite + 真实仓库的应用测试夹具。
class RealAppHarness {
  late AppDatabase db;
  late SharedPreferences prefs;
  late AppSettings settings;
  late RecordsRepository records;
  late LlmProfileStore profiles;
  late ChatRepository chat;
  late OutboxDao outbox;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = AppSettings(prefs);
    await settings.deviceId();
    // 固定中文界面语言：测试宿主 platform locale 为 en_US，
    // 跟随系统会让存量中文断言全部失效
    await settings.setLocalePref('zh');

    AppDatabase.resetInstanceForTest();
    db = await AppDatabase.openForTest(
        await databaseFactory.openDatabase(inMemoryDatabasePath));
    outbox = OutboxDao(db);
    records = RecordsRepository(db, outbox);
    profiles = LlmProfileStore(db);
    chat = ChatRepository(db);
  }

  Future<void> tearDown() async {
    await db.db.close();
    AppDatabase.resetInstanceForTest();
  }

  List<Override> get overrides => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appSettingsProvider.overrideWithValue(settings),
        appDatabaseProvider.overrideWithValue(db),
        llmProfilesProvider.overrideWith((ref) => LlmProfilesController(
              ref.watch(llmProfileStoreProvider),
              ref.watch(appSettingsProvider),
            )),
        llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
        assistantProvider.overrideWith((ref) => AssistantController(
              ref.watch(chatRepositoryProvider),
              HealthContextBuilder(ref.watch(recordsRepositoryProvider)),
              ref,
            )),
        activeLlmProfileIdProvider
            .overrideWith((ref) => settings.activeLlmProfileId),
        themeModeNameProvider.overrideWith((ref) => settings.themeMode),
        localePrefProvider.overrideWith((ref) => settings.localePref),
      ];

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: BloodPressedApp(router: buildAppRouter()),
      ),
    );
    await pumpUntilReal(
      tester,
      () => tester.any(find.byType(NavigationBar)),
    );
  }

  Future<BpRecord> insertRecord({
    required int sys,
    required int dia,
    int? pulse,
    DateTime? at,
    MeasureArm arm = MeasureArm.left,
    MeasurePosture? posture,
    String? note,
    RecordSource source = RecordSource.manual,
  }) {
    final now = DateTime.now();
    return records.create(BpRecord(
      id: 'r-$sys-$dia-${now.microsecondsSinceEpoch}',
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      measuredAt: at ?? now,
      arm: arm,
      posture: posture,
      note: note,
      source: source,
      deviceId: 'test-device',
      createdAt: now,
      updatedAt: now,
    ));
  }
}
