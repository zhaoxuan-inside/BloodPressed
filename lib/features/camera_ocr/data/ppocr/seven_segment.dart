/// 七段码 LCD 读数识别（纯 Dart，无 Flutter / onnxruntime 依赖，便于单元测试）。
///
/// 血压计的七段数码管是巨型定制字形，通用文本检测/识别（含 PP-OCRv5 与
/// RapidOCR 参考实现）均无法稳定检出与读出（plan-006 宿主机对照实验结论）。
/// 本读取器走专用路径：
/// 1. 彩色背光定位：HSV 饱和蓝/青掩码 → 最大矩形连通域 → 旋转矩形四角；
/// 2. 仿射矫正为灰度图（长边限制内缩放，统一处理尺度）；
/// 3. 照度归一化二值化（盒模糊背景比值），抗背光梯度与屏幕翻拍摩尔纹；
/// 4. 连通域过滤噪声 → 行带 → 列簇 → 行子块（回接段间断裂的笔画，如 "1"）；
/// 5. 七段中心采样分类（细长字形按宽高比直判 "1"），按间距分组为数值；
/// 6. 输出各显示行数值（自上而下）。
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'det_postprocess.dart';

/// RGBA 像素图（行主序，每像素 4 字节）。
class SegImage {
  SegImage(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}

/// LCD 上读出的一个数值（同一显示行的数字自左向右拼接）。
class LcdNumberGroup {
  const LcdNumberGroup({
    required this.value,
    required this.bandY,
    required this.digitCount,
  });

  final int value;

  /// 所在显示行的纵向起点（矫正后 LCD 坐标，随行号递增）。
  final int bandY;
  final int digitCount;

  @override
  String toString() => '$value(bandY=$bandY,digits=$digitCount)';
}

/// 一次七段码读数结果（按显示行自上而下）。
class LcdReadout {
  const LcdReadout(this.numbers);

  final List<LcdNumberGroup> numbers;

  @override
  String toString() => 'LcdReadout($numbers)';
}

/// 显示行（内部结构：y0..y1 与行内数字）。
class _Band {
  int y0 = 0;
  int y1 = 0;
  final digits = <_Digit>[];
}

class _Digit {
  _Digit({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.mask,
  });

  final int x;
  final int y;
  final int w;
  final int h;
  final Uint8List mask;
  int? digit;
}

/// 连通域（像素索引列表）。
class _Component {
  final pixels = <int>[];
  int get area => pixels.length;
}

class SevenSegmentReader {
  /// 诊断日志钩子（宿主机测试 / 客户端 kDebugMode 排查用）。
  static void Function(String message)? logger;

  static void _log(String message) => logger?.call(message);

  /// 诊断工件：每次单定向提取的 (宽, 高, 矫正灰度图, 二值图, 去噪掩码, 数值)。
  /// 仅在 [collectDebugArtifacts] 为 true 时收集（含位图，勿常开）。
  static bool collectDebugArtifacts = false;
  static final debugOrientations = <List<Object>>[];

  /// 数字分组时的最大间距（相对数字高度）。
  static const double _groupGapRatio = 0.55;

  /// "1" 直判的宽高比上限。
  static const double _oneAspect = 0.3;

  /// 单字宽高比上限：超过视为多字粘连（误读成单值比读不出更危险）。
  static const double _maxDigitAspect = 0.85;

  /// 七段采样网格。
  static const int _gridW = 32, _gridH = 56;

  /// 矫正后 LCD 长边上限（统一处理尺度，控制耗时与噪声粒度）。
  static const int _lcdMaxSide = 900;

  /// 七段段检测（在 32×56 采样网格上，行列填充峰值法）。
  ///
  /// 竖墙（b/c/e/f）= 对应侧条带内的**列**填充峰值；横杠（a/d/g）=
  /// 对应横带内的**行**填充峰值。斜体字形（墙随高度横移）、笔画宽度
  /// 变化、摩尔纹残点都天然容忍，远稳于固定坐标采样窗。
  static const double _wallOnFill = 0.50; // 竖墙判定（列填充率）
  static const double _barOnFill = 0.55; // 横杠判定（行填充率）

