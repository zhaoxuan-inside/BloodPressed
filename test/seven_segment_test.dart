/// 七段码 LCD 读取与解析测试：合成血压计屏照片（含布局/旋转/灰屏变体）。
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/camera_ocr/data/ppocr/seven_segment.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/position_parser.dart';

/// RGBA 画布
class _Canvas {
  _Canvas(this.width, this.height)
      : pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List pixels;

  void fillRect(int x0, int y0, int w, int h, List<int> rgb) {
    for (var y = y0; y < y0 + h; y++) {
      for (var x = x0; x < x0 + w; x++) {
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        final i = (y * width + x) * 4;
        pixels[i] = rgb[0];
        pixels[i + 1] = rgb[1];
        pixels[i + 2] = rgb[2];
        pixels[i + 3] = 255;
      }
    }
  }
}

const _lcdBg = [60, 150, 210]; // 蓝色背光（色相 ~102）
const _digit = [20, 40, 90]; // 深色数字
const _body = [210, 210, 210]; // 机身

/// 七段字形段矩形（宽 gw 高 gh，笔画 t，段缝 gap），键同分类器 a~g。
/// 下半竖段从 half+gap 起（贴近真实 LCD：中缝约为半个笔画宽）。
Map<String, List<int>> _segRects(int gw, int gh, int t, int gap) {
  final half = gh ~/ 2;
  return {
    'a': [t, 0, gw - 2 * t, t],
    'b': [gw - t, gap, t, half - t ~/ 2 - gap - gap],
    'c': [gw - t, half + gap, t, gh - t - gap - (half + gap)],
    'd': [t, gh - t, gw - 2 * t, t],
    'e': [0, half + gap, t, gh - t - gap - (half + gap)],
    'f': [0, gap, t, half - t ~/ 2 - gap - gap],
    'g': [t, half - t ~/ 2, gw - 2 * t, t],
  };
}

const _digitSegs = <int, List<String>>{
  0: ['a', 'b', 'c', 'd', 'e', 'f'],
  1: ['b', 'c'],
  2: ['a', 'b', 'g', 'e', 'd'],
  3: ['a', 'b', 'g', 'c', 'd'],
  4: ['f', 'g', 'b', 'c'],
  5: ['a', 'f', 'g', 'c', 'd'],
  6: ['a', 'f', 'g', 'e', 'c', 'd'],
  7: ['a', 'b', 'c'],
  8: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
  9: ['a', 'b', 'c', 'd', 'f', 'g'],
};

void _drawGlyph(
    _Canvas c, int x0, int y0, int gw, int gh, int t, int gap, int digit) {
  final segs = _segRects(gw, gh, t, gap);
  for (final s in _digitSegs[digit]!) {
    final r = segs[s]!;
    c.fillRect(x0 + r[0], y0 + r[1], r[2], r[3], _digit);
  }
}

/// 在 LCD 上画一行数字（value 逐位绘制；gapX = 位间距）。
void _drawNumber(_Canvas c, int value, int digits, int x0, int y0,
    {required int gw, required int gh, required int t, required int gap, required int gapX}) {
  final text = value.toString().padLeft(digits, '0');
  for (var i = 0; i < text.length; i++) {
    _drawGlyph(c, x0 + i * (gw + gapX), y0, gw, gh, t, gap, int.parse(text[i]));
  }
}

