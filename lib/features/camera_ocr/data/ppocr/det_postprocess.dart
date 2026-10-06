/// DBNet 文本检测后处理（纯 Dart，无 IO，便于单元测试）。
///
/// 输入 PP-OCR 检测模型输出的概率图（单通道 H×W），输出文本框列表
/// （轴对齐，已按 unclip 扩张并缩放回原图坐标）。
library;

import 'dart:collection';
import 'dart:typed_data';

/// 检测出的文本框（原图坐标，轴对齐）。
class DetBox {
  const DetBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
  final double score;

  int get width => right - left;
  int get height => bottom - top;
  int get area => width * height;

  @override
  String toString() =>
      'DetBox($left,$top,$right,$bottom,score=${score.toStringAsFixed(2)})';
}

/// 从概率图提取文本框。
///
/// * [prob] 长度 h*w 的概率图；
/// * [thresh] 二值化阈值（DB 默认 0.3）；
/// * [boxThresh] 框内平均分过滤阈值（DB 默认 0.5，取略宽松值）；
/// * [unclipRatio] 扩张系数（DB 默认 1.5~2.0）；
/// * [minArea] 最小像素面积（过滤噪点）。
List<DetBox> boxesFromProbMap({
  required Float32List prob,
  required int width,
  required int height,
  double thresh = 0.3,
  double boxThresh = 0.45,
  double unclipRatio = 1.8,
  int minArea = 24,
}) {
  final bin = Uint8List(width * height);
  for (var i = 0; i < bin.length; i++) {
    if (prob[i] >= thresh) bin[i] = 1;
  }

  final visited = Uint8List(width * height);
  final queue = Queue<int>();
  final boxes = <DetBox>[];

  for (var start = 0; start < bin.length; start++) {
    if (bin[start] == 0 || visited[start] == 1) continue;
    queue.add(start);
    visited[start] = 1;

    var minX = width, minY = height, maxX = 0, maxY = 0;
    var count = 0;
    var probSum = 0.0;
    final memberIdx = <int>[];

    while (queue.isNotEmpty) {
      final idx = queue.removeFirst();
      memberIdx.add(idx);
      final x = idx % width;
      final y = idx ~/ width;
      count++;
      probSum += prob[idx];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      if (x > 0 && bin[idx - 1] == 1 && visited[idx - 1] == 0) {
        visited[idx - 1] = 1;
        queue.add(idx - 1);
      }
      if (x < width - 1 && bin[idx + 1] == 1 && visited[idx + 1] == 0) {
        visited[idx + 1] = 1;
        queue.add(idx + 1);
      }
      if (y > 0 && bin[idx - width] == 1 && visited[idx - width] == 0) {
        visited[idx - width] = 1;
        queue.add(idx - width);
      }
      if (y < height - 1 && bin[idx + width] == 1 && visited[idx + width] == 0) {
        visited[idx + width] = 1;
        queue.add(idx + width);
      }
    }

    if (count < minArea) continue;
    final score = probSum / count;
    if (score < boxThresh) continue;

    // unclip：按 bbox 面积/周长比向外扩张（DB 简化版，轴对齐近似）
    final bw = maxX - minX + 1;
    final bh = maxY - minY + 1;
    final perimeter = 2 * (bw + bh);
    final offset = (bw * bh * unclipRatio / perimeter).ceil();
    final l = (minX - offset).clamp(0, width - 1);
    final t = (minY - offset).clamp(0, height - 1);
    final r = (maxX + offset).clamp(0, width - 1);
    final b = (maxY + offset).clamp(0, height - 1);
    boxes.add(DetBox(left: l, top: t, right: r, bottom: b, score: score));
  }

  boxes.sort((a, b) {
    final byRow = (a.top + a.bottom).compareTo(b.top + b.bottom);
    return byRow != 0 ? byRow : a.left.compareTo(b.left);
  });
  return boxes;
}
