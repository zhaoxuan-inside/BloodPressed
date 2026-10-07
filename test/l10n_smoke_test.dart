/// l10n 冒烟测试：英文界面渲染、语言切换生效、无 context 场景（CSV）随语言快照变化。
///
/// 语言偏好固定写入 AppSettings（与主 harness 相同的 provider 装配），
/// AppLocaleService 静态快照在用例内显式设置/恢复，避免跨用例污染。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/export/data/csv_exporter.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';
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
    AppLocaleService.current = const Locale('zh');
    await app.tearDown();
  });

  testWidgets('英文界面：首页与设置页关键文案为英文', (tester) async {
    await app.settings.setLocalePref('en');
    await app.pumpApp(tester);

    expect(find.text('BloodPressed'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await pumpUntilReal(tester, () => tester.any(find.text('Language')));
    // 'Me' 同时出现在底部导航与设置页标题
    expect(find.text('Me'), findsNWidgets(2));
    // Language 行在首屏外（懒加载），滚动到可见
    if (!tester.any(find.text('Language'))) {
      await tester.scrollUntilVisible(
        find.text('Language'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
  });

  testWidgets('语言切换：设置页选择中文后界面即时切换', (tester) async {
    await app.settings.setLocalePref('en');
    await app.pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    // 语言行在首屏外（懒加载）：先拖动触发构建，再完全滚入视口
    for (var i = 0;
        i < 8 && !tester.any(find.text('中文'));
        i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('中文'));
    await tester.pumpAndSettle();

    // 语言行选择「中文」→ MaterialApp 重建为中文（'我的' 在导航与标题各一次）
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsNWidgets(2));
    expect(app.settings.localePref, 'zh');
  });

  test('无 context 场景：CSV 表头随 AppLocaleService 快照变化', () async {
    AppLocaleService.current = const Locale('zh');
    final zhCsv = const CsvExporter().buildCsv([]);
    expect(zhCsv, contains('测量时间,高压(mmHg)'));

    AppLocaleService.current = const Locale('en');
    final enCsv = const CsvExporter().buildCsv([]);
    expect(enCsv, contains('Time,Systolic(mmHg)'));
  });

  test('AppLocalizations 支持 zh/en 两个 locale', () {
    expect(
      AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toSet(),
      containsAll(['zh', 'en']),
    );
  });
}
