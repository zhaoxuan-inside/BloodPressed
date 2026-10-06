/// 旋转四边形 → 正置文本条的仿射裁剪（纯 Dart，双线性采样）。
///
/// 源四边形是旋转矩形（平行四边形特例），因此逆映射为仿射：
/// src = c0 + u*(c1-c0) + v*(c3-c0)，无需完整单应性。
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'ppocr_service.dart' show RgbaImage;

/// 从源图裁剪旋转四边形区域，输出 W×H 的正置 RGBA 图。
///
/// [corners] 按周向顺序（0=左上 1=右上 2=右下 3=左下），
/// [width]/[height] 为目标尺寸（建议取四边形实际长/短边长）。
RgbaImage cropQuad(
  RgbaImage src,
  List<Offset> corners,
  int width,
  int height,
) {
  final c0 = corners[0];
  final c1 = corners[1];
  final c3 = corners[3];
  final uw = (c1.dx - c0.dx) / width;
  final uh = (c1.dy - c0.dy) / width;
  final vw = (c3.dx - c0.dx) / height;
  final vh = (c3.dy - c0.dy) / height;

  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final sx = c0.dx + uw * x + vw * y;
      final sy = c0.dy + uh * x + vh * y;
      final di = (y * width + x) * 4;

      final xi = sx.floor();
      final yi = sy.floor();
      final fx = sx - xi;
      final fy = sy - yi;

      if (xi < 0 || yi < 0 || xi >= src.width - 1 || yi >= src.height - 1) {
        continue;
      }
      final i00 = (yi * src.width + xi) * 4;
      final i10 = i00 + 4;
      final i01 = i00 + src.width * 4;
      final i11 = i01 + 4;

      for (var c = 0; c < 3; c++) {
        final v00 = src.rgba[i00 + c].toDouble();
        final v10 = src.rgba[i10 + c].toDouble();
        final v01 = src.rgba[i01 + c].toDouble();
        final v11 = src.rgba[i11 + c].toDouble();
        out[di + c] =
            (v00 * (1 - fx) * (1 - fy) +
                    v10 * fx * (1 - fy) +
                    v01 * (1 - fx) * fy +
                    v11 * fx * fy)
                .round();
      }
      out[di + 3] = 255;
    }
  }
  return RgbaImage(out, width, height);
}

/// 从旋转四边形推算目标裁剪尺寸（宽=长边，高=短边）。
(int, int) quadSize(List<Offset> corners) {
  double dist(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  var w = dist(corners[0], corners[1]).round();
  var h = dist(corners[1], corners[2]).round();
  if (w < h) {
    final t = w;
    w = h;
    h = t;
  }
  w = w < 8 ? 8 : w;
  h = h < 8 ? 8 : h;
  return (w, h);
}
