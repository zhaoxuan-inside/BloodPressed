/// 全功能 UI 集成测试：真实 SQLite 仓库 + 真实 assets，无业务层假数据。
///
/// sqflite_ffi 的 isolate 回包必须在真实事件循环中交付，因此本文件
/// 使用 [RealNetworkWidgetsBinding] + [pumpUntilReal]（同魔搭页测试）。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';

import 'support/real_test_harness.dart';

void main() {
  installRealNetworkBinding();
  initSqfliteFfi();

  late RealAppHarness app;

  setUp(() async {
    app = RealAppHarness();
    await app.setUp();
  });

  tearDown(() async {
    await app.tearDown();
  });

  Future<void> fillAndSave(
    WidgetTester tester, {
    required String sys,
    required String dia,
    String? pulse,
    String? note,
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
    if (note != null) {
      await tester.enterText(
        find.widgetWithText(TextField, '备注（可选，如运动后、服药前）'),
        note,
      );
    }
    final saveBtn = find.text('保存记录').evaluate().isNotEmpty
        ? find.text('保存记录')
        : find.text('保存修改');
    await tester.tap(saveBtn);
    await pumpUntilReal(
      tester,
      () => !tester.any(find.text('保存记录')) &&
          !tester.any(find.text('保存修改')),
    );
  }

  testWidgets('完整链路：欢迎页 → 手动录入 → 首页展示与分级 → 编辑 → SQLite 落盘',
      (tester) async {
    await app.pumpApp(tester);

    expect(find.text('👋 欢迎使用 BloodPressed'), findsOneWidget);
    expect(find.text('还没有血压记录'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('拍照识别'), findsWidgets);
    await tester.tap(find.text('手动录入').last);
    await pumpUntilReal(tester, () => tester.any(find.text('录入血压')));

    await tester.tap(find.text('右臂').last);
    await tester.pump();
    await tester.tap(find.text('未记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('坐位').last);
    await tester.pumpAndSettle();

    await fillAndSave(tester, sys: '128', dia: '84', pulse: '72', note: '晨起');

    expect(find.text('128/84'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
    expect(find.text('72 次/分'), findsOneWidget);

    final stored = await tester.runAsync(() => app.records.list());
    expect(stored, hasLength(1));
    expect(stored!.first.systolic, 128);
    expect(stored.first.diastolic, 84);
    expect(stored.first.pulse, 72);
    expect(stored.first.arm, MeasureArm.right);
    expect(stored.first.posture, MeasurePosture.sitting);
    expect(stored.first.note, '晨起');
    expect(stored.first.source, RecordSource.manual);
    expect(await tester.runAsync(() => app.outbox.count()), 1);

    await tester.tap(find.text('128/84'));
    await pumpUntilReal(tester, () => tester.any(find.text('编辑记录')));
    await fillAndSave(tester, sys: '145', dia: '95', pulse: '78');

    expect(find.text('145/95'), findsOneWidget);
    expect(find.text('轻度升高'), findsWidgets);

    final updated = await tester.runAsync(() => app.records.list());
    expect(updated!.first.systolic, 145);
    expect(updated.first.diastolic, 95);
    expect(await tester.runAsync(() => app.outbox.count()), 2);
  });

  testWidgets('删除记录：左滑后确认，SQLite 软删除 + outbox delete',
      (tester) async {
    await app.pumpApp(tester);

    await tester.tap(find.text('手动录入').first);
    await pumpUntilReal(tester, () => tester.any(find.text('录入血压')));
    await fillAndSave(tester, sys: '120', dia: '80');
    expect(find.text('120/80'), findsOneWidget);

    await tester.drag(find.text('120/80'), const Offset(-600, 0));
    await pumpUntilReal(tester, () => tester.any(find.text('删除记录')));
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('还没有血压记录')),
    );

    expect(find.text('120/80'), findsNothing);
    final visible = await tester.runAsync(() => app.records.list());
    expect(visible, isEmpty);
    final all = await tester.runAsync(
        () => app.records.list(includeDeleted: true));
    expect(all, hasLength(1));
    expect(all!.first.isDeleted, isTrue);
    final entries = await tester.runAsync(() => app.outbox.take(10));
    expect(entries!.last.op, 'delete');
  });

  testWidgets('趋势页：真实多日记录聚合、筛选与折线图', (tester) async {
    final now = DateTime.now();
    await app.insertRecord(sys: 118, dia: 76, pulse: 68, at: now);
    await app.insertRecord(
      sys: 142,
      dia: 92,
      pulse: 80,
      at: now.subtract(const Duration(days: 2)),
      arm: MeasureArm.right,
    );
    await app.insertRecord(
      sys: 128,
      dia: 82,
      pulse: 72,
      at: now.subtract(const Duration(days: 10)),
    );

    await app.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.show_chart_outlined));
    await pumpUntilReal(tester, () => tester.any(find.text('血压趋势')));
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('平均高压')) && tester.any(find.byType(LineChart)),
    );

    expect(find.text('血压趋势'), findsOneWidget);
    expect(find.text('平均高压'), findsOneWidget);
    expect(find.text('平均低压'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.text('近7天'));
    await pumpUntilReal(tester, () => tester.any(find.byType(LineChart)));
    await tester.tap(find.text('双臂'));
    await tester.pump();
    expect(find.textContaining('仅左臂'), findsOneWidget);
  });

  testWidgets('知识阅读：13 篇真实 assets、分类筛选、详情收藏与字号',
      (tester) async {
    await app.pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await pumpUntilReal(tester, () => tester.any(find.text('健康知识')));
    expect(find.text('健康知识'), findsOneWidget);
    expect(find.text('在家如何正确测量血压？'), findsOneWidget);
    expect(KnowledgeArticle.all, hasLength(13));

    await tester.tap(find.text('生活方式'));
    await tester.pumpAndSettle();
    expect(find.text('减盐是降血压的第一步'), findsOneWidget);
    expect(find.text('在家如何正确测量血压？'), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在家如何正确测量血压？'));
    await pumpUntilReal(
      tester,
      () => tester.any(find.textContaining('测量前 30 分钟')),
    );
    // 等待页面滑入动画结束，否则 AppBar 星标的全局坐标仍在位移中
    await tester.pumpAndSettle();
    // 文章详情页 AppBar 标题与列表页筛选 chip 同名，限定 AppBar 作用域
    expect(find.widgetWithText(AppBar, '测量方法'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border));
    await pumpUntilReal(tester, () => tester.any(find.byIcon(Icons.star)));
    expect(app.settings.isFavorite('measure-guide'), isTrue);

    await tester.tap(find.byIcon(Icons.text_increase));
    await tester.pump();
    expect(app.settings.knowledgeFontScale, greaterThan(1.0));
  });

  testWidgets('AI 助手：未配置模型时显示引导', (tester) async {
    await app.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.smart_toy_outlined));
    await pumpUntilReal(tester, () => tester.any(find.text('尚未配置 AI 模型')));
    expect(find.text('去配置模型'), findsOneWidget);
  });

  testWidgets('添加远端模型写入 SQLite 后助手进入真实欢迎态', (tester) async {
    await app.pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await pumpUntilReal(tester, () => tester.any(find.text('AI 模型配置')));
    await tester.tap(find.text('AI 模型配置'));
    await pumpUntilReal(tester, () => tester.any(find.text('添加远端模型 API')));
    await tester.tap(find.text('添加远端模型 API'));
    await pumpUntilReal(tester, () => tester.any(find.text('添加远端模型')));

    await tester.tap(find.text('DeepSeek'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, '模型名称（model）'),
      'deepseek-chat',
    );
    await tester.tap(find.text('添加并启用'));
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('从魔搭社区安装模型')),
    );

    final list = await tester.runAsync(() => app.profiles.list());
    expect(list, hasLength(1));
    expect(list!.first.kind.name, 'remote');
    expect(list.first.baseUrl, contains('deepseek.com'));
    expect(list.first.remoteModel, 'deepseek-chat');

    // 等待编辑页 pop 动画结束，避免同时存在两个返回按钮
    await tester.pumpAndSettle();
    await tester.pageBack();
    await pumpUntilReal(tester, () => tester.any(find.text('我的')));
    // 设置行图标与底部导航同图标名，取导航栏（树序靠后）的
    await tester.tap(find.byIcon(Icons.smart_toy_outlined).last);
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('👋 你好，我是你的血压健康助手')),
    );
    expect(find.text('帮我分析一下最近的血压情况'), findsOneWidget);
  });

  testWidgets('我的页：设置落盘、云同步占位、魔搭市场入口、免责声明',
      (tester) async {
    await app.pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await pumpUntilReal(tester, () => tester.any(find.text('AI 模型配置')));
    expect(find.text('导出与分享'), findsOneWidget);
    expect(find.text('云同步'), findsOneWidget);
    expect(find.text('默认测量臂'), findsOneWidget);

    await tester.tap(find.text('右臂'));
    await tester.pump();
    expect(app.settings.defaultArm, MeasureArm.right);

    // 新增提醒方式区块后页面变长，外观设置在首屏外，先滚动到可见
    await tester.scrollUntilVisible(
      find.text('暗色'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible 只保证"可见"，再上拉一段确保完整进入可点区域
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.text('暗色'));
    await tester.pump();
    expect(app.settings.themeMode, 'dark');

    await tester.tap(find.text('云同步'));
    await pumpUntilReal(tester, () => tester.any(find.text('未开启')));
    expect(find.textContaining('尚未接入云平台'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // 列表此前滚动到下方（懒加载），顶部行未构建，向上拖回 AI 模型配置行
    for (var i = 0;
        i < 6 && !tester.any(find.text('AI 模型配置'));
        i++) {
      await tester.dragFrom(const Offset(180, 400), const Offset(0, 400));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('AI 模型配置'));
    await pumpUntilReal(tester, () => tester.any(find.text('尚未配置任何模型')));
    await tester.tap(find.text('从魔搭社区安装模型'));
    await pumpUntilReal(tester, () => tester.any(find.text('魔搭模型市场')));
    expect(find.text('Qwen3 0.6B'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('其他仓库'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Qwen2.5 3B Instruct'), findsOneWidget);
    // pageBack 会被下层路由的同名返回按钮干扰，直接点最上层路由的返回
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('免责声明'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // 再上拉一段，确保该行完整进入可点区域（scrollUntilVisible 只保证可见）
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.text('免责声明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不构成医学诊断'), findsOneWidget);
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    // 微信分享配置同样可能被推到视口边缘，滚动到可见后再点
    await tester.scrollUntilVisible(
      find.text('微信分享配置'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.text('微信分享配置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '微信开放平台 AppID'),
      'wx1234567890abcd',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(app.settings.wechatAppId, 'wx1234567890abcd');
  });

  testWidgets('导出与分享页：真实记录卡与统计卡', (tester) async {
    await app.insertRecord(sys: 132, dia: 86, pulse: 75);
    await app.pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await pumpUntilReal(tester, () => tester.any(find.text('导出与分享')));
    await tester.tap(find.text('导出与分享'));
    await pumpUntilReal(tester, () => tester.any(find.text('卡片分享')));

    expect(find.text('单次记录卡'), findsOneWidget);
    expect(find.text('BloodPressed · 血压记录'), findsOneWidget);
    expect(find.text('微信好友'), findsOneWidget);
    expect(find.text('导出全部记录为 CSV（Excel 可打开）'), findsOneWidget);

    await tester.tap(find.text('统计摘要卡'));
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('BloodPressed · 血压周报')),
    );
  });

  testWidgets('OCR 确认表单：预填结果写入真实 SQLite 且来源为拍照识别',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: app.overrides,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecordEditPage(
                          initialSystolic: 145,
                          initialDiastolic: 95,
                          initialPulse: 88,
                          initialSource: RecordSource.ocr,
                          initialConfidence: 0.82,
                        ),
                      ),
                    );
                  },
                  child: const Text('打开确认'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开确认'));
    await pumpUntilReal(tester, () => tester.any(find.text('保存记录')));

    expect(find.textContaining('拍照识别结果'), findsOneWidget);
    expect(find.textContaining('82%'), findsOneWidget);
    expect(find.textContaining('轻度升高'), findsOneWidget);

    await tester.tap(find.text('保存记录'));
    await pumpUntilReal(tester, () => !tester.any(find.text('保存记录')));

    final stored = await tester.runAsync(() => app.records.list());
    expect(stored, hasLength(1));
    expect(stored!.first.systolic, 145);
    expect(stored.first.diastolic, 95);
    expect(stored.first.pulse, 88);
    expect(stored.first.source, RecordSource.ocr);
  });

  testWidgets('非法血压拦截：高压小于低压不入库', (tester) async {
    await app.pumpApp(tester);
    await tester.tap(find.text('手动录入').first);
    await pumpUntilReal(tester, () => tester.any(find.text('录入血压')));
    await tester.enterText(
      find.widgetWithText(TextField, '高压（收缩压）').first,
      '80',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '低压（舒张压）').first,
      '120',
    );
    await tester.tap(find.text('保存记录'));
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('高压应大于低压')),
    );
    expect(await tester.runAsync(() => app.records.list()), isEmpty);
  });

  testWidgets('首页最近一次测量与今日次数来自真实 SQLite', (tester) async {
    final now = DateTime.now();
    // 两条都放"今天"（用分钟间隔，避免午夜前运行时跨天导致今日计数不稳定）
    await app.insertRecord(sys: 118, dia: 76, pulse: 64, at: now);
    await app.insertRecord(
      sys: 122,
      dia: 78,
      pulse: 66,
      at: now.subtract(const Duration(minutes: 1)),
    );
    await app.pumpApp(tester);
    await pumpUntilReal(tester, () => tester.any(find.text('最近一次测量')));
    expect(find.text('最近一次测量'), findsOneWidget);
    expect(find.text('118'), findsWidgets);
    expect(find.text('76'), findsWidgets);
    expect(find.textContaining('今日已测 2 次'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);
  });

  testWidgets('趋势空态', (tester) async {
    await app.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.show_chart_outlined));
    await pumpUntilReal(tester, () => tester.any(find.text('该范围内暂无数据')));
    expect(find.text('该范围内暂无数据'), findsOneWidget);
  });

  testWidgets('趋势近90天与脉搏序列', (tester) async {
    await app.insertRecord(sys: 126, dia: 82, pulse: 70);
    await app.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.show_chart_outlined));
    await pumpUntilReal(tester, () => tester.any(find.byType(LineChart)));
    await tester.tap(find.text('近90天'));
    await pumpUntilReal(tester, () => tester.any(find.byType(LineChart)));
    await tester.tap(find.text('脉搏'));
    await pumpUntilReal(tester, () => tester.any(find.byType(LineChart)));
    expect(find.text('平均脉搏'), findsOneWidget);
  });

  testWidgets('知识：认识血压与监测管理真实文章', (tester) async {
    await app.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await pumpUntilReal(tester, () => tester.any(find.text('健康知识')));
    await tester.tap(find.text('认识血压'));
    await tester.pumpAndSettle();
    expect(find.text('高压、低压、脉搏，分别代表什么？'), findsOneWidget);
    await tester.tap(find.text('监测管理'));
    await tester.pumpAndSettle();
    expect(find.text('这些情况请立即就医'), findsOneWidget);
    await tester.tap(find.text('这些情况请立即就医'));
    await pumpUntilReal(
      tester,
      () => tester.any(find.textContaining('立即就医')),
    );
  });

  testWidgets('默认测量臂写入新记录表单', (tester) async {
    await tester.runAsync(() => app.settings.setDefaultArm(MeasureArm.right));
    await app.pumpApp(tester);
    await tester.tap(find.text('手动录入').first);
    await pumpUntilReal(tester, () => tester.any(find.text('录入血压')));
    final arm = tester.widget<SegmentedButton<MeasureArm>>(
      find.byType(SegmentedButton<MeasureArm>),
    );
    expect(arm.selected, {MeasureArm.right});
  });

  testWidgets('助手发送走真实远端推理并落盘用户消息', (tester) async {
    await tester.runAsync(() async {
      final profile = LlmProfile(
        id: 'remote-live',
        kind: LlmKind.remote,
        name: '魔搭推理',
        config: {
          'baseUrl': 'https://api-inference.modelscope.cn/v1',
          'apiKey': 'invalid-token-bloodpressed-test',
          'model': 'Qwen/Qwen3-32B',
        },
      );
      await app.profiles.upsert(profile);
      await app.settings.setActiveLlmProfile(profile.id);
    });
    await app.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.smart_toy_outlined));
    await pumpUntilReal(
      tester,
      () => tester.any(find.text('👋 你好，我是你的血压健康助手')),
    );
    await tester.enterText(
      find.byType(TextField),
      '最近血压偏高要注意什么？',
    );
    await tester.tap(find.byIcon(Icons.send));
    await pumpUntilReal(
      tester,
      () => tester.any(find.byType(ErrorBanner)) ||
          tester.any(find.textContaining('最近血压偏高要注意什么')),
      timeout: const Duration(seconds: 45),
    );
    final history = await tester.runAsync(() => app.chat.history());
    expect(history!.any((m) => m.role == ChatRole.user), isTrue);
    // 排空 dio 请求残留的 30s 超时 FakeTimer，避免 Pending timers 判失败
    await tester.pump(const Duration(seconds: 31));
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('首页快捷入口包含拍照与相册识别', (tester) async {
    await app.pumpApp(tester);
    expect(find.text('拍照识别'), findsOneWidget);
    expect(find.text('相册识别'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('从相册选择'), findsOneWidget);
  });
}
