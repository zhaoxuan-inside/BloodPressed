/// 趋势四件套 UI 测试：分析文案助手、全屏横屏页（渲染/系列/AI 流程）、
/// 分析卡交互、两张分享卡渲染。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/router/app_router.dart';
import 'package:blood_pressed/features/assistant/presentation/assistant_page.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/export/presentation/share_card_widgets.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/presentation/analysis_text.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/features/stats/presentation/fullscreen_trend_page.dart';
import 'package:blood_pressed/features/stats/presentation/widgets/analysis_card.dart';
import 'package:blood_pressed/features/stats/presentation/widgets/trend_chart.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

import 'support/real_test_harness.dart';

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

BpAnalysis _fixtureAnalysis() {
  final a = BpAnalyzer.analyze([
    rec(8, 142, 92), // 清晨偏高
    rec(15, 118, 76),
  ]);
  return a;
}

void main() {
  installRealNetworkBinding();
  initSqfliteFfi();

  group('分析文案助手', () {
    test('结论：偏高峰值时段被指出；全部理想给理想文案', () {
      final l10n = AppLocaleService.auto;
      final elevated = analysisConclusion(_fixtureAnalysis(), l10n);
      expect(elevated, contains('清晨'));
      expect(elevated, contains('142/92'));

      final ideal = analysisConclusion(
        BpAnalyzer.analyze([rec(8, 120, 78), rec(15, 122, 80)]),
        l10n,
      );
      expect(ideal, contains('理想'));
    });

    test('模型摘要：紧凑中文数字串', () {
      final s = analysisSummaryZh(_fixtureAnalysis());
      expect(s, startsWith('共2次测量'));
      expect(s, contains('清晨均142/92'));
      expect(s, contains('最高单次142/92'));
      expect(s, contains('达标率50%'));
    });

    test('范围标签：预设与自定义', () {
      final l10n = AppLocaleService.auto;
      expect(trendRangeLabel(const TrendQuery(days: 30), l10n), '近30天');
      final custom = trendRangeLabel(
        TrendQuery.custom(DateTime(2026, 10, 1), DateTime(2026, 10, 11)),
        l10n,
      );
      expect(custom, '10月1日-10月11日');
    });
  });

  group('分析卡', () {
    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: ListView(children: [child])),
    );

    testWidgets('折叠显示结论，展开出现时段/星期/峰值，回调触发', (tester) async {
      var aiTapped = false;
      var shareTapped = false;
      await tester.pumpWidget(
        host(
          AnalysisCard(
            analysis: _fixtureAnalysis(),
            conclusion: analysisConclusion(
              _fixtureAnalysis(),
              AppLocaleService.auto,
            ),
            onAiAnalyze: () => aiTapped = true,
            onShare: () => shareTapped = true,
          ),
        ),
      );

      // 折叠：结论可见，明细不可见
      expect(find.textContaining('清晨'), findsOneWidget);
      expect(find.text('星期'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      // 展开
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      expect(find.text('达标 0/1'), findsWidgets);

      // 回调
      await tester.tap(find.byIcon(Icons.auto_awesome));
      expect(aiTapped, isTrue);
      await tester.tap(find.byIcon(Icons.ios_share));
      expect(shareTapped, isTrue);
    });
  });

  group('分享卡渲染', () {
    testWidgets('趋势卡：标题/均值/次数可见', (tester) async {
      final query = TrendQuery.custom(
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Center(
              child: TrendShareCard(
                title: '10月5日-10月6日',
                points: [
                  DayPoint(
                    date: DateTime(2026, 10, 5),
                    avgSystolic: 138,
                    avgDiastolic: 88,
                    count: 2,
                  ),
                  DayPoint(
                    date: DateTime(2026, 10, 6),
                    avgSystolic: 126,
                    avgDiastolic: 80,
                    count: 1,
                  ),
                ],
                query: query,
                avgSystolic: 132,
                avgDiastolic: 84,
                count: 3,
              ),
            ),
          ),
        ),
      );
      expect(find.text('血压了么 · 血压趋势'), findsOneWidget);
      expect(find.text('10月5日-10月6日'), findsOneWidget);
      expect(find.text('132 / 84'), findsOneWidget);
      expect(find.byType(TrendLineChart), findsOneWidget);
    });

    testWidgets('分析卡：结论/时段/星期/峰值可见', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Center(
              child: AnalysisShareCard(
                title: '10月5日-10月6日',
                conclusion: '「清晨」时段平均血压偏高（142/90）',
                analysis: _fixtureAnalysis(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('血压了么 · 规律分析'), findsOneWidget);
      expect(find.textContaining('清晨'), findsWidgets);
      expect(find.textContaining('最高单次'), findsOneWidget);
    });
  });

  group('全屏横屏图表页', () {
    Future<ProviderContainer> harnessContainer(RealAppHarness app) async {
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
      await LlmProfileStore(app.db).upsert(remoteProfile);
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      await settings.setActiveLlmProfile(remoteProfile.id);
      await settings.acceptPrivacy();
      await settings.allowRemote(remoteProfile);
      final container = ProviderContainer(
        overrides: [
          ...app.overrides,
          activeLlmProfileIdProvider.overrideWith((ref) => remoteProfile.id),
          isBuiltinActiveProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      await container.read(llmProfilesProvider.notifier).refresh();
      await container.read(llmEngineProvider.notifier).activate(remoteProfile);
      return container;
    }

    testWidgets('渲染折线 + 系列切换 + AI 流程（清 pending/回竖屏/进助手）', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      addTearDown(app.tearDown);
      await app.insertRecord(
        sys: 142,
        dia: 92,
        at: DateTime(2026, 10, 5, 8, 30),
      );
      await app.insertRecord(
        sys: 118,
        dia: 76,
        at: DateTime(2026, 10, 5, 15, 0),
      );

      final container = await harnessContainer(app);
      final router = buildAppRouter();
      addTearDown(router.dispose);
      final query = TrendQuery.custom(
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 5),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      unawaited(router.push('/stats/fullscreen', extra: query));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FullscreenTrendPage), findsOneWidget);
      expect(find.byType(TrendLineChart), findsOneWidget);

      // 切脉搏：无脉搏数据显示空态文案
      await tester.tap(find.text('脉搏'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('脉搏'), findsWidgets);

      // AI 流程：pending 写入 → pop 回竖屏 → 进助手页 → 自动发送
      await tester.tap(find.text('血压'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AssistantPage), findsOneWidget);
      expect(container.read(pendingAssistantPromptProvider), isNull);
      final state = container.read(assistantProvider);
      expect(state.messages.map((m) => m.role), contains(ChatRole.user));
    });
  });
}
