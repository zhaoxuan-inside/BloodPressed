/// 功能搜索测试：确定性匹配规则、语义匹配（注入 fake 出口）、
/// 新路由导航冒烟、搜索页交互闭环。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/app.dart';
import 'package:blood_pressed/core/router/app_router.dart';
import 'package:blood_pressed/features/app_search/domain/feature_registry.dart';
import 'package:blood_pressed/features/app_search/domain/feature_search_service.dart';
import 'package:blood_pressed/features/app_search/presentation/feature_search_page.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/model_market_page.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';
import 'package:blood_pressed/features/settings/presentation/settings_page.dart';
import 'package:blood_pressed/features/sync/presentation/sync_page.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';
import 'support/real_test_harness.dart';

void main() {
  installRealNetworkBinding();
  initSqfliteFfi();

  group('确定性匹配', () {
    final service = FeatureSearchService();

    test('空查询返回空表', () {
      expect(service.match(''), isEmpty);
      expect(service.match('   '), isEmpty);
    });

    test('标题命中（zh）', () {
      final hits = service.match('测量提醒');
      expect(hits.map((e) => e.id).first, 'reminder');
    });

    test('关键词命中（zh）', () {
      final ids = service.match('备份').map((e) => e.id).toList();
      expect(ids, contains('sync'));
    });

    test('关键词命中（en，大小写不敏感）', () {
      final ids = service.match('CSV').map((e) => e.id).toList();
      expect(ids, contains('export'));
      final ids2 = service.match('theme').map((e) => e.id).toList();
      expect(ids2, contains('appearance'));
    });

    test('无命中返回空表', () {
      expect(service.match('完全无关的查询词'), isEmpty);
    });

    test('注册表条目的路由均已注册（静态检查）', () {
      const registered = {
        '/home', '/record/new', '/stats', '/assistant', '/knowledge',
        '/llm', '/market', '/settings', '/export', '/sync', '/search',
      };
      for (final entry in kAppFeatureRegistry) {
        expect(registered, contains(entry.route),
            reason: '条目 ${entry.id} 的路由 ${entry.route} 未注册');
      }
    });
  });

  group('语义匹配（fake 出口）', () {
    final service = FeatureSearchService();

    test('按分数排序取前 N，幻觉 id 被过滤', () async {
      final hits = await service.semanticMatch(
        '怎么把数据给医生',
        chatJson: (messages, maxTokens) async => {
          'matches': [
            {'id': 'export', 'score': 95},
            {'id': 'ghost-不存在', 'score': 99},
            {'id': 'record_new', 'score': 30},
          ],
        },
      );
      expect(hits.map((e) => e.id).toList(), ['export', 'record_new']);
    });

    test('输出不可解析/为空 → 返回空表', () async {
      expect(
        await service.semanticMatch('q',
            chatJson: (m, t) async => null),
        isEmpty,
      );
      expect(
        await service.semanticMatch('q',
            chatJson: (m, t) async => {'matches': '不是数组'}),
        isEmpty,
      );
    });

    test('模型抛错 → 静默返回空表', () async {
      expect(
        await service.semanticMatch('q',
            chatJson: (m, t) => throw Exception('模型未就绪')),
        isEmpty,
      );
    });

    test('系统提示包含功能目录与用户查询', () async {
      List<ChatMessage>? captured;
      await service.semanticMatch('设置提醒', chatJson: (messages, maxTokens) {
        captured = messages;
        return Future.value(const {
          'matches': [
            {'id': 'reminder', 'score': 90}
          ],
        });
      });
      expect(captured, isNotNull);
      expect(captured!.first.content, contains('测量提醒'));
      expect(captured!.first.content, contains('设置提醒'));
    });
  });

  group('路由与页面', () {
    testWidgets('提升的 4 条路由均可直达', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      addTearDown(app.tearDown);

      final router = buildAppRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: app.overrides,
        child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
      ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // go_router 的 push Future 在 pop 时才完成，连续 unawaited push
      // 会丢弃前序命令式路由——逐个 push→验证→pop
      unawaited(router.push('/sync'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SyncPage), findsOneWidget);
      router.pop();
      await tester.pump(const Duration(milliseconds: 300));

      unawaited(router.push('/market'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ModelMarketPage), findsOneWidget);
      router.pop();
      await tester.pump(const Duration(milliseconds: 300));

      unawaited(router.push('/record/new'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RecordEditPage), findsOneWidget);
      router.pop();
      await tester.pump(const Duration(milliseconds: 300));

      unawaited(router.push('/search'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FeatureSearchPage), findsOneWidget);
    });

    testWidgets('搜索页：中文关键词实时过滤并跳转', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      addTearDown(app.tearDown);

      final router = buildAppRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: app.overrides,
        child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
      ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      unawaited(router.push('/search'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), '提醒');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('测量提醒'), findsOneWidget);

      await tester.tap(find.text('测量提醒'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('首页 AppBar 有搜索入口', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      addTearDown(app.tearDown);

      await tester.pumpWidget(ProviderScope(
        overrides: app.overrides,
        child: BloodPressedApp(router: buildAppRouter()),
      ));
      await pumpUntilReal(
          tester, () => tester.any(find.byType(NavigationBar)));

      expect(find.byIcon(Icons.search), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FeatureSearchPage), findsOneWidget);
    });
  });
}
