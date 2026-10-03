import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';

/// ML Kit OCR 封装（中文识别脚本，兼顾数字与中文标签）。
class OcrService {
  OcrService({OcrBpParser? parser}) : _parser = parser ?? const OcrBpParser();

  final OcrBpParser _parser;
  TextRecognizer? _recognizer;

  /// 识别图片并解析血压候选。
  ///
  /// 返回 null 表示 OCR 环节不可用（典型：设备无 Google Play Services）；
  /// 返回结果 candidates 可能为空（识别不出数值）。
  Future<OcrParseResult?> recognize(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer =
        _recognizer ??= TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final result = await recognizer.processImage(inputImage);
      final buffer = StringBuffer();
      for (final block in result.blocks) {
        buffer.writeln(block.text);
      }
      return _parser.parse(buffer.toString());
    } catch (e) {
      if (isMlKitUnavailable(e)) {
        return null;
      }
      rethrow;
    }
  }

  /// 判断是否为 ML Kit 运行环境缺失（无 GMS 设备）。
  static bool isMlKitUnavailable(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('play services') ||
        s.contains('play store') ||
        s.contains('gms') ||
        s.contains('api not found') ||
        s.contains('no usable recognizer') ||
        s.contains('provider') && s.contains('unavailable');
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
