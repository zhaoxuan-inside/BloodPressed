import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/features/assistant/presentation/assistant_page.dart';
import 'package:blood_pressed/features/export/presentation/export_page.dart';
import 'package:blood_pressed/features/knowledge/presentation/knowledge_list_page.dart';
import 'package:blood_pressed/features/llm/presentation/llm_settings_page.dart';
import 'package:blood_pressed/features/records/presentation/home_page.dart';
import 'package:blood_pressed/features/settings/presentation/settings_page.dart';
import 'package:blood_pressed/features/stats/presentation/stats_page.dart';

/// 底部导航外壳。
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: '趋势'),
          NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy),
              label: 'AI助手'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: '知识'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
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
