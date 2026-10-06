import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/core/utils/formatters.dart';

/// 卡片截图工具。
class CardCapturer {
  CardCapturer._();

  static Future<Uint8List> capture(GlobalKey key,
      {double pixelRatio = 3}) async {
    final boundary = key.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('分享卡片尚未渲染完成');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('卡片导出失败');
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
          const Row(
            children: [
              Icon(Icons.favorite, color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                '血压了么 · 血压记录',
                style: TextStyle(
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
                child: Text(category.label,
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
                    Text('${record.pulse} 次/分',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${Fmt.full(record.measuredAt)} · ${record.arm.label}测量',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Divider(color: Colors.white24, height: 28),
          const Text(
            '坚持测量，守护心血管健康 💪',
            style: TextStyle(color: Colors.white, fontSize: 12),
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
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                '血压了么 · 血压周报',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '近${_daysLabel(days)}血压概览',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _row('平均血压',
              '${stats.avgSystolic.toStringAsFixed(0)} / ${stats.avgDiastolic.toStringAsFixed(0)} mmHg'),
          _row('血压范围',
              '高压 ${stats.minSystolic}~${stats.maxSystolic} · 低压 ${stats.minDiastolic}~${stats.maxDiastolic}'),
          if (stats.avgPulse != null)
            _row('平均脉搏',
                '${stats.avgPulse!.toStringAsFixed(0)} 次/分'),
          _row('测量次数', '${stats.count} 次'),
          _row('达标率（<135/85）',
              '${(stats.normalRate * 100).toStringAsFixed(0)}%'),
          const Divider(color: Colors.white24, height: 28),
          const Text(
            '规律监测，心中有数 📈',
            style: TextStyle(color: Colors.white, fontSize: 12),
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

  static String _daysLabel(int days) {
    if (days <= 7) return '7天';
    if (days <= 30) return '30天';
    if (days <= 90) return '90天';
    return '一段时间';
  }
}
