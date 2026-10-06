/// DBNet 文本检测后处理（纯 Dart，无 IO，便于单元测试）。
///
/// 输入 PP-OCR 检测模型输出的概率图（单通道 H×W）：
/// * [quadsFromProbMap] 完整后处理：连通域 → 凸包 → 最小面积旋转矩形 →
///   unclip 扩张，输出**旋转四边形**（配合透视裁剪使用，识别质量更好）；
/// * [boxesFromProbMap] 简化后处理：输出轴对齐框（调试用）。
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// 检测出的文本框（轴对齐，调试用）。
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

/// 检测出的文本四边形（原图坐标，四角按周向顺序：
/// 左上 → 右上 → 右下 → 左下，以矩形长边为"宽"）。
class DetQuad {
  const DetQuad({required this.corners, required this.score});

  /// 4 个角点，index 0..3 周向顺序。
  final List<Offset> corners;
  final double score;

  Rect get bounds {
    final xs = corners.map((c) => c.dx);
    final ys = corners.map((c) => c.dy);
    return Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min),
        xs.reduce(math.max), ys.reduce(math.max));
  }

  /// 边长（宽=角点 0-1 边，高=角点 1-2 边）。
  double get edge01 {
    final dx = corners[1].dx - corners[0].dx;
    final dy = corners[1].dy - corners[0].dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get edge12 {
    final dx = corners[2].dx - corners[1].dx;
    final dy = corners[2].dy - corners[1].dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _Point2 {
  _Point2(this.x, this.y);
  final double x;
  final double y;
}

double _cross(_Point2 o, _Point2 a, _Point2 b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Andrew 凸包（单调链）。
List<_Point2> _convexHull(List<_Point2> pts) {
  if (pts.length < 3) return pts;
  final sorted = [...pts]..sort((a, b) {
      final c = a.x.compareTo(b.x);
      return c != 0 ? c : a.y.compareTo(b.y);
    });
  final lower = <_Point2>[];
  for (final p in sorted) {
    while (lower.length >= 2 &&
        _cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <_Point2>[];
  for (final p in sorted.reversed) {
    while (upper.length >= 2 &&
        _cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  upper.removeLast();
  lower.removeLast();
  return [...lower, ...upper];
}

/// 最小面积旋转矩形（枚举凸包边为基准方向）。
({_Point2 center, _Point2 u, _Point2 v, double w, double h}) _minAreaRect(
    List<_Point2> hull) {
  var bestArea = double.infinity;
  var bestU = _Point2(1, 0);
  var bestV = _Point2(0, 1);
  var bestW = 0.0;
  var bestH = 0.0;
  var bestC = _Point2(0, 0);

  for (var i = 0; i < hull.length; i++) {
    final p1 = hull[i];
    final p2 = hull[(i + 1) % hull.length];
    final ex = p2.x - p1.x;
    final ey = p2.y - p1.y;
    final len = math.sqrt(ex * ex + ey * ey);
    if (len < 1e-6) continue;
    final ux = ex / len;
    final uy = ey / len;
    final vx = -uy;
    final vy = ux;

    var minU = double.infinity, maxU = double.negativeInfinity;
    var minV = double.infinity, maxV = double.negativeInfinity;
    for (final p in hull) {
      final pu = p.x * ux + p.y * uy;
      final pv = p.x * vx + p.y * vy;
      if (pu < minU) minU = pu;
      if (pu > maxU) maxU = pu;
      if (pv < minV) minV = pv;
      if (pv > maxV) maxV = pv;
    }
    final w = maxU - minU;
    final h = maxV - minV;
    final area = w * h;
    if (area < bestArea) {
      bestArea = area;
      bestU = _Point2(ux, uy);
      bestV = _Point2(vx, vy);
      bestW = w;
      bestH = h;
      bestC = _Point2(
        ux * ((minU + maxU) / 2) + vx * ((minV + maxV) / 2),
        uy * ((minU + maxU) / 2) + vy * ((minV + maxV) / 2),
      );
    }
  }
  return (center: bestC, u: bestU, v: bestV, w: bestW, h: bestH);
}

/// 从概率图提取文本四边形（完整 DB 后处理）。
///
/// 返回按阅读顺序（行优先）排序的四边形列表，坐标为概率图坐标系。
List<DetQuad> quadsFromProbMap({
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
  final quads = <DetQuad>[];

  for (var start = 0; start < bin.length; start++) {
    if (bin[start] == 0 || visited[start] == 1) continue;
    queue.add(start);
    visited[start] = 1;

    var count = 0;
    var probSum = 0.0;
    final boundary = <_Point2>[];

    while (queue.isNotEmpty) {
      final idx = queue.removeFirst();
      final x = idx % width;
      final y = idx ~/ width;
      count++;
      probSum += prob[idx];

      final isBoundary = x == 0 ||
          y == 0 ||
          x == width - 1 ||
          y == height - 1 ||
          bin[idx - 1] == 0 ||
          bin[idx + 1] == 0 ||
          bin[idx - width] == 0 ||
          bin[idx + width] == 0;
      if (isBoundary) boundary.add(_Point2(x.toDouble(), y.toDouble()));

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
    if (boundary.length < 3) continue;

    final hull = _convexHull(boundary);
    final rect = _minAreaRect(hull);

    // unclip：offset = area * ratio / perimeter，宽高各外扩 2*offset
    final perimeter = 2 * (rect.w + rect.h);
    final offset = rect.w * rect.h * unclipRatio / perimeter;
    final w = rect.w + 2 * offset;
    final h = rect.h + 2 * offset;
    // 保证"宽"为长边（识别条横放）
    final uLong = w >= h ? rect.u : rect.v;
    final vShort = w >= h ? rect.v : rect.u;
    final halfLong = math.max(w, h) / 2;
    final halfShort = math.min(w, h) / 2;

    final cx = rect.center.x;
    final cy = rect.center.y;
    Offset corner(double su, double sv) => Offset(
        cx + uLong.x * halfLong * su + vShort.x * halfShort * sv,
        cy + uLong.y * halfLong * su + vShort.y * halfShort * sv);
    quads.add(DetQuad(
      corners: [
        corner(-1, -1),
        corner(1, -1),
        corner(1, 1),
        corner(-1, 1),
      ],
      score: score,
    ));
  }

  quads.sort((a, b) {
    final ba = a.bounds;
    final bb = b.bounds;
    final byRow = (ba.top + ba.bottom).compareTo(bb.top + bb.bottom);
    return byRow != 0 ? byRow : ba.left.compareTo(bb.left);
  });
  return quads;
}

/// 点集的最小面积旋转矩形四角（周向：0→1 为长边、1→2 为短边）。
///
/// 退化点集（<3 点或共线凸包）返回空列表。
List<Offset> minAreaRectCorners(List<Offset> points) {
  if (points.length < 3) return const [];
  final hull =
      _convexHull([for (final p in points) _Point2(p.dx, p.dy)]);
  if (hull.length < 3) return const [];
  final rect = _minAreaRect(hull);
  final halfLong = rect.w / 2;
  final halfShort = rect.h / 2;
  Offset corner(double su, double sv) => Offset(
      rect.center.x + rect.u.x * halfLong * su + rect.v.x * halfShort * sv,
      rect.center.y + rect.u.y * halfLong * su + rect.v.y * halfShort * sv);
  return [corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1)];
}

/// 从概率图提取轴对齐文本框（简化后处理，调试用）。
List<DetBox> boxesFromProbMap({
  required Float32List prob,
  required int width,
  required int height,
  double thresh = 0.3,
  double boxThresh = 0.45,
  double unclipRatio = 1.8,
  int minArea = 24,
}) {
  final quads = quadsFromProbMap(
    prob: prob,
    width: width,
    height: height,
    thresh: thresh,
    boxThresh: boxThresh,
    unclipRatio: unclipRatio,
    minArea: minArea,
  );
  return quads
      .map((q) => DetBox(
            left: q.bounds.left.floor(),
            top: q.bounds.top.floor(),
            right: q.bounds.right.ceil(),
            bottom: q.bounds.bottom.ceil(),
            score: q.score,
          ))
      .toList();
}
