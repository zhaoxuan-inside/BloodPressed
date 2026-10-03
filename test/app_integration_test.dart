/// 端到端 UI 集成测试：真实 App 界面 + 内存假数据层。
///
/// 说明：sqflite_common_ffi 的 isolate 回调在 testWidgets 的 FakeAsync 时区中
/// 无法交付（纯 test() 中正常，见 records_repository_test.dart），
/// 因此本文件以内存实现的仓库注入替代数据库层，专注验证真实 UI 链路：
/// 手动录入 → 首页展示 → 编辑 → 删除 → 趋势图 → 知识阅读 →
/// AI 助手引导 → 设置页 → 导出页 → AI 模型页 → 魔搭市场页 → OCR 确认表单。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:blood_pressed/app.dart';
import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/router/app_router.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';

// ---------------- 内存假数据层 ----------------

/// 内存记录仓库（接口与真实仓库一致，不触碰 SQLite）。
class FakeRecordsRepository extends RecordsRepository {
  FakeRecordsRepository(AppDatabase db) : super(db, OutboxDao(db));

  final List<BpRecord> store = [];

  @override
  Future<List<BpRecord>> list({
    DateTime? from,
    DateTime? to,
    MeasureArm? arm,
    bool includeDeleted = false,
    int? limit,
  }) async {
    var rows = store.where((r) => includeDeleted || !r.isDeleted).toList();
    if (from != null) {
      rows = rows.where((r) => !r.measuredAt.isBefore(from)).toList();
    }
    if (to != null) {
      rows = rows.where((r) => !r.measuredAt.isAfter(to)).toList();
    }
    if (arm != null) {
      rows = rows.where((r) => r.arm == arm).toList();
    }
    rows.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return rows;
  }

  @override
  Future<BpRecord?> byId(String id) async {
    for (final r in store) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<BpRecord> latest() async => store.first;

  @override
  Future<bool> existsAny() async => store.isNotEmpty;

  @override
  Future<BpRecord> create(BpRecord record) async {
    store.add(record);
    return record;
  }

  @override
  Future<BpRecord> update(BpRecord record) async {
    final i = store.indexWhere((r) => r.id == record.id);
    if (i >= 0) store[i] = record;
    return record;
  }

  @override
  Future<void> softDelete(String id, {required String deviceId}) async {
    final i = store.indexWhere((r) => r.id == id);
    if (i >= 0) {
      final now = DateTime.now();
      store[i] = store[i].copyWith(deletedAt: now, updatedAt: now);
    }
  }

  @override
  Future<BpStats> stats({DateTime? from, DateTime? to, MeasureArm? arm}) async {
    final rows = await list(from: from, to: to, arm: arm);
    return BpStats.compute(rows);
  }
}

/// 内存会话仓库。
class FakeChatRepository extends ChatRepository {
  FakeChatRepository(super.db);

  final List<ChatMessage> messages = [];

  @override
  Future<List<ChatMessage>> history({int limit = 200}) async =>
      List.of(messages);

  @override
  Future<ChatMessage> append(ChatRole role, String content) async {
    final m = ChatMessage(
      id: 'fake-${messages.length}',
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
    messages.add(m);
    return m;
  }

  @override
  Future<void> clear() async => messages.clear();
}

/// 内存 LLM 配置仓库。
class FakeLlmProfileStore extends LlmProfileStore {
  FakeLlmProfileStore(super.db);

  final Map<String, LlmProfile> profiles = {};

  @override
  Future<List<LlmProfile>> list() async => profiles.values.toList();

  @override
  Future<void> upsert(LlmProfile profile) async =>
      profiles[profile.id] = profile;

