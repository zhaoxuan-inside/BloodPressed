/// 趋势/分析卡分享流程：透明 dialog 捕获 → PNG 落盘 → 分享弹层
/// （微信好友/朋友圈/系统）。趋势页与全屏横屏页共用。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/export/data/wechat_share_service.dart';
import 'package:blood_pressed/features/export/presentation/card_capture_dialog.dart';
import 'package:blood_pressed/features/export/presentation/share_card_widgets.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 捕获并分享趋势图表卡。
Future<void> shareTrendChart(
  BuildContext context,
  WidgetRef ref, {
  required List<DayPoint> points,
  required TrendQuery query,
  required String title,
  required double avgSystolic,
  required double avgDiastolic,
  required int count,
}) {
  final l10n = AppLocalizations.of(context);
  final card = TrendShareCard(
    title: title,
    points: points,
    query: query,
    avgSystolic: avgSystolic,
    avgDiastolic: avgDiastolic,
    count: count,
  );
  return _shareCard(context, ref, card, text: l10n.shareText);
}

/// 捕获并分享规律分析卡。
Future<void> shareAnalysis(
  BuildContext context,
  WidgetRef ref, {
  required BpAnalysis analysis,
  required String conclusion,
  required String title,
}) {
  final card = AnalysisShareCard(
    title: title,
    conclusion: conclusion,
    analysis: analysis,
  );
  return _shareCard(context, ref, card, text: conclusion);
}

Future<void> _shareCard(
  BuildContext context,
  WidgetRef ref,
  Widget card, {
  required String text,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    final bytes = await captureCard(context, card);
    if (!context.mounted) return;
    if (bytes == null) {
      messenger.showSnackBar(
          SnackBar(content: Text(AppLocaleService.auto.cardCaptureFailed)));
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}${Platform.pathSeparator}bp_card_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    if (!context.mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(l10n.shareWechat),
              onTap: () => Navigator.pop(context, 'wechat'),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(l10n.shareMoments),
              onTap: () => Navigator.pop(context, 'timeline'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(l10n.shareMore),
              onTap: () => Navigator.pop(context, 'system'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final settings = ref.read(appSettingsProvider);
    final service = ShareService(
      wechatAppId: settings.wechatAppId,
      universalLink: settings.wechatUniversalLink,
    );
    final result = switch (choice) {
      'wechat' => await service.shareImage(file, text: text),
      'timeline' => await service.shareImage(file, text: text, toTimeline: true),
      _ => await service.shareFile(file, text: text),
    };
    messenger.showSnackBar(SnackBar(content: Text(result)));
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text(AppLocaleService.auto.shareFailed(e.toString()))));
  }
}

/// 「AI 分析」入口守卫：无生效模型 → 提示「尚未配置大模型」并返回
/// false（调用方决定是否引导去模型配置）；有模型则写入待发送 prompt
/// 并返回 true（调用方随后 push /assistant，助手页 initState 消费）。
Future<bool> guardAndSendAnalysis(
  BuildContext context,
  WidgetRef ref, {
  required String prompt,
}) async {
  final l10n = AppLocalizations.of(context);
  if (ref.read(effectiveLlmProfileProvider) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.llmNotConfigured)));
    return false;
  }
  ref.read(pendingAssistantPromptProvider.notifier).state = prompt;
  return true;
}
