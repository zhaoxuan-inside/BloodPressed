/// PP-OCRv5 mobile ONNX 推理服务（det + rec，离线，无 GMS 依赖）。
///
/// 流程：原生解码图片（RGBA）→ 检测（DBNet 概率图 → 文本框）→ 逐框裁剪 →
/// 识别（CTC 解码）→ 带位置的文本行。模型随包内置（assets/models/ppocr）。
///
/// 像素访问直接操作 RGBA 字节（Flutter 原生解码器，
/// 避免 image 包纯 Dart 解码大 JPEG 的分钟级耗时）。
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'det_postprocess.dart';
import 'rec_decode.dart';

/// RGBA 像素图（行主序，每像素 4 字节）。
class RgbaImage {
  RgbaImage(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;

  /// 最近邻缩放（OCR 预处理足够）。
  RgbaImage resizeNearest(int newW, int newH) {
    final out = Uint8List(newW * newH * 4);
    final xr = width / newW;
    final yr = height / newH;
    for (var y = 0; y < newH; y++) {
      final sy = (y * yr).clamp(0, height - 1).toInt();
      for (var x = 0; x < newW; x++) {
        final sx = (x * xr).clamp(0, width - 1).toInt();
        final si = (sy * width + sx) * 4;
        final di = (y * newW + x) * 4;
        out[di] = rgba[si];
        out[di + 1] = rgba[si + 1];
        out[di + 2] = rgba[si + 2];
        out[di + 3] = rgba[si + 3];
      }
    }
    return RgbaImage(out, newW, newH);
  }

  /// 裁剪区域（自动钳制到边界）。
  RgbaImage crop(Rect rect) {
    final l = rect.left.clamp(0, width - 1).toInt();
    final t = rect.top.clamp(0, height - 1).toInt();
    final r = rect.right.clamp(1, width).toInt();
    final b = rect.bottom.clamp(1, height).toInt();
    final w = r - l;
    final h = b - t;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final src = ((t + y) * width + l) * 4;
      out.setRange(y * w * 4, (y + 1) * w * 4, rgba, src);
    }
    return RgbaImage(out, w, h);
  }
}

class PpOcrService {
  PpOcrService();

  static const double _detMeanR = 0.485, _detMeanG = 0.456, _detMeanB = 0.406;
  static const double _detStdR = 0.229, _detStdG = 0.224, _detStdB = 0.225;
  static const int _detLimitSide = 736;
  static const int _recHeight = 48;
  static const int _recMaxBoxes = 15;

  OrtSession? _detSession;
  OrtSession? _recSession;
  List<String>? _dict;

  bool get _ready =>
      _detSession != null && _recSession != null && _dict != null;

  Future<void> _ensureLoaded() async {
    if (_ready) return;
    OrtEnv.instance;
    final detBytes = (await rootBundle.load(
            'assets/models/ppocr/ch_PP-OCRv5_det_mobile.onnx'))
        .buffer
        .asUint8List();
    final recBytes = (await rootBundle.load(
            'assets/models/ppocr/ch_PP-OCRv5_rec_mobile.onnx'))
        .buffer
        .asUint8List();
    final dictRaw =
        await rootBundle.loadString('assets/models/ppocr/ppocrv5_dict.txt');
    _dict = dictRaw
        .split('\n')
        .map((l) => l.trimRight().replaceAll('\r', ''))
        .toList();
    _detSession = OrtSession.fromBuffer(detBytes, OrtSessionOptions());
    _recSession = OrtSession.fromBuffer(recBytes, OrtSessionOptions());
  }

