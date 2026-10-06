/// PP-OCR 纯逻辑模块测试：DBNet 后处理、CTC 解码、位置感知解析。
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/camera_ocr/data/ppocr/det_postprocess.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/position_parser.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/rec_decode.dart';

Float32List _prob(int w, int h, List<Rect> hot, {double v = 0.9}) {
  final p = Float32List(w * h);
  for (final r in hot) {
    for (var y = r.top.round(); y < r.bottom.round(); y++) {
      for (var x = r.left.round(); x < r.right.round(); x++) {
        p[y * w + x] = v;
      }
    }
  }
  return p;
}

void main() {
  group('DBNet 检测后处理', () {
    test('单个高亮区域 → 一个框，位置接近原区域', () {
      final boxes = boxesFromProbMap(
        prob: _prob(96, 32, [const Rect.fromLTWH(20, 8, 40, 12)]),
        width: 96,
        height: 32,
      );
      expect(boxes, hasLength(1));
      expect(boxes.first.left, lessThanOrEqualTo(20));
      expect(boxes.first.right, greaterThanOrEqualTo(60));
      expect(boxes.first.score, greaterThan(0.8));
    });

    test('两个分离区域 → 两个框，按行排序', () {
      final boxes = boxesFromProbMap(
        prob: _prob(96, 48, [
          const Rect.fromLTWH(10, 30, 30, 10),
          const Rect.fromLTWH(50, 4, 30, 10),
        ]),
        width: 96,
        height: 48,
      );
      expect(boxes, hasLength(2));
      expect(boxes.first.top, lessThan(boxes.last.top));
    });

    test('微小噪点被过滤', () {
      final boxes = boxesFromProbMap(
        prob: _prob(64, 32, [
          const Rect.fromLTWH(30, 15, 3, 2), // 6 像素 < minArea
          const Rect.fromLTWH(10, 5, 30, 10),
        ]),
        width: 64,
        height: 32,
      );
      expect(boxes, hasLength(1));
    });

    test('低分区域（boxThresh 以下）被过滤', () {
      final boxes = boxesFromProbMap(
        prob: _prob(64, 32, [const Rect.fromLTWH(10, 5, 30, 10)],
            v: 0.35),
        width: 64,
        height: 32,
      );
      expect(boxes, isEmpty);
    });
  });

  group('CTC 解码', () {
    const dict = ['1', '2', '0', '8', '压'];
    // 字典表：0=blank，1..5=dict，6=空格
    test('去重连续 + 跳过 blank', () {
      // 1('1'),2('2'),2(dup),blank,3('0'),blank,blank → "120"
      expect(decodeCtc([1, 2, 2, 0, 3, 0, 0], dict), '120');
    });
    test('非连续相同字符保留', () {
      expect(decodeCtc([1, 0, 1], dict), '11');
    });
    test('空格位（n+1）输出空格', () {
      expect(decodeCtc([1, 6, 2], dict), '1 2');
    });
    test('全 blank → 空串', () {
      expect(decodeCtc([0, 0, 0], dict), '');
    });
  });

  group('位置感知解析', () {
    PpTextLine line(String text, double left, double top, double w,
            {double h = 40}) =>
        PpTextLine(text: text, rect: Rect.fromLTWH(left, top, w, h));

    test('标签+右侧数值配对（三诺实拍布局）', () {
      final result = parsePositionedLines([
        line('高压', 1183, 438, 160),
        line('120', 1545, 365, 560),
        line('低压', 1176, 578, 156),
        line('80', 1545, 766, 560),
        line('脉搏', 1159, 1150, 150),
        line('75 03', 1545, 1290, 300),
      ]);
      expect(result.best, isNotNull);
      expect(result.best!.systolic, 120);
      expect(result.best!.diastolic, 80);
      expect(result.best!.pulse, 75);
      expect(result.best!.pattern, 'position-label');
    });

    test('无标签时退回传统文本解析（分数式）', () {
      final result = parsePositionedLines([
        line('125/82', 100, 100, 200),
      ]);
      expect(result.best, isNotNull);
      expect(result.best!.systolic, 125);
      expect(result.best!.diastolic, 82);
    });

    test('标签与数值距离过远不误配（刻度标签场景）', () {
      // 刻度标签 135/85 恰好也是数字框：不应被当作读数（无高压/低压标签邻近时退回文本兜底）
      final result = parsePositionedLines([
        line('135', 1800, 300, 100),
        line('85', 1800, 700, 100),
      ]);
      // 无标签可配对；兜底解析会把 135/85 当分数式 → 应被 plausible 拦截
      // （135>85 且都在区间内 → 会给出候选，但置信度低）
      if (result.best != null) {
        expect(result.best!.confidence, lessThan(0.6));
      }
    });
  });
}
