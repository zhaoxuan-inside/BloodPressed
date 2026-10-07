import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 卡片截图工具。
class CardCapturer {
  CardCapturer._();

  static Future<Uint8List> capture(GlobalKey key,
      {double pixelRatio = 3}) async {
    final boundary = key.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError(AppLocaleService.auto.cardNotReady);
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError(AppLocaleService.auto.cardExportFailed);
    }
    return data.buffer.asUint8List();
  }
}

/// 单次记录分享卡。
class RecordShareCard extends StatelessWidget {
  const RecordShareCard({super.key, required this.record});

  final BpRecord record;

  @override
  Widget build(BuildContext context) {
    final category = BpCategory.fromValues(record.systolic, record.diastolic);
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                l10n.shareCardRecordHeader,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${record.systolic}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        height: 1.0,
                        fontWeight: FontWeight.w800)),
                const Text('/',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 34,
                        fontWeight: FontWeight.w300)),
                Text('${record.diastolic}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        height: 1.0,
                        fontWeight: FontWeight.w800)),
                const Padding(
                  padding: EdgeInsets.only(left: 6, bottom: 6),
                  child: Text('mmHg',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(categoryLabel(l10n, category),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (record.pulse != null)
                Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('${record.pulse} ${l10n.pulseUnit}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.cardMeasuredAt(
                Fmt.full(record.measuredAt), armLabel(l10n, record.arm)),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Divider(color: Colors.white24, height: 28),
          Text(
            l10n.cardFooterRecord,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 统计摘要分享卡。
class StatsShareCard extends StatelessWidget {
  const StatsShareCard({super.key, required this.stats, required this.days});

  final BpStats stats;
  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF00897B)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                l10n.shareCardStatsHeader,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.statsOverviewTitle(_daysLabel(l10n, days)),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _row(l10n.avgBpLabel,
              '${stats.avgSystolic.toStringAsFixed(0)} / ${stats.avgDiastolic.toStringAsFixed(0)} mmHg'),
          _row(l10n.bpRangeLabel,
              l10n.bpRangeValue(stats.minSystolic, stats.maxSystolic, stats.minDiastolic, stats.maxDiastolic)),
          if (stats.avgPulse != null)
            _row(l10n.avgPulseLabel,
                '${stats.avgPulse!.toStringAsFixed(0)} ${l10n.pulseUnit}'),
          _row(l10n.countLabel, l10n.timesValue(stats.count)),
          _row(l10n.onTargetRateLabel,
              '${(stats.normalRate * 100).toStringAsFixed(0)}%'),
          const Divider(color: Colors.white24, height: 28),
          Text(
            l10n.cardFooterStats,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  static String _daysLabel(AppLocalizations l10n, int days) {
    if (days <= 7) return l10n.days7;
    if (days <= 30) return l10n.days30;
    if (days <= 90) return l10n.days90;
    return l10n.daysPeriod;
  }
}
