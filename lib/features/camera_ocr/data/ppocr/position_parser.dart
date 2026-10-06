/// 位置感知的血压数值解析：利用 OCR 文本框的几何关系配对标签与数值。
///
/// 规则（按可靠度降序）：
/// 1. 标签配对：找"高压/低压/脉搏（含 SYS/DIA/PULSE 等）"标签框，
///    取其右侧最近的数值框（纵向偏移容忍），作为对应读数；
/// 2. 传统兜底：把全部文本拼接后交给既有 OcrBpParser（分数式/标签式/相邻式）。
///
/// 输入仅依赖 [PpTextLine]（含文本与包围盒），输出域层 OcrParseResult。
library;

import 'dart:ui';

import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';

import 'rec_decode.dart';
import 'seven_segment.dart';

/// 七段码 LCD 读数 → 血压候选（行序自上而下：收缩压 → 舒张压 → 脉搏）。
///
/// 规则：首个收缩压区间数值为收缩压；其后首个舒张压区间且小于收缩压的
/// 数值为舒张压；再其后首个脉搏区间数值为脉搏（多余数值如时间/记忆序号
/// 靠区间过滤）。七段字形经逐段采样校验，误读概率低，置信度高于通用 OCR。
OcrParseResult? parseLcdReadout(LcdReadout readout) {
  int? sys, dia, pulse;
  for (final n in readout.numbers) {
    final v = n.value;
    if (sys == null && v >= 60 && v <= 260) {
      sys = v;
    } else if (sys != null &&
        dia == null &&
        v >= 40 &&
        v <= 160 &&
        v < sys) {
      dia = v;
    } else if (sys != null &&
        dia != null &&
        pulse == null &&
        v >= 30 &&
        v <= 220) {
      pulse = v;
    }
  }
  if (sys == null || dia == null) return null;
  final c = BpCandidate(
    systolic: sys,
    diastolic: dia,
    pulse: pulse,
    confidence: pulse != null ? 0.92 : 0.88,
    pattern: 'lcd',
  );
  if (!c.plausible) return null;
  return OcrParseResult(candidates: [c]);
}

/// 把带位置的文本行解析为血压候选。
OcrParseResult parsePositionedLines(List<PpTextLine> lines) {
  final flat = <(String, Rect)>[];
  for (final group in groupIntoLines(lines)) {
    for (final l in group) {
      final text = l.text.trim();
      if (text.isNotEmpty) flat.add((text, l.rect));
    }
  }
  if (flat.isEmpty) return const OcrParseResult(candidates: []);

  final candidates = <BpCandidate>[];

  final sys = _valueNearLabel(flat, const ['高压', '收缩压', '收缩', 'SYS', 'HYP']);
  final dia = _valueNearLabel(flat, const ['低压', '舒张压', '舒张', 'DIA', 'DIAS']);
  final pulse = _valueNearLabel(
      flat, const ['脉搏', '脉率', '心率', 'PULSE', 'PUL', 'HR']);

  if (sys != null && dia != null) {
    final c = BpCandidate(
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      confidence: 0.78 + (pulse != null ? 0.08 : 0.0),
      pattern: 'position-label',
    );
    if (c.plausible) candidates.add(c);
  }

  // 传统文本兜底（分数式/文本标签式仍可能命中）
  final joined =
      flat.map((e) => e.$1).join(' ');
  candidates.addAll(const OcrBpParser().parse(joined).candidates);

  final seen = <String, BpCandidate>{};
  for (final c in candidates) {
    final key = '${c.systolic}-${c.diastolic}-${c.pulse ?? "_"}';
    final old = seen[key];
    if (old == null || c.confidence > old.confidence) seen[key] = c;
  }
  final list = seen.values.where((c) => c.plausible).toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  return OcrParseResult(candidates: list);
}

/// 取标签框右侧最近的数值（同行/近行优先，距离 = 横距 + 纵距加权）。
int? _valueNearLabel(
    List<(String, Rect)> boxes, List<String> labels) {
  final labelBox = _findLabel(boxes, labels);
  if (labelBox == null) return null;

  final candidates = <(int, double)>[]; // (value, distance)
  for (final (text, rect) in boxes) {
    if (rect == labelBox) continue;
    if (rect.left <= labelBox.right) continue; // 必须在标签右侧
    final value = _leadingBpValue(text);
    if (value == null) continue;
    final dx = rect.left - labelBox.right;
    final dy = (rect.center.dy - labelBox.center.dy).abs();
    if (dy > labelBox.height * 4 + 120) continue; // 排除其他行
    candidates.add((value, dx + dy * 2.0));
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.$2.compareTo(b.$2));
  return candidates.first.$1;
}

Rect? _findLabel(List<(String, Rect)> boxes, List<String> labels) {
  Rect? best;
  var bestScore = double.infinity;
  for (final (text, rect) in boxes) {
    final lower = text.toLowerCase();
    if (RegExp(r'\d').hasMatch(text)) continue; // 含数字的是数值框，不是标签
    for (final label in labels) {
      if (lower.contains(label.toLowerCase())) {
        // 越小的框越像纯标签
        final score = rect.width + rect.height;
        if (score < bestScore) {
          best = rect;
          bestScore = score;
        }
      }
    }
  }
  return best;
}

/// 提取文本中首个血压合理区间的数值（过滤 mmHg/unit/两位序号噪声靠区间完成）。
int? _leadingBpValue(String text) {
  final m = RegExp(r'\d{2,3}').firstMatch(text);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}
