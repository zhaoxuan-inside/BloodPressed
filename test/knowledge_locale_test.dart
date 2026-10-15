/// 知识库语言回归：内容必须跟随「生效语言」（含跟随系统解析），
/// 而非语言偏好字符串；正文缓存按语言隔离。
///
/// 用户报告：语言选择「跟随系统」时知识库仍只展示中文。
/// 根因：knowledgeListProvider 只监听 localePrefProvider（'system' 之后
/// 恒定不变），语言取自 AppLocaleService 静态快照——快照会刷新，
/// 但 provider 不会重算；正文缓存又按中英共享的 id 键控，跨语言串内容。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/knowledge/data/knowledge_repository.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';

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

  final zhFirstTitle = '在家如何正确测量血压？';
  final enFirstTitle = 'How to Measure Blood Pressure Accurately at Home';

  Future<void> openKnowledge(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await pumpUntilReal(
      tester,
      () =>
          tester.any(find.text(zhFirstTitle)) ||
          tester.any(find.text(enFirstTitle)),
    );
  }

  /// 设置页语言段与主题段都有「跟随系统」文案：用语言段独有的
  /// English 选项定位语言 SegmentedButton，再在其中点「跟随系统」。
  Future<void> switchLanguageToSystem(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.person_outline));
    await pumpUntilReal(tester, () => tester.any(find.text('中文')));
    for (var i = 0; i < 8 && !tester.any(find.text('English')); i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    final langButton = find.ancestor(
      of: find.text('English'),
      matching: find.byType(SegmentedButton<String>),
    );
    expect(langButton, findsOneWidget);
    await tester.ensureVisible(langButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: langButton, matching: find.text('跟随系统')),
    );
    await pumpUntilReal(tester, () => tester.any(find.text('System')));
  }

  testWidgets('跟随系统（系统英文）冷启动：知识库列表为英文', (tester) async {
    await app.settings.setLocalePref('system');
    await app.pumpApp(tester);

    await openKnowledge(tester);

    expect(find.text(enFirstTitle), findsOneWidget);
    expect(find.text('Measurement'), findsOneWidget);
  });

  testWidgets('会话内切到跟随系统：知识库由中文即时切英文', (tester) async {
    await app.pumpApp(tester); // setUp 固定 zh 起
    await openKnowledge(tester);
    expect(find.text(zhFirstTitle), findsOneWidget);

    await switchLanguageToSystem(tester);

    // 回到知识库 tab：列表标题/分类应即时切英文
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await pumpUntilReal(tester, () => tester.any(find.text(enFirstTitle)));

    expect(find.text(enFirstTitle), findsOneWidget);
    expect(find.text('Measurement'), findsOneWidget);
    expect(find.text(zhFirstTitle), findsNothing);
  });

  testWidgets('显式英文偏好：知识库列表为英文（回归网）', (tester) async {
    await app.settings.setLocalePref('en');
    await app.pumpApp(tester);

    await openKnowledge(tester);

    expect(find.text(enFirstTitle), findsOneWidget);
    expect(find.text('Measurement'), findsOneWidget);
  });

  test('正文缓存按语言隔离：同 id 中英文章各自加载', () async {
    final repo = const KnowledgeRepository();
    final zh = await repo.loadContent(KnowledgeArticle.allZh.first);
    final en = await repo.loadContent(KnowledgeArticle.allEn.first);

    expect(zh, contains('血压'));
    expect(en, contains('Blood Pressure'));
    expect(en, isNot(equals(zh)));
  });
}
