/// PP-OCR 识别（CTC）解码与文本行几何工具（纯 Dart，无 IO）。
library;

import 'dart:ui';

/// 一条识别出的文本及其在原图中的包围盒。
class PpTextLine {
  const PpTextLine({
    required this.text,
    required this.rect,
    this.score = 0,
  });

  final String text;
  final Rect rect;
  final double score;

  /// 行内首个整数（如 "75 03" → 75，"120" → 120）。
  int? get leadingNumber {
    final m = RegExp(r'\d{1,4}').firstMatch(text);
    return m == null ? null : int.tryParse(m.group(0)!);
  }

  bool get hasNumber => leadingNumber != null;
}

/// CTC 贪心解码：blank=0，跳过重复与空白，映射到字典。
///
/// 字典表约定与 PP-OCR 一致：index 0 为 blank，1..n 依次对应
/// [dict] 每行一个字符，n+1 为空格。
String decodeCtc(List<int> indices, List<String> dict) {
  final out = StringBuffer();
  var prev = -1;
  for (final idx in indices) {
    if (idx == prev || idx == 0) {
      prev = idx;
      continue;
    }
    prev = idx;
    if (idx == dict.length + 1) {
      out.write(' ');
    } else if (idx >= 1 && idx <= dict.length) {
      out.write(dict[idx - 1]);
    }
  }
  return out.toString();
}

/// 把检测框按"行"分组（垂直中心重叠视为同行），行内按 x 升序。
List<List<PpTextLine>> groupIntoLines(List<PpTextLine> lines) {
  final sorted = [...lines]..sort((a, b) {
      final byRow = a.rect.center.dy.compareTo(b.rect.center.dy);
      return byRow != 0 ? byRow : a.rect.left.compareTo(b.rect.left);
    });
  final groups = <List<PpTextLine>>[];
  for (final l in sorted) {
    final h = l.rect.height;
    final group = groups.lastOrNull;
    if (group != null) {
      final lastRect = group.last.rect;
      final dy = (l.rect.center.dy - lastRect.center.dy).abs();
      if (dy < 0.6 * (h + lastRect.height) / 2 + 8) {
        group.add(l);
        continue;
      }
    }
    groups.add([l]);
  }
  for (final g in groups) {
    g.sort((a, b) => a.rect.left.compareTo(b.rect.left));
  }
  return groups;
}
