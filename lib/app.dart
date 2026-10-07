import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/i18n/app_locale_service.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/llm/presentation/controllers/llm_providers.dart';
import 'l10n/app_localizations.dart';

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
    final localePref = ref.watch(localePrefProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      // 中英双语：语言偏好为 system 时交给 locale 解析（zh/en 之外回落 en）
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localePref == 'system' ? null : Locale(localePref),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      builder: (context, child) {
        // 同步当前生效语言快照，供通知/CSV/分享卡等无 context 场景取词
        AppLocaleService.current = Localizations.localeOf(context);
        return child!;
      },
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: widget.router ?? appRouter,
    );
  }
}
