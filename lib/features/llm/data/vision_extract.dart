import 'dart:typed_data';

import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';
import 'package:blood_pressed/features/llm/data/remote_chat_engine.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

/// 多模态大模型血压识别兜底：把血压计照片交给支持视觉的远端模型提取数值。
///
/// 返回 null 表示模型未能给出可信数值。
Future<BpCandidate?> extractBpFromImage({
  required Uint8List jpegBytes,
  required LlmProfile profile,
}) async {
  const prompt = '''
你是一个医疗设备读数识别助手。请从这张血压计照片/截图中提取数值。
要求：
1. 只输出一个 JSON 对象，不要输出任何其他文字。
2. JSON 格式：{"systolic": 收缩压整数, "diastolic": 舒张压整数, "pulse": 脉搏整数或null}
3. 数值必须来自图片中实际显示的读数；无法确定的字段填 null。
4. 收缩压即"高压/SYS"，舒张压即"低压/DIA"。
''';
  final engine = RemoteChatEngine(profile);
  try {
    final output = await engine.recognizeImage(
      jpegBytes: jpegBytes,
      prompt: prompt,
    );
    return parseLlmExtraction(output);
  } finally {
    await engine.dispose();
  }
}
