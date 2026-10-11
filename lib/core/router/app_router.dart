import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/features/assistant/presentation/assistant_page.dart';
import 'package:blood_pressed/features/export/presentation/export_page.dart';
import 'package:blood_pressed/features/knowledge/presentation/knowledge_list_page.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/llm/presentation/llm_settings_page.dart';
import 'package:blood_pressed/features/records/presentation/home_page.dart';
import 'package:blood_pressed/features/settings/presentation/settings_page.dart';
import 'package:blood_pressed/features/stats/presentation/stats_page.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// AI助手分支的 branch 索引（StatefulShellRoute 中的固定位置）。
const int _assistantBranchIndex = 2;

/// 底部导航外壳。
///
/// AI助手入口在「已配置模型或内置默认模型就绪」时显示；
/// 停留在该分支时模型可用性消失（档案删空且内置未就绪）则自动跳回首页。
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profiles = ref.watch(llmProfilesProvider).valueOrNull ?? const [];
    final hasModel =
        profiles.isNotEmpty || ref.watch(builtinModelReadyProvider);

    // 模型可用性消失且当前停在 AI助手分支：退回首页，避免停留在已隐藏的入口
    ref.listen(llmProfilesProvider, (prev, next) {
      final empty = (next.valueOrNull ?? const []).isEmpty;
      final builtinReady = ref.read(builtinModelReadyProvider);
      if (empty &&
          !builtinReady &&
          navigationShell.currentIndex == _assistantBranchIndex &&
          context.mounted) {
        context.go('/home');
      }
    });    // 显示序号 → branch 索引（无模型可用时 AI助手分支不渲染）
    final visibleBranches = [
      0,
      1,
      if (hasModel) _assistantBranchIndex,
      3,
      4,
    ];
    final destinations = [
      NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: l10n.navHome),
      NavigationDestination(
          icon: const Icon(Icons.show_chart_outlined),
          selectedIcon: const Icon(Icons.show_chart),
          label: l10n.navStats),
      if (hasModel)
        NavigationDestination(
            icon: const Icon(Icons.smart_toy_outlined),
            selectedIcon: const Icon(Icons.smart_toy),
            label: l10n.navAssistant),
      NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book),
          label: l10n.navKnowledge),
      NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: l10n.navMe),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        // branch 索引 → 显示序号（AI助手隐藏后，知识/我的的选中态要前移）
        selectedIndex:
            visibleBranches.contains(navigationShell.currentIndex)
                ? visibleBranches.indexOf(navigationShell.currentIndex)
                : 0,
        onDestinationSelected: (displayIndex) {
          final branch = visibleBranches[displayIndex];
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: destinations,
      ),
    );
  }
}

/// 应用路由表（每次调用生成独立实例，便于测试隔离）。
GoRouter buildAppRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/stats',
              name: 'stats',
              builder: (context, state) => const StatsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/assistant',
              name: 'assistant',
              builder: (context, state) => const AssistantPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/knowledge',
              name: 'knowledge',
              builder: (context, state) => const KnowledgeListPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/llm',
        name: 'llm',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LlmSettingsPage(),
      ),
      GoRoute(
        path: '/export',
        name: 'export',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExportPage(),
      ),
    ],
  );
}

/// 应用全局路由实例。
final GoRouter appRouter = buildAppRouter();