/// 竖版三诺式布局：120 / 80 / 75 03（行堆叠，行方向沿短边）。
SegImage _portraitLcd() {
  final c = _Canvas(500, 740)
    ..fillRect(0, 0, 500, 740, _body)
    ..fillRect(60, 60, 400, 620, _lcdBg);
  const gw = 40, gh = 76, t = 9, gap = 1;
  _drawNumber(c, 120, 3, 100, 90,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  _drawNumber(c, 80, 2, 140, 250,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  _drawNumber(c, 75, 2, 100, 410,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  _drawNumber(c, 3, 1, 252, 410,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  return SegImage(c.pixels, c.width, c.height);
}

/// 横版欧姆龙式布局：205 / 88（行方向沿长边）。
SegImage _landscapeLcd() {
  final c = _Canvas(740, 540)
    ..fillRect(0, 0, 740, 540, _body)
    ..fillRect(50, 60, 640, 420, _lcdBg);
  const gw = 33, gh = 60, t = 7, gap = 0;
  _drawNumber(c, 205, 3, 250, 90,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  _drawNumber(c, 88, 2, 270, 260,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  return SegImage(c.pixels, c.width, c.height);
}

/// 灰屏（非彩色背光）：通用场景，七段码路径应放弃。
SegImage _grayLcd() {
  final c = _Canvas(500, 740)
    ..fillRect(0, 0, 500, 740, _body)
    ..fillRect(60, 60, 400, 620, [150, 150, 150]);
  const gw = 40, gh = 76, t = 9, gap = 1;
  _drawNumber(c, 120, 3, 100, 90,
      gw: gw, gh: gh, t: t, gap: gap, gapX: 12);
  return SegImage(c.pixels, c.width, c.height);
}

/// 双线性旋转（绕中心），模拟手持拍摄倾斜。
SegImage _rotate(SegImage img, double rad) {
  final out = Uint8List(img.width * img.height * 4);
  final cos = math.cos(rad), sin = math.sin(rad);
  final cx = img.width / 2, cy = img.height / 2;
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      final dx = x - cx, dy = y - cy;
      final sx = cos * dx + sin * dy + cx;
      final sy = -sin * dx + cos * dy + cy;
      final xi = sx.floor(), yi = sy.floor();
      final di = (y * img.width + x) * 4;
      if (xi < 0 || yi < 0 || xi >= img.width - 1 || yi >= img.height - 1) {
        out[di + 3] = 255;
        continue;
      }
      final fx = sx - xi, fy = sy - yi;
      for (var ch = 0; ch < 3; ch++) {
        double p(int xx, int yy) =>
            img.rgba[(yy * img.width + xx) * 4 + ch].toDouble();
        final i00 = (yi * img.width + xi) * 4 + ch;
        final v = p(xi, yi) * (1 - fx) * (1 - fy) +
            img.rgba[i00 + 4] * fx * (1 - fy) +
            img.rgba[i00 + img.width * 4] * (1 - fx) * fy +
            img.rgba[i00 + img.width * 4 + 4] * fx * fy;
        out[di + ch] = v.round();
      }
      out[di + 3] = 255;
    }
  }
  return SegImage(out, img.width, img.height);
}

void main() {
  setUpAll(() {
    SevenSegmentReader.logger = (m) => debugPrint('[SevenSeg] $m');
  });
  tearDownAll(() {
    SevenSegmentReader.logger = null;
  });

  test('竖版彩色背光屏：读出 120 / 80 / 75', () {
    final readout = SevenSegmentReader().read(_portraitLcd());
    expect(readout, isNotNull);
    final values = readout!.numbers.map((n) => n.value).toList();
    expect(values, [120, 80, 75, 3]);
  });

  test('竖版屏倾斜 5° 仍可读出', () {
    final readout = SevenSegmentReader().read(_rotate(_portraitLcd(), 5 * math.pi / 180));
    expect(readout, isNotNull);
    expect(readout!.numbers.map((n) => n.value).toList(), [120, 80, 75, 3]);
  });

  test('横版彩色背光屏：读出 205 / 88', () {
    final readout = SevenSegmentReader().read(_landscapeLcd());
    expect(readout, isNotNull);
    expect(readout!.numbers.map((n) => n.value).toList(), [205, 88]);
  });

  test('灰屏（非彩色背光）返回 null', () {
    expect(SevenSegmentReader().read(_grayLcd()), isNull);
  });

  test('parseLcdReadout：行序映射收缩压/舒张压/脉搏', () {
    final result = parseLcdReadout(const LcdReadout([
      LcdNumberGroup(value: 120, bandY: 0, digitCount: 3),
      LcdNumberGroup(value: 80, bandY: 200, digitCount: 2),
      LcdNumberGroup(value: 75, bandY: 400, digitCount: 2),
      LcdNumberGroup(value: 3, bandY: 400, digitCount: 2),
    ]));
    expect(result, isNotNull);
    expect(result!.best!.systolic, 120);
    expect(result.best!.diastolic, 80);
    expect(result.best!.pulse, 75);
    expect(result.isReliable, isTrue);
  });

  test('parseLcdReadout：无脉搏行时脉搏为空', () {
    final result = parseLcdReadout(const LcdReadout([
      LcdNumberGroup(value: 135, bandY: 0, digitCount: 3),
      LcdNumberGroup(value: 88, bandY: 200, digitCount: 2),
    ]));
    expect(result, isNotNull);
    expect(result!.best!.systolic, 135);
    expect(result.best!.diastolic, 88);
    expect(result.best!.pulse, isNull);
  });

  test('parseLcdReadout：数值不合理时返回 null', () {
    expect(
      parseLcdReadout(const LcdReadout([
        LcdNumberGroup(value: 5, bandY: 0, digitCount: 1),
        LcdNumberGroup(value: 3, bandY: 100, digitCount: 1),
      ])),
      isNull,
    );
  });

  test('parseLcdReadout：舒张压必须小于收缩压', () {
    expect(
      parseLcdReadout(const LcdReadout([
        LcdNumberGroup(value: 80, bandY: 0, digitCount: 2),
        LcdNumberGroup(value: 120, bandY: 100, digitCount: 3),
      ])),
      isNull,
    );
  });
}