  /// 数字 → 点亮的段。
  static const _segMap = <int, String>{
    0: 'abcdef',
    1: 'bc',
    2: 'abged',
    3: 'abgcd',
    4: 'fgbc',
    5: 'afgcd',
    6: 'afgedc',
    7: 'abc',
    8: 'abcdefg',
    9: 'abcdfg',
  };

  /// 段名（diff 计算顺序）。
  static const _zonesKeys = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];

  /// 主入口：读出 LCD 上的数值；未找到彩色背光屏或无可读数字时返回 null。
  ///
  /// 行方向未知（三诺竖屏 / 欧姆龙横屏），两个 90° 定向都提取，
  /// 取合理数值得分更高者。
  LcdReadout? read(SegImage img) {
    debugOrientations.clear();
    final quad = _locateLcdQuad(img);
    if (quad == null) return null;
    final best = _readOrientation(img, quad);
    final alt = _readOrientation(img, _rotated(quad));
    if (best == null) return alt?.$1;
    if (alt == null) return best.$1;
    return best.$2 >= alt.$2 ? best.$1 : alt.$1;
  }

  /// 单定向提取，返回 (读数, 得分)。
  (LcdReadout, int)? _readOrientation(SegImage img, List<Offset> quad) {
    final lcd = _rectifyToGray(img, quad);
    final w = lcd.$1, h = lcd.$2, gray = lcd.$3;
    // 预模糊（_binarize 内）负责抑制摩尔纹防止笔画碎裂；
    // 不再做闭运算，否则会把相邻数字桥接成一个连通域。
    final bin = _binarize(gray, w, h);
    final clean = _filterComponents(bin, w, h);
    final numbers = _extractNumbers(clean, w, h);
    if (collectDebugArtifacts) {
      debugOrientations.add([w, h, gray, bin, clean, numbers]);
    }
    _log('rectified ${w}x$h quad=$quad numbers=$numbers');
    if (numbers.isEmpty) return null;
    var score = 0;
    for (final n in numbers) {
      if (n.value >= 60 && n.value <= 260) {
        score += 10;
      } else if (n.value >= 30 && n.value <= 220) {
        score += 5;
      }
      score += n.digitCount;
    }
    return (LcdReadout(numbers), score);
  }

  // ---------------- 1) LCD 定位 ----------------

  /// 在降采样图上找饱和蓝/青背光的旋转矩形，返回原图坐标四角
  /// （图像坐标周向顺序：左上→右上→右下→左下；行方向由 [read] 双定向解决）。
  List<Offset>? _locateLcdQuad(SegImage img) {
    final step = math.max(1, math.max(img.width, img.height) ~/ 360);
    final dw = img.width ~/ step;
    final dh = img.height ~/ step;
    final mask = _blueMask(img, dw, dh, step);
    final solid = _closeOpen(mask, dw, dh, 4);

    final minArea = dw * dh * 0.004;
    var bestScore = 0.0;
    List<Offset>? best;
    for (final comp in _components(solid, dw, dh)) {
      if (comp.area < minArea) continue;
      final corners = minAreaRectCorners([
        for (final i in comp.pixels) Offset(i % dw + 0.0, i ~/ dw + 0.0),
      ]);
      if (corners.isEmpty) continue;
      final w = _dist(corners[0], corners[1]);
      final h = _dist(corners[1], corners[2]);
      if (w < 1 || h < 1) continue;
      if (math.min(w, h) / math.max(w, h) < 0.25) continue; // 长条背景剔除
      final fill = comp.area / (w * h);
      if (fill < 0.55) continue;
      final score = comp.area * fill;
      if (score > bestScore) {
        bestScore = score;
        best = corners;
      }
    }
    if (best == null) return null;
    // 图像坐标锚定（y 轴向下）：左上 = x+y 最小，右上 = y-x 最小，
    // 保证 0→1 为顶边、3→0 为左边，矫正结果不会上下颠倒。
    var tl = best[0], tr = best[0], br = best[0], bl = best[0];
    for (final p in best) {
      if (p.dx + p.dy < tl.dx + tl.dy) tl = p;
      if (p.dx + p.dy > br.dx + br.dy) br = p;
      if (p.dy - p.dx < tr.dy - tr.dx) tr = p;
      if (p.dy - p.dx > bl.dy - bl.dx) bl = p;
    }
    return [tl, tr, br, bl].map((p) => Offset(p.dx * step, p.dy * step)).toList();
  }

