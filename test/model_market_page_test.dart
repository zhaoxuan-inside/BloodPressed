/// 魔搭市场页真实数据渲染测试。
///
/// 页面不做任何 provider 覆盖，使用 App 真实的 ModelScopeClient
/// 直连 modelscope.cn。
///
/// 技术说明：flutter_test 的 FakeAsync 会冻结真实定时器并拦截网络，
/// 这里通过两处框架机制实现真实网络测试：
/// 1. 自定义绑定关闭全局 HTTP 拦截（flutter_test 为端到端真实网络
///    测试预留的 `overrideHttpClient` 开关）；
/// 2. 在 `tester.runAsync`（真实事件循环）内循环驱动 `pump`，
///    等待真实请求完成后再做断言。
///
/// 注意：运行本文件需要外网可访问 modelscope.cn。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/llm/presentation/model_market_page.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

class _RealNetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _RealNetworkBinding();

  /// 在真实事件循环中反复驱动一帧，直到 [until] 满足或超时。
  Future<void> pumpUntilReal(
    WidgetTester tester,
    bool Function() until, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    await tester.runAsync(() async {
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (until()) return;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> pumpMarket(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: ModelMarketPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> focusCustomRepoInput(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byType(TextField),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('展开精选模型：渲染真实魔搭文件列表', (tester) async {
    await pumpMarket(tester);

    await tester.tap(find.text('Qwen3 0.6B'));
    await pumpUntilReal(
      tester,
      () => tester.widgetList(find.textContaining('.gguf')).isNotEmpty,
    );

    // 真实仓库中的真实权重文件
    expect(find.text('Qwen3-0.6B-Q8_0.gguf'), findsOneWidget);
    expect(find.textContaining('.gguf'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('自定义真实仓库：输入 Qwen/Qwen3-8B-GGUF 拉取真实列表', (tester) async {
    await pumpMarket(tester);
    await focusCustomRepoInput(tester);

    await tester.enterText(find.byType(TextField), 'Qwen/Qwen3-8B-GGUF');
    await tester.tap(find.text('查看'));
    await pumpUntilReal(
      tester,
      () => tester.widgetList(find.textContaining('.gguf')).isNotEmpty,
    );

    // 真实仓库中的真实文件（Qwen3-8B 系列 GGUF 权重）
    expect(find.text('Qwen3-8B-Q4_K_M.gguf'), findsOneWidget);
    expect(find.text('Qwen3-8B-Q8_0.gguf'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('自定义不存在的仓库：真实错误响应渲染可读提示与重试', (tester) async {
    await pumpMarket(tester);
    await focusCustomRepoInput(tester);

    await tester.enterText(
        find.byType(TextField), 'This/DoesNotExist-xyz-GGUF');
    await tester.tap(find.text('查看'));
    await pumpUntilReal(
      tester,
      () => tester.widgetList(find.text('重试')).isNotEmpty,
    );

    // 魔搭真实 404 响应（Code: 10010205001）解析后的可读提示
    expect(find.textContaining('魔搭返回错误'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