  @override
  Future<void> delete(String id) async => profiles.remove(id);
}

// ---------------- 测试主体 ----------------

void main() {
  late AppDatabase wiringDb;
  late AppSettings settings;
  late SharedPreferences prefs;
  late FakeRecordsRepository fakeRecords;
  late FakeChatRepository fakeChat;
  late FakeLlmProfileStore fakeProfiles;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = AppSettings(prefs);
    await settings.deviceId();

    // 仅用于构造注入的底层对象（假数据层不会真正触碰数据库）
    wiringDb = await AppDatabase.openForTest(
        await databaseFactory.openDatabase(inMemoryDatabasePath));
    fakeRecords = FakeRecordsRepository(wiringDb);
    fakeChat = FakeChatRepository(wiringDb);
    fakeProfiles = FakeLlmProfileStore(wiringDb);
  });

  tearDown(() async {
    await wiringDb.db.close();
    AppDatabase.resetInstanceForTest();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final s = AppSettings(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appSettingsProvider.overrideWithValue(s),
          recordsRepositoryProvider.overrideWithValue(fakeRecords),
          chatRepositoryProvider.overrideWithValue(fakeChat),
          llmProfileStoreProvider.overrideWithValue(fakeProfiles),
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
              .overrideWith((ref) => s.activeLlmProfileId),
          themeModeNameProvider.overrideWith((ref) => s.themeMode),
        ],
        child: BloodPressedApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 填写录入表单并保存（新增与编辑共用）。
  Future<void> fillAndSave(
    WidgetTester tester, {
    required String sys,
    required String dia,
    String? pulse,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, '高压（收缩压）').first,
      sys,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '低压（舒张压）').first,
      dia,
    );
    if (pulse != null) {
      await tester.enterText(
        find.widgetWithText(TextField, '脉搏（可选）').first,
        pulse,
      );
    }
    final saveBtn = find.text('保存记录').evaluate().isNotEmpty
        ? find.text('保存记录')
        : find.text('保存修改');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
  }