  List<Offset> _rotated(List<Offset> corners) =>
      [corners[1], corners[2], corners[3], corners[0]];

  /// 蓝/青背光掩码（对齐 OpenCV 色相 90~120、饱和度≥70、明度≥60）。
  Uint8List _blueMask(SegImage img, int dw, int dh, int step) {
    final out = Uint8List(dw * dh);
    for (var y = 0; y < dh; y++) {
      final int srcY = math.min(img.height - 1, y * step);
      for (var x = 0; x < dw; x++) {
        final int sx = math.min(img.width - 1, x * step);
        final si = (srcY * img.width + sx) * 4;
        final r = img.rgba[si], g = img.rgba[si + 1], b = img.rgba[si + 2];
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        if (maxC < 60) continue;
        final s = (maxC - minC) * 255 ~/ maxC;
        if (s < 70) continue;
        var hue = 0.0;
        if (maxC == r) {
          hue = 60 * (g - b) / (maxC - minC);
        } else if (maxC == g) {
          hue = 120 + 60 * (b - r) / (maxC - minC);
        } else {
          hue = 240 + 60 * (r - g) / (maxC - minC);
        }
        if (hue < 0) hue += 360;
        final half = hue / 2; // 对齐 OpenCV 0~180 刻度
        if (half >= 90 && half <= 120) out[y * dw + x] = 1;
      }
    }
    return out;
  }

  // ---------------- 2) 矫正为灰度图 ----------------

