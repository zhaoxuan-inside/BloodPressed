import 'dart:typed_data';
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:blood_pressed/core/design/bp_category_style.dart';
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

/// 卡片统一宽度。
const double _cardWidth = 340;

/// 卡片圆角。
const double _cardRadius = 24;

/// 单次记录分享卡。
///
/// 深色渐变 + 径向光斑 + ECG 主题装饰 + 玻璃拟态元素，保证导出 PNG 的质感。
class RecordShareCard extends StatelessWidget {
  const RecordShareCard({super.key, required this.record});

  final BpRecord record;

  static const List<Color> _gradient = [
    Color(0xFF06231F),
    Color(0xFF0B4A41),
    Color(0xFF118877),
  ];

  @override
  Widget build(BuildContext context) {
    final category = BpCategory.fromValues(record.systolic, record.diastolic);
    final l10n = AppLocalizations.of(context);
    final categoryColor = BpCategoryStyle.colorOf(category);
    return _CardShell(
      gradient: _gradient,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandBadge(icon: Icons.favorite),
          const SizedBox(height: 18),
          Text(l10n.shareCardRecordHeader, style: _brandLabelStyle),
          const SizedBox(height: 14),
          // hero 数值：窄屏安全（卡片定宽 340，数值区整体缩放）
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${record.systolic}', style: _heroStyle),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('/',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w200)),
                ),
                Text('${record.diastolic}', style: _heroStyle),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UnitPill(text: 'mmHg'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _GlassPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: categoryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: categoryColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(categoryLabel(l10n, category), style: _pillStyle),
                  ],
                ),
              ),
              const Spacer(),
              if (record.pulse != null)
                _GlassPill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_border,
                          color: Colors.white70, size: 13),
                      const SizedBox(width: 5),
                      Text('${record.pulse} ${l10n.pulseUnit}',
                          style: _pillStyle),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.cardMeasuredAt(
                Fmt.full(record.measuredAt), armLabel(l10n, record.arm)),
            style: _metaStyle,
          ),
          const SizedBox(height: 14),
          const _HairlineDivider(),
          const SizedBox(height: 12),
          _CardFooter(text: l10n.cardFooterRecord),
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

  static const List<Color> _gradient = [
    Color(0xFF07253F),
    Color(0xFF124A6E),
    Color(0xFF118877),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CardShell(
      gradient: _gradient,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandBadge(icon: Icons.monitor_heart),
          const SizedBox(height: 18),
          Text(l10n.shareCardStatsHeader, style: _brandLabelStyle),
          const SizedBox(height: 8),
          Text(
            l10n.statsOverviewTitle(_daysLabel(l10n, days)),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: l10n.avgBpLabel,
                  value:
                      '${stats.avgSystolic.toStringAsFixed(0)} / ${stats.avgDiastolic.toStringAsFixed(0)}',
                  unit: 'mmHg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: l10n.avgPulseLabel,
                  value: stats.avgPulse?.toStringAsFixed(0) ?? '—',
                  unit: l10n.pulseUnit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: l10n.countLabel,
                  value: '${stats.count}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: l10n.onTargetRateLabel,
                  value:
                      '${(stats.normalRate * 100).toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricTile(
            label: l10n.bpRangeLabel,
            value: l10n.bpRangeValue(stats.minSystolic, stats.maxSystolic,
                stats.minDiastolic, stats.maxDiastolic),
            small: true,
          ),
          const SizedBox(height: 14),
          const _HairlineDivider(),
          const SizedBox(height: 12),
          _CardFooter(text: l10n.cardFooterStats),
        ],
      ),
    );
  }

  static String _daysLabel(AppLocalizations l10n, int days) {
    if (days <= 7) return l10n.days7;
    if (days <= 30) return l10n.days30;
    if (days <= 90) return l10n.days90;
    return l10n.daysPeriod;
  }
}

// ---------------------------------------------------------------------------
// 卡片视觉构件（两张卡共用）
// ---------------------------------------------------------------------------

/// 卡片外壳：深色渐变 + 装饰层（光斑/ECG）+ 高光描边 + 顶部光泽。
class _CardShell extends StatelessWidget {
  const _CardShell({required this.gradient, required this.child});

  final List<Color> gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.55, 1],
          colors: gradient,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius - 1),
        child: Stack(
          children: [
            const Positioned.fill(child: _CardDecor()),
            // 顶部光泽：白色自上而下淡出，强化玻璃质感
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 110,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(22), child: child),
          ],
        ),
      ),
    );
  }
}

/// 卡片装饰层：径向光斑 + 装饰圆 + 低透明度 ECG 心电波形。
class _CardDecor extends StatelessWidget {
  const _CardDecor();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CardDecorPainter(),
      ),
    );
  }
}

class _CardDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Color white(double a) => Colors.white.withValues(alpha: a);

    // 右上径向光斑
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.86, size.height * 0.06),
        size.width * 0.55,
        [white(0.14), white(0)],
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    // 左下装饰圆（填充 + 描边各一）
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.92),
      64,
      Paint()..color = white(0.05),
    );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 1.02),
      96,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = white(0.10),
    );

    // ECG 心电波形：横贯卡片中部，贴合血压主题
    final ecg = Path();
    final baseY = size.height * 0.60;
    final cycle = 96.0;
    ecg.moveTo(-cycle, baseY);
    for (var x = -cycle; x < size.width + cycle; x += cycle) {
      void lineTo(double dx, double dy) => ecg.lineTo(x + dx, baseY + dy);
      void wave(double cdx, double cdy, double edx) =>
          ecg.quadraticBezierTo(x + cdx, baseY + cdy, x + edx, baseY);
      lineTo(cycle * 0.22, 0);
      wave(cycle * 0.28, -6, cycle * 0.34); // P 波
      lineTo(cycle * 0.40, 3);
      lineTo(cycle * 0.46, -20); // R 波上行
      lineTo(cycle * 0.52, 10); // S 波下行
      lineTo(cycle * 0.58, 0);
      wave(cycle * 0.72, -8, cycle * 0.86); // T 波
      lineTo(cycle, 0);
    }
    canvas.drawPath(
      ecg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = white(0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _CardDecorPainter oldDelegate) => false;
}

/// 品牌徽章：圆角玻璃块 + 主题图标。
class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 15),
    );
  }
}

/// 玻璃 pill（分级/脉搏）。
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

/// 单位小徽章。
class _UnitPill extends StatelessWidget {
  const _UnitPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// 统计卡玻璃指标瓦片。
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.small = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: small ? 11.5 : 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 14.5 : 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 渐隐细分隔线。
class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }
}

/// 卡片底部标语行。
class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Icon(Icons.monitor_heart_outlined,
            size: 13, color: Colors.white.withValues(alpha: 0.45)),
      ],
    );
  }
}

// 文字样式常量（两张卡共享）。

const _brandLabelStyle = TextStyle(
  color: Colors.white70,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.4,
);

TextStyle get _heroStyle => TextStyle(
      color: Colors.white,
      fontSize: 62,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ],
    );

const _pillStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

const _metaStyle = TextStyle(
  color: Colors.white70,
  fontSize: 12,
  height: 1.4,
);