  BpRecord makeRecord(int sys, int dia, {int? pulse}) {
    final now = DateTime.now();
    return BpRecord(
      id: 'r-$sys-$dia-${now.microsecondsSinceEpoch}',
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      measuredAt: now,
      arm: MeasureArm.left,
      source: RecordSource.manual,
      deviceId: 'test',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('完整链路：欢迎页 → 手动录入 → 首页展示与分级 → 编辑 → 趋势图',
      (tester) async {
    await pumpApp(tester);

    // 1. 空库欢迎状态
    expect(find.text('👋 欢迎使用 BloodPressed'), findsOneWidget);
    expect(find.text('还没有血压记录'), findsOneWidget);

    // 2. FAB → 底部菜单 → 手动录入
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('拍照识别'), findsWidgets);
    await tester.tap(find.text('手动录入').last);
    await tester.pumpAndSettle();

    // 3. 填表保存：128/84 → 正常高值
    await fillAndSave(tester, sys: '128', dia: '84', pulse: '72');

    // 4. 回到首页：记录卡片出现（128/84 属于"正常"）
    expect(find.text('128/84'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
    expect(find.text('72 次/分'), findsOneWidget);

    // 5. 编辑：改成 145/95 → 轻度升高
    await tester.tap(find.text('128/84'));
    await tester.pumpAndSettle();
    expect(find.text('编辑记录'), findsOneWidget);
    await fillAndSave(tester, sys: '145', dia: '95', pulse: '78');

    expect(find.text('145/95'), findsOneWidget);
    expect(find.text('轻度升高'), findsWidgets);

    // 6. 趋势页：统计卡片与折线图渲染
    await tester.tap(find.byIcon(Icons.show_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('血压趋势'), findsOneWidget);
    expect(find.text('平均高压'), findsOneWidget);
    expect(find.text('平均低压'), findsOneWidget);
  });

  testWidgets('删除记录（左滑 → 确认）', (tester) async {
    await pumpApp(tester);

    // 先录一条
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动录入').last);
    await tester.pumpAndSettle();
    await fillAndSave(tester, sys: '120', dia: '80');
    expect(find.text('120/80'), findsOneWidget);

    // 左滑删除 → 确认对话框 → 删除
    await tester.drag(find.text('120/80'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('120/80'), findsNothing);
    expect(find.text('还没有血压记录'), findsOneWidget);
  });

  testWidgets('知识阅读：列表 → 详情 → 收藏', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(find.text('健康知识'), findsOneWidget);
    expect(find.text('在家如何正确测量血压？'), findsOneWidget);

    await tester.tap(find.text('在家如何正确测量血压？'));
    await tester.pumpAndSettle();
    expect(find.text('测量方法'), findsOneWidget);
    expect(find.textContaining('测量前 30 分钟'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('AI 助手：未配置模型时显示引导', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.smart_toy_outlined));
    await tester.pumpAndSettle();
    expect(find.text('尚未配置 AI 模型'), findsOneWidget);
    expect(find.text('去配置模型'), findsOneWidget);
  });

  testWidgets('我的页：全部入口可见 → 云同步占位 → AI 模型页 → 魔搭市场',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('AI 模型配置'), findsOneWidget);
    expect(find.text('导出与分享'), findsOneWidget);
    expect(find.text('云同步'), findsOneWidget);
    expect(find.text('默认测量臂'), findsOneWidget);

    // 云同步占位页（顶部可见区域直接点入）
    await tester.tap(find.text('云同步'));
    await tester.pumpAndSettle();
    expect(find.text('未开启'), findsOneWidget);
    expect(find.textContaining('云平台接入'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // AI 模型页 → 魔搭市场
    await tester.tap(find.text('AI 模型配置'));
    await tester.pumpAndSettle();
    expect(find.text('尚未配置任何模型'), findsOneWidget);
    expect(find.text('从魔搭社区安装模型'), findsOneWidget);
    expect(find.text('添加远端模型 API'), findsOneWidget);

    await tester.tap(find.text('从魔搭社区安装模型'));
    await tester.pumpAndSettle();
    expect(find.text('魔搭模型市场'), findsOneWidget);
    expect(find.text('Qwen3 0.6B'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('其他仓库'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('其他仓库'), findsOneWidget);
    expect(find.text('Qwen2.5 3B Instruct'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 折叠线以下的内容需要滚动（ListView 懒加载，放到最后验证）
    await tester.scrollUntilVisible(
      find.text('免责声明'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('免责声明'), findsOneWidget);
  });

  testWidgets('导出与分享页：记录卡预览与 CSV 入口', (tester) async {
    fakeRecords.store.add(makeRecord(132, 86, pulse: 75));
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出与分享'));
    await tester.pumpAndSettle();

    expect(find.text('卡片分享'), findsOneWidget);
    expect(find.text('单次记录卡'), findsOneWidget);
    expect(find.text('BloodPressed · 血压记录'), findsOneWidget);
    expect(find.text('微信好友'), findsOneWidget);
    expect(find.text('导出全部记录为 CSV（Excel 可打开）'), findsOneWidget);

    // 切换统计卡
    await tester.tap(find.text('统计摘要卡'));
    await tester.pumpAndSettle();
    expect(find.text('BloodPressed · 血压周报'), findsOneWidget);
  });

  testWidgets('OCR 识别确认表单：预填 + 来源标记 + 保存', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appSettingsProvider.overrideWithValue(settings),
          recordsRepositoryProvider.overrideWithValue(fakeRecords),
        ],
        child: MaterialApp(
          home: RecordEditPage(
            initialSystolic: 145,
            initialDiastolic: 95,
            initialPulse: 88,
            initialSource: RecordSource.ocr,
            initialConfidence: 0.82,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('拍照识别结果'), findsOneWidget);
    expect(find.textContaining('82%'), findsOneWidget);
    expect(find.textContaining('轻度升高'), findsOneWidget);

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(fakeRecords.store, hasLength(1));
    expect(fakeRecords.store.first.systolic, 145);
    expect(fakeRecords.store.first.source, RecordSource.ocr);
  });
}
