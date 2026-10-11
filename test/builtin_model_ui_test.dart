/// 内置默认模型 UI 测试：助手 Tab 可见性（内置就绪才显示）、
/// 助手页下载引导态、内置卡片的展示状态机。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/app.dart';
import 'package:blood_pressed/core/router/app_router.dart';
import 'package:blood_pressed/features/assistant/presentation/assistant_page.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/llm/presentation/widgets/builtin_model_card.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';
import 'support/real_test_harness.dart';

void main() {
  installRealNetworkBinding();
  initSqfliteFfi();

  group('助手 Tab 可见性', () {
    testWidgets('全新安装（无档案、内置未就绪）→ 不显示 AI助手', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      addTearDown(app.tearDown);

      await tester.pumpWidget(ProviderScope(
        overrides: app.overrides,
        child: BloodPressedApp(router: buildAppRouter()),
      ));
      await pumpUntilReal(
          tester, () => tester.any(find.byType(NavigationBar)));

      expect(find.text('AI助手'), findsNothing);
    });

    testWidgets('内置模型就绪（无用户档案）→ 显示 AI助手', (tester) async {
      final app = RealAppHarness(builtinModelReady: true);
      await app.setUp();
      addTearDown(app.tearDown);

      await tester.pumpWidget(ProviderScope(
        overrides: app.overrides,
        child: BloodPressedApp(router: buildAppRouter()),
      ));
      await pumpUntilReal(
          tester, () => tester.any(find.byType(NavigationBar)));

      expect(find.text('AI助手'), findsOneWidget);
    });
  });

  group('助手页下载引导', () {
    testWidgets('内置未就绪且无用户档案 → 展示下载卡片与体积说明', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      addTearDown(app.tearDown);

      await tester.pumpWidget(ProviderScope(
        overrides: app.overrides,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: AssistantPage(),
        ),
      ));
      await tester.pump();

      expect(find.text('内置模型 · Qwen3-1.7B'), findsOneWidget);
      expect(find.textContaining('1.8GB'), findsWidgets);
      expect(find.text('开始下载'), findsOneWidget);
      expect(find.text('去配置模型'), findsOneWidget);
    });

    testWidgets('引擎错误（用户档案加载失败）→ 维持原「去配置」提示', (tester) async {
      final app = RealAppHarness();
      await app.setUp();
      await LlmProfileStore(app.db).upsert(const LlmProfile(
        id: 'user-local-bad',
        kind: LlmKind.local,
        name: '本地坏档',
        config: {'modelPath': 'Z:/no/such/model.gguf'},
      ));
      await app.prefs.setString('active_llm_profile', 'user-local-bad');
      addTearDown(app.tearDown);

      final container = ProviderContainer(overrides: app.overrides);
      addTearDown(container.dispose);
      // 预置引擎错误态（激活指向不存在文件的本地档案）
      await container
          .read(llmEngineProvider.notifier)
          .activate(const LlmProfile(
            id: 'user-local-bad',
            kind: LlmKind.local,
            name: '本地坏档',
            config: {'modelPath': 'Z:/no/such/model.gguf'},
          ));

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: AssistantPage(),
        ),
      ));
      await tester.pump();

      expect(find.text('内置模型 · Qwen3-1.7B'), findsNothing);
      expect(find.text('尚未配置 AI 模型'), findsOneWidget);
    });
  });

  group('内置卡片状态机', () {
    testWidgets('未下载：下载按钮 + 说明文案', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ListView(children: [
            BuiltinModelCardView(
              ready: false,
              activeNow: false,
              hasUserModel: false,
              onDownload: () {},
            ),
          ]),
        ),
      ));

      expect(find.text('内置模型 · Qwen3-1.7B'), findsOneWidget);
      expect(find.text('开始下载'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    });

    testWidgets('下载中：进度文案 + 暂停按钮', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ListView(children: [
            BuiltinModelCardView(
              ready: false,
              activeNow: false,
              hasUserModel: false,
              progress: 0.42,
              onDownload: () {},
              onPause: () {},
            ),
          ]),
        ),
      ));

      expect(find.text('下载中 42%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      expect(find.text('开始下载'), findsNothing);
    });

    testWidgets('就绪且无用户模型：启用按钮；有用户模型：无操作按钮', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ListView(children: [
            BuiltinModelCardView(
              ready: true,
              activeNow: false,
              hasUserModel: false,
              onActivate: () {},
            ),
            BuiltinModelCardView(
              ready: true,
              activeNow: false,
              hasUserModel: true,
            ),
          ]),
        ),
      ));

      expect(find.text('已下载 · 离线可用'), findsNWidgets(2));
      expect(find.text('使用内置模型'), findsOneWidget);
    });
  });
}