  /// 旋转矩形（左上→右上→右下→左下）→ 正置灰度图，长边 ≤ [_lcdMaxSide]。
  (int, int, Uint8List) _rectifyToGray(SegImage img, List<Offset> quad) {
    final sw = math.max(8, _dist(quad[0], quad[1]).round());
    final sh = math.max(8, _dist(quad[1], quad[2]).round());
    final scale = math.min(1.0, _lcdMaxSide / math.max(sw, sh));
    final w = math.max(8, (sw * scale).round());
    final h = math.max(8, (sh * scale).round());

    final c0 = quad[0], c1 = quad[1], c3 = quad[3];
    final uw = (c1.dx - c0.dx) / w;
    final uh = (c1.dy - c0.dy) / w;
    final vw = (c3.dx - c0.dx) / h;
    final vh = (c3.dy - c0.dy) / h;

    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        out[y * w + x] =
            _sampleGray(img, c0.dx + uw * x + vw * y, c0.dy + uh * x + vh * y)
                .round();
      }
    }
    return (w, h, out);
  }

  double _dist(Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _sampleGray(SegImage img, double sx, double sy) {
    final xi = sx.floor(), yi = sy.floor();
    if (xi < 0 || yi < 0 || xi >= img.width - 1 || yi >= img.height - 1) {
      return 0;
    }
    final fx = sx - xi, fy = sy - yi;
    final i00 = (yi * img.width + xi) * 4;
    final row = img.width * 4;
    double lum(int i) =>
        0.299 * img.rgba[i] + 0.587 * img.rgba[i + 1] + 0.114 * img.rgba[i + 2];
    return lum(i00) * (1 - fx) * (1 - fy) +
        lum(i00 + 4) * fx * (1 - fy) +
        lum(i00 + row) * (1 - fx) * fy +
        lum(i00 + row + 4) * fx * fy;
  }

  // ---------------- 3) 二值化 ----------------

  /// 照度归一化（盒模糊背景比值 < 0.72 为前景）+ 3×3 开运算。
  ///
  /// 先对小半径盒模糊抑制屏幕翻拍摩尔纹（高频），笔画宽度远大于纹路周期。
  Uint8List _binarize(Uint8List gray0, int w, int h) {
    final gray = _boxGray(gray0, w, h, 2);
    final ksize = math.max(15, math.min(w, h) ~/ 12) | 1;
    final bg = _boxMean(gray, w, h, ksize ~/ 2);
    final bin = Uint8List(w * h);
    for (var i = 0; i < bin.length; i++) {
      if ((gray[i] + 1) / (bg[i] + 1) < 0.72) bin[i] = 1;
    }
    return _open3(bin, w, h);
  }

  /// 盒模糊（边界复制，积分图实现）。
  Uint8List _boxGray(Uint8List gray, int w, int h, int r) {
    final mean = _boxMean(gray, w, h, r);
    final out = Uint8List(w * h);
    for (var i = 0; i < out.length; i++) {
      out[i] = mean[i].round();
    }
    return out;
  }

  /// 盒均值（边界复制，积分图实现）。
  Float64List _boxMean(Uint8List gray, int w, int h, int r) {
    final integral = Int64List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0;
      for (var x = 0; x < w; x++) {
        rowSum += gray[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] =
            integral[y * (w + 1) + x + 1] + rowSum;
      }
    }
    final out = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
        final sum = integral[(y1 + 1) * (w + 1) + x1 + 1] -
            integral[y0 * (w + 1) + x1 + 1] -
            integral[(y1 + 1) * (w + 1) + x0] +
            integral[y0 * (w + 1) + x0];
        out[y * w + x] = sum / ((y1 - y0 + 1) * (x1 - x0 + 1));
      }
    }
    return out;
  }

  /// 闭 + 开运算（半径 r 的可分离最大/最小值滤波），
  /// 用于填合背光掩码中的数字孔洞并去除噪点。
  Uint8List _closeOpen(Uint8List m, int w, int h, int r) {
    final closed = _minFilter(_maxFilter(m, w, h, r), w, h, r);
    return _maxFilter(_minFilter(closed, w, h, r), w, h, r);
  }

  Uint8List _maxFilter(Uint8List m, int w, int h, int r) {
    final t = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 0;
        for (var dx = -r; dx <= r && v == 0; dx++) {
          if (m[y * w + (x + dx).clamp(0, w - 1)] == 1) v = 1;
        }
        t[y * w + x] = v;
      }
    }
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 0;
        for (var dy = -r; dy <= r && v == 0; dy++) {
          if (t[(y + dy).clamp(0, h - 1) * w + x] == 1) v = 1;
        }
        out[y * w + x] = v;
      }
    }
    return out;
  }

  Uint8List _minFilter(Uint8List m, int w, int h, int r) {
    final t = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 1;
        for (var dx = -r; dx <= r && v == 1; dx++) {
          if (m[y * w + (x + dx).clamp(0, w - 1)] == 0) v = 0;
        }
        t[y * w + x] = v;
      }
    }
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 1;
        for (var dy = -r; dy <= r && v == 1; dy++) {
          if (t[(y + dy).clamp(0, h - 1) * w + x] == 0) v = 0;
        }
        out[y * w + x] = v;
      }
    }
    return out;
  }

  Uint8List _open3(Uint8List m, int w, int h) =>
      _dilate3(_erode3(m, w, h), w, h);

  Uint8List _erode3(Uint8List m, int w, int h) {
    final t = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 1;
        for (var dx = -1; dx <= 1 && v == 1; dx++) {
          if (m[y * w + (x + dx).clamp(0, w - 1)] == 0) v = 0;
        }
        t[y * w + x] = v;
      }
    }
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 1;
        for (var dy = -1; dy <= 1 && v == 1; dy++) {
          if (t[(y + dy).clamp(0, h - 1) * w + x] == 0) v = 0;
        }
        out[y * w + x] = v;
      }
    }
    return out;
  }

  Uint8List _dilate3(Uint8List m, int w, int h) {
    final t = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 0;
        for (var dx = -1; dx <= 1 && v == 0; dx++) {
          if (m[y * w + (x + dx).clamp(0, w - 1)] == 1) v = 1;
        }
        t[y * w + x] = v;
      }
    }
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 0;
        for (var dy = -1; dy <= 1 && v == 0; dy++) {
          if (t[(y + dy).clamp(0, h - 1) * w + x] == 1) v = 1;
        }
        out[y * w + x] = v;
      }
    }
    return out;
  }

  // ---------------- 4) 连通域 ----------------

  /// 8 连通域（BFS）。
  List<_Component> _components(Uint8List mask, int w, int h) {
    final visited = Uint8List(w * h);
    final queue = <int>[];
    final out = <_Component>[];
    for (var start = 0; start < mask.length; start++) {
      if (mask[start] == 0 || visited[start] == 1) continue;
      visited[start] = 1;
      queue.add(start);
      final comp = _Component();
      while (queue.isNotEmpty) {
        final idx = queue.removeLast();
        comp.pixels.add(idx);
        final x = idx % w, y = idx ~/ w;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            final ni = ny * w + nx;
            if (mask[ni] == 1 && visited[ni] == 0) {
              visited[ni] = 1;
              queue.add(ni);
            }
          }
        }
      }
      out.add(comp);
    }
    return out;
  }

  /// 过滤噪声连通域（过小、过大、过宽、过扁高的都是边框或斑点），
  /// 返回仅保留可信分量的掩码。
  Uint8List _filterComponents(Uint8List bin, int w, int h) {
    final minArea = math.max(24, w * h * 0.0003).round();
    final clean = Uint8List(w * h);
    for (final comp in _components(bin, w, h)) {
      var x0 = w, x1 = 0, y0 = h, y1 = 0;
      for (final i in comp.pixels) {
        final x = i % w, y = i ~/ w;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
      final bw = x1 - x0 + 1, bh = y1 - y0 + 1;
      if (comp.area < minArea) continue;
      if (bh > h * 0.62 || bw > w * 0.62) continue;
      // 触边分量 = LCD 边框 / 机身 / 按钮碎片（数字永远有边距）
      if (x1 < w * 0.03 || x0 > w * 0.97 || y1 < h * 0.03 || y0 > h * 0.97) {
        continue;
      }
      for (final i in comp.pixels) {
        clean[i] = 1;
      }
    }
    return clean;
  }

  // ---------------- 5) 数字提取与分类 ----------------

  /// profile > 0 的连续段（end 独占）。
  List<(int, int)> _runs(Int32List profile) {
    final out = <(int, int)>[];
    var s = -1;
    for (var i = 0; i < profile.length; i++) {
      if (profile[i] > 0) {
        if (s < 0) s = i;
      } else if (s >= 0) {
        out.add((s, i));
        s = -1;
      }
    }
    if (s >= 0) out.add((s, profile.length));
    return out;
  }

  List<LcdNumberGroup> _extractNumbers(Uint8List clean, int w, int h) {
    final rowSum = Int32List(h);
    for (var y = 0; y < h; y++) {
      var sum = 0;
      final row = y * w;
      for (var x = 0; x < w; x++) {
        sum += clean[row + x];
      }
      rowSum[y] = sum;
    }
    // 行带：投影 > 0.5% 宽，合并 < 2% 高的缝，丢弃过矮的带（图标/单位文字；
    // 旁侧按钮等贴边内容已在连通域过滤阶段剔除）
    final bandRuns = <(int, int)>[];
    for (final r in _runs(Int32List.fromList(
        [for (final v in rowSum) v > w * 0.005 ? 1 : 0]))) {
      if (bandRuns.isNotEmpty && r.$1 - bandRuns.last.$2 < h * 0.02) {
        bandRuns[bandRuns.length - 1] =
            (bandRuns.last.$1, r.$2);
      } else {
        bandRuns.add(r);
      }
    }

    final numbers = <LcdNumberGroup>[];
    for (final (y0, y1) in bandRuns) {
      final bandH = y1 - y0;
      if (bandH < h * 0.09) continue;
      final band = _extractBand(clean, w, h, y0, y1);
      if (band.digits.isEmpty) continue;
      _classifyBand(band);
      _log('band y=$y0 h=$bandH digits='
          '${band.digits.map((d) => '${d.digit}@x${d.x}(${d.w}x${d.h})').join(' ')}');
      for (final g in _groupDigits(band)) {
        numbers.add(g);
      }
    }
    return numbers;
  }

  _Band _extractBand(Uint8List clean, int w, int h, int y0, int y1) {
    final band = _Band()..y0 = y0..y1 = y1;
    final colSum = Int32List(w);
    for (var y = y0; y < y1; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        colSum[x] += clean[row + x];
      }
    }
    // 列簇阈值 8% 行高：数字笔画列（≥12% 行高）保留，杂散噪点列
    // （1~2px）不再把相邻数字桥接成一个簇
    final colThr = math.max(1, ((y1 - y0) * 0.05).round());
    final clusters = <(int, int)>[];
    var s = -1;
    for (var x = 0; x < w; x++) {
      if (colSum[x] >= colThr) {
        if (s < 0) s = x;
      } else if (s >= 0) {
        clusters.add((s, x));
        s = -1;
      }
    }
    if (s >= 0) clusters.add((s, w));
    _log('  band y=$y0-$y1 colThr=$colThr clusters=$clusters '
        'colSumMax=${colSum.reduce(math.max)}');
    for (final (x0, x1) in clusters) {
      if (x1 - x0 < w * 0.02) continue;
      if (x0 < w * 0.03 || x1 > w * 0.97) continue; // LCD 边框/边缘阴影
      // 列簇 → 行子块（回接上下分离笔画，如 "1" 的上下两段）
      final blocks = <(int, int)>[];
      for (final b in _runs(_rowProfile(clean, w, x0, x1, y0, y1))) {
        if (blocks.isNotEmpty) {
          final prev = blocks.last;
          final gap = b.$1 - prev.$2;
          final prevH = prev.$2 - prev.$1;
          final curH = b.$2 - b.$1;
          if (gap < 0.35 * math.min(prevH, curH)) {
            blocks[blocks.length - 1] = (prev.$1, b.$2);
            continue;
          }
        }
        blocks.add(b);
      }
      for (final (by0, by1) in blocks) {
        final mask = _tightMask(clean, w, x0, x1, y0 + by0, y0 + by1);
        if (mask == null) continue;
        band.digits.add(_Digit(
          x: mask.$3,
          y: y0 + by0 + mask.$4,
          w: mask.$1,
          h: mask.$2,
          mask: mask.$5,
        ));
      }
    }
    // 行内小噪声（相对最高字形）
    if (band.digits.isNotEmpty) {
      final hmax = band.digits.map((d) => d.h).reduce(math.max);
      band.digits.removeWhere((d) => d.h < 0.45 * hmax);
    }
    return band;
  }

  Int32List _rowProfile(
      Uint8List clean, int w, int x0, int x1, int y0, int y1) {
    final prof = Int32List(y1 - y0);
    for (var y = y0; y < y1; y++) {
      var sum = 0;
      final row = y * w;
      for (var x = x0; x < x1; x++) {
        sum += clean[row + x];
      }
      prof[y - y0] = sum;
    }
    return prof;
  }

  /// 区域紧致掩码，返回 (w, h, xOff, yOff, mask)。
  (int, int, int, int, Uint8List)? _tightMask(
      Uint8List clean, int w, int x0, int x1, int y0, int y1) {
    var minX = 1 << 30, maxX = -1, minY = 1 << 30, maxY = -1;
    for (var y = y0; y < y1; y++) {
      final row = y * w;
      for (var x = x0; x < x1; x++) {
        if (clean[row + x] == 1) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < minX || maxY < minY) return null;
    final bw = maxX - minX + 1, bh = maxY - minY + 1;
    final mask = Uint8List(bw * bh);
    for (var y = 0; y < bh; y++) {
      for (var x = 0; x < bw; x++) {
        mask[y * bw + x] = clean[(minY + y) * w + minX + x];
      }
    }
    return (bw, bh, minX, minY, mask);
  }

  void _classifyBand(_Band band) {
    for (final d in band.digits) {
      if (d.w < d.h * _oneAspect) {
        d.digit = 1; // 七段 "1" 是唯一细长字形
      } else if (d.w > d.h * _maxDigitAspect) {
        d.digit = null; // 多字粘连（如"80"连体）宁可拒读
      } else {
        d.digit = _classifyGlyph(d.mask, d.w, d.h);
      }
    }
    band.digits.removeWhere((d) => d.digit == null);
  }

  /// 七段分类：网格上行/列填充峰值检测各段，段差 > 1 视为非数字。
  int? _classifyGlyph(Uint8List mask, int w, int h) {
    final g = _areaResize(mask, w, h, _gridW, _gridH);
    final on = <String>{
      if (_maxRowFill(g, 8, 24, 2, 12) >= _barOnFill) 'a',
      if (_maxColFill(g, 26, 31, 4, 26) >= _wallOnFill) 'b',
      if (_maxColFill(g, 26, 31, 30, 52) >= _wallOnFill) 'c',
      if (_maxRowFill(g, 8, 24, 44, 54) >= _barOnFill) 'd',
      if (_maxColFill(g, 0, 7, 30, 52) >= _wallOnFill) 'e',
      if (_maxColFill(g, 0, 7, 4, 26) >= _wallOnFill) 'f',
      if (_maxRowFill(g, 9, 23, 24, 32) >= _wallOnFill) 'g',
    };
    int? best;
    var bestDiff = 9;
    _segMap.forEach((digit, pattern) {
      var diff = 0;
      for (final seg in _zonesKeys) {
        if (on.contains(seg) != pattern.contains(seg)) diff++;
      }
      if (diff < bestDiff) {
        bestDiff = diff;
        best = digit;
      }
    });
    _log('  glyph ${w}x$h on="${on.join()}" -> $best ($bestDiff)');
    return bestDiff <= 1 ? best : null;
  }

  /// [y0..y1] 行内 x∈[x0..x1] 的最大行填充率。
  double _maxRowFill(Uint8List g, int x0, int x1, int y0, int y1) {
    var best = 0.0;
    final span = x1 - x0 + 1;
    for (var y = y0; y <= y1; y++) {
      var sum = 0;
      for (var x = x0; x <= x1; x++) {
        sum += g[y * _gridW + x];
      }
      final fill = sum / span;
      if (fill > best) best = fill;
    }
    return best;
  }

  /// [x0..x1] 列内 y∈[y0..y1] 的最大列填充率。
  double _maxColFill(Uint8List g, int x0, int x1, int y0, int y1) {
    var best = 0.0;
    final span = y1 - y0 + 1;
    for (var x = x0; x <= x1; x++) {
      var sum = 0;
      for (var y = y0; y <= y1; y++) {
        sum += g[y * _gridW + x];
      }
      final fill = sum / span;
      if (fill > best) best = fill;
    }
    return best;
  }

  /// 0/1 掩码面积均值重采样（相当于 INTER_AREA，双向通吃）。
  Uint8List _areaResize(Uint8List mask, int w, int h, int tw, int th) {
    final integral = Int32List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0;
      for (var x = 0; x < w; x++) {
        rowSum += mask[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] =
            integral[y * (w + 1) + x + 1] + rowSum;
      }
    }
    final out = Uint8List(tw * th);
    for (var ty = 0; ty < th; ty++) {
      final sy0 = (ty * h / th).floor();
      final sy1 = math.max(1, ((ty + 1) * h / th).ceil());
      for (var tx = 0; tx < tw; tx++) {
        final sx0 = (tx * w / tw).floor();
        final sx1 = math.max(1, ((tx + 1) * w / tw).ceil());
        final sum = integral[sy1 * (w + 1) + sx1] -
            integral[sy0 * (w + 1) + sx1] -
            integral[sy1 * (w + 1) + sx0] +
            integral[sy0 * (w + 1) + sx0];
        out[ty * tw + tx] = sum / ((sy1 - sy0) * (sx1 - sx0)) > 0.39 ? 1 : 0;
      }
    }
    return out;
  }

  /// 同行数字按间距分组为数值（间距 < 0.55×数字高）。
  Iterable<LcdNumberGroup> _groupDigits(_Band band) sync* {
    band.digits.sort((a, b) => a.x.compareTo(b.x));
    var value = 0, count = 0, x2 = 0;
    for (final d in band.digits) {
      if (count > 0 && d.x - x2 >= _groupGapRatio * d.h) {
        yield LcdNumberGroup(value: value, bandY: band.y0, digitCount: count);
        value = 0;
        count = 0;
      }
      value = value * 10 + d.digit!;
      count++;
      x2 = d.x + d.w;
    }
    if (count > 0) {
      yield LcdNumberGroup(value: value, bandY: band.y0, digitCount: count);
    }
  }
}
