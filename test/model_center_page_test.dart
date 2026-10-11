/// 模型中心页真实数据渲染测试（双社区搜索/文件列表/错误提示）。
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

import 'package:blood_pressed/features/llm/presentation/model_center_page.dart';
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
          home: ModelCenterPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> focusCustomRepoInput(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('customRepoField')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  Future<void> focusSearchInput(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('modelSearchField')));
    await tester.pump(const Duration(milliseconds: 200));
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

    await tester.enterText(find.byKey(const ValueKey('customRepoField')), 'Qwen/Qwen3-8B-GGUF');
    await tester.tap(find.text('查看'));
    await pumpUntilReal(
      tester,
      () => tester.widgetList(find.textContaining('.gguf')).isNotEmpty,
    );

    // 真实仓库中的真实文件（Qwen3-8B 系列 GGUF 权重）
    expect(find.text('Qwen3-8B-Q4_K_M.gguf'), findsOneWidget);
    expect(find.text('Qwen3-8B-Q8_0.gguf'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('搜索：双社区并行检索 qwen3 1.7b 出现结果', (tester) async {
    await pumpMarket(tester);
    await focusSearchInput(tester);

    await tester.enterText(
        find.byKey(const ValueKey('modelSearchField')), 'qwen3 1.7b');
    await tester.tap(find.text('搜索'));
    await pumpUntilReal(
      tester,
      () => tester.widgetList(find.text('搜索结果')).isNotEmpty,
    );

    // 双社区合并去重：官方仓库应出现在结果里（来自任一社区）
    expect(find.text('Qwen/Qwen3-1.7B-GGUF'), findsOneWidget);
    // 推进 FakeAsync 时钟越过 searchAll 的 8s 超时 Timer，避免
    // timersPending 不变量断言失败
    await tester.pump(const Duration(seconds: 61));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('自定义不存在的仓库：真实错误响应渲染可读提示与重试', (tester) async {
    await pumpMarket(tester);
    await focusCustomRepoInput(tester);

    await tester.enterText(find.byKey(const ValueKey('customRepoField')),
        'This/DoesNotExist-xyz-GGUF');
    await tester.tap(find.text('查看'));
    await pumpUntilReal(
      tester,
      () => tester.widgetList(find.text('重试')).isNotEmpty,
    );

    // 魔搭真实 404 响应（Code: 10010205001）解析后的可读提示
    expect(find.textContaining('获取模型文件失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
