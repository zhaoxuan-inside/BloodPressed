/// 分享卡捕获链路回归测试（stats-share-002 修复）：
/// 1. 图表卡（fl_chart）在透明 dialog 中渲染稳定后可成功出 PNG——
///    修复前"首帧立即捕获"在真机上失败/挂起，此处作为可捕获性回归网；
/// 2. 记录卡（纯 widget）捕获成功；
/// 3. 捕获超时兜底：toImage 挂起时按超时返回 null 且 dialog 自动关闭，
///    保证调用页面永远不会被透明 dialog 卡死。
///
/// 说明：captureCard 的 settleDelay 在 testWidgets 的 FakeAsync 时区中
/// 无法与真实光栅化协作（测试环境帧完全由 pump 驱动），故成功路径按
/// 真机等价时序验证——dialog 渲染稳定（全部动画结束、无 pending 帧）后
/// 直接走 CardCapturer.capture；超时路径走完整 captureCard 流程。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/export/presentation/card_capture_dialog.dart';
import 'package:blood_pressed/features/export/presentation/share_card_widgets.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/features/stats/domain/daily_candle.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

BpRecord rec(int hour, int sys, int dia, {int? pulse}) {
  final base = DateTime(2026, 10, 5);
  final now = DateTime.now();
  return BpRecord(
    id: 'r-$hour-$sys-$dia',
    systolic: sys,
    diastolic: dia,
    pulse: pulse,
    measuredAt: DateTime(base.year, base.month, base.day, hour, 30),
    arm: MeasureArm.left,
    source: RecordSource.manual,
    deviceId: 'test',
    createdAt: now,
    updatedAt: now,
  );
}

TrendShareCard trendCard() => TrendShareCard(
  title: '10月5日-10月6日',
  points: DayCandle.aggregate([
    rec(8, 138, 88),
    rec(20, 142, 92),
    rec(8, 126, 80).copyWith(measuredAt: DateTime(2026, 10, 6, 8)),
  ]),
  query: TrendQuery.custom(DateTime(2026, 10, 5), DateTime(2026, 10, 6)),
);

Future<void> pumpCardDialog(
  WidgetTester tester,
  Widget card,
  GlobalKey key,
) async {
  BuildContext? contextOut;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Builder(
        builder: (ctx) {
          contextOut ??= ctx;
          return const Scaffold(body: SizedBox());
        },
      ),
    ),
  );
  showDialog<void>(
    context: contextOut!,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => Center(
      child: RepaintBoundary(key: key, child: card),
    ),
  );
  // dialog 首帧 + 推过入场动画与卡片内动画，确保无 pending 帧标记
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<Uint8List?> captureStable(WidgetTester tester, GlobalKey key) async {
  Uint8List? bytes;
  Object? error;
  await tester.runAsync(() async {
    try {
      bytes = await CardCapturer.capture(key);
    } catch (e) {
      error = e;
    }
  });
  assert(() {
    if (error != null) {
      // 需求：捕获必须在渲染稳定后成功；暴露断言细节便于排查
      // ignore: avoid_print
      print('captureStable error: $error');
    }
    return true;
  }());
  return bytes;
}

void main() {
  group('captureCard 捕获链路', () {
    testWidgets('图表卡（fl_chart）渲染稳定后成功出 PNG', (tester) async {
      final key = GlobalKey();
      await pumpCardDialog(tester, trendCard(), key);
      final bytes = await captureStable(tester, key);
      expect(bytes, isNotNull);
      // PNG 魔数
      expect(bytes![0], 0x89);
      expect(bytes[1], 0x50);
      // 卡片 340 宽 @3x → 图像应有一定体量
      expect(bytes.length, greaterThan(5000));
    });

    testWidgets('记录卡成功出 PNG', (tester) async {
      final key = GlobalKey();
      await pumpCardDialog(
        tester,
        RecordShareCard(record: rec(8, 128, 76, pulse: 72)),
        key,
      );
      final bytes = await captureStable(tester, key);
      expect(bytes, isNotNull);
      expect(bytes![0], 0x89);
      expect(bytes[1], 0x50);
    });

    testWidgets('捕获挂起时 captureCard 超时兜底返回 null 且 dialog 关闭', (tester) async {
      BuildContext? contextOut;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (ctx) {
              contextOut ??= ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      // timeout=0 强制走超时路径（toImage future 总是异步完成）；
      // 整条链路留在 FakeAsync 时区，由 pump 推进 settle 延迟与超时
      final future = captureCard(
        contextOut!,
        RecordShareCard(record: rec(9, 120, 80)),
        settleDelay: const Duration(milliseconds: 80),
        timeout: Duration.zero,
      );
      await tester.pump(); // dialog 首帧，帧末排程捕获
      await tester.pumpAndSettle(); // 推过 settle 延迟与超时
      final bytes = await future;
      expect(bytes, isNull);
      // dialog 已自动关闭（卡片文本不在树上）
      expect(find.text('血压了么 · 血压记录'), findsNothing);
    });
  });
}