  /// 识别图片，返回带位置的文本行（按阅读顺序）。
  Future<List<PpTextLine>> recognizeLines(String imagePath) async {
    await _ensureLoaded();
    final bytes = File(imagePath).readAsBytesSync();
    final codec = await instantiateImageCodec(bytes, targetWidth: 1600);
    final frame = await codec.getNextFrame();
    final rgba =
        (await frame.image.toByteData(format: ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();
    final image = RgbaImage(rgba, frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();

    // ---------- 检测 ----------
    final longest = math.max(image.width, image.height);
    var scale = _detLimitSide / longest;
    if (scale > 1) scale = 1;
    var detW = ((image.width * scale) / 32).floor() * 32;
    var detH = ((image.height * scale) / 32).floor() * 32;
    detW = detW < 32 ? 32 : detW;
    detH = detH < 32 ? 32 : detH;
    final detImage = image.resizeNearest(detW, detH);
    final detInput = _detTensor(detImage);
    final detRun = await _detSession!.runAsync(
      OrtRunOptions(),
      {
        'x': OrtValueTensor.createTensorWithDataList(
            detInput, [1, 3, detH, detW])
      },
    );
    final prob = _probMapFromOutput(detRun![0]!.value, detW, detH);

    final scaleX = image.width / detW;
    final scaleY = image.height / detH;
    final detBoxes = boxesFromProbMap(
      prob: prob,
      width: detW,
      height: detH,
    )
        .map((b) => DetBox(
              left: (b.left * scaleX).round(),
              top: (b.top * scaleY).round(),
              right: (b.right * scaleX).round(),
              bottom: (b.bottom * scaleY).round(),
              score: b.score,
            ))
        .toList()
      ..sort((a, b) => b.area.compareTo(a.area));
    // 大图/摩尔纹场景可能检出数十个框，逐框识别耗时过长；
    // 血压读数所在框面积显著更大，按面积取前 15 个
    final recTargets = detBoxes.take(_recMaxBoxes).toList()
      ..sort((a, b) {
        final byRow = (a.top + a.bottom).compareTo(b.top + b.bottom);
        return byRow != 0 ? byRow : a.left.compareTo(b.left);
      });

    // ---------- 识别 ----------
    final lines = <PpTextLine>[];
    for (final box in recTargets) {
      final cropped = image.crop(Rect.fromLTWH(
        box.left.toDouble(),
        box.top.toDouble(),
        box.width.toDouble(),
        box.height.toDouble(),
      ));
      final recW = _recInputWidth(cropped);
      final resized = cropped.resizeNearest(recW, _recHeight);
      final recInput = _recTensor(resized, recW);
      final recRun = await _recSession!.runAsync(
        OrtRunOptions(),
        {
          'x': OrtValueTensor.createTensorWithDataList(
              recInput, [1, 3, _recHeight, recW])
        },
      );
      final indices =
          _argmaxPerSteps(recRun![0]!.value, _dict!.length + 2);
      final text = decodeCtc(indices, _dict!).trim();
      if (text.isEmpty) continue;
      lines.add(PpTextLine(
        text: text,
        rect: Rect.fromLTWH(
          box.left.toDouble(),
          box.top.toDouble(),
          box.width.toDouble(),
          box.height.toDouble(),
        ),
        score: box.score,
      ));
    }
    return lines;
  }

  void dispose() {
    _detSession?.release();
    _recSession?.release();
    _detSession = null;
    _recSession = null;
  }

  // ---------------- 张量构建与输出 ----------------

  /// NCHW float，ImageNet mean/std。
  Float32List _detTensor(RgbaImage image) {
    final w = image.width;
    final h = image.height;
    final data = Float32List(3 * h * w);
    const means = [_detMeanR, _detMeanG, _detMeanB];
    const stds = [_detStdR, _detStdG, _detStdB];
    var idx = 0;
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final base = (y * w + x) * 4 + c;
          final v = image.rgba[base] / 255.0;
          data[idx++] = ((v - means[c]) / stds[c]).toDouble();
        }
      }
    }
    return data;
  }

  /// 识别输入：高 48、宽按比例，归一化到 [-1,1]。
  Float32List _recTensor(RgbaImage image, int w) {
    final h = _recHeight;
    final data = Float32List(3 * h * w);
    var idx = 0;
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final base = (y * w + x) * 4 + c;
          final v = image.rgba[base] / 255.0;
          data[idx++] = ((v - 0.5) / 0.5).toDouble();
        }
      }
    }
    return data;
  }

  int _recInputWidth(RgbaImage crop) {
    var w = (crop.width * _recHeight / crop.height).round();
    return w.clamp(32, 640);
  }

  /// 递归展平任意嵌套的输出张量为 double 列表。
  void _collectNums(Object? o, List<double> out) {
    if (o is num) {
      out.add(o.toDouble());
    } else if (o is List) {
      for (final e in o) {
        _collectNums(e, out);
      }
    }
  }

  Float32List _probMapFromOutput(Object? out, int w, int h) {
    final flat = <double>[];
    _collectNums(out, flat);
    final prob = Float32List(w * h);
    for (var i = 0; i < prob.length && i < flat.length; i++) {
      prob[i] = flat[i];
    }
    return prob;
  }

  /// 按类别数切分展平输出，逐时间步取 argmax。
  List<int> _argmaxPerSteps(Object? output, int classCount) {
    final flat = <double>[];
    _collectNums(output, flat);
    final steps = flat.length ~/ classCount;
    final indices = <int>[];
    for (var t = 0; t < steps; t++) {
      var best = 0;
      var bestV = double.negativeInfinity;
      for (var c = 0; c < classCount; c++) {
        final v = flat[t * classCount + c];
        if (v > bestV) {
          bestV = v;
          best = c;
        }
      }
      indices.add(best);
    }
    return indices;
  }
}
