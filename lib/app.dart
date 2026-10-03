import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/llm/presentation/controllers/llm_providers.dart';

/// 应用根组件。[router] 仅供测试注入独立路由实例。
class BloodPressedApp extends ConsumerStatefulWidget {
  const BloodPressedApp({super.key, this.router});

  final GoRouter? router;

  @override
  ConsumerState<BloodPressedApp> createState() => _BloodPressedAppState();
}

class _BloodPressedAppState extends ConsumerState<BloodPressedApp> {
  @override
  void initState() {
    super.initState();
    // 启动后预热当前激活的模型（本地模型加载较慢，放后台）
    Future.microtask(() {
      final profile = ref.read(activeLlmProfileProvider);
      if (profile != null) {
        ref.read(llmEngineProvider.notifier).activate(profile);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeModeName = ref.watch(themeModeNameProvider);
    final themeMode = switch (themeModeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'BloodPressed 血压管家',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: widget.router ?? appRouter,
    );
  }
}
