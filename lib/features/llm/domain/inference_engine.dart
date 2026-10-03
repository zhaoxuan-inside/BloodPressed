import 'package:blood_pressed/features/llm/domain/llm_models.dart';

/// 推理引擎抽象：远端 API 与本地 GGUF 共用同一接口。
abstract class InferenceEngine {
  /// 引擎是否已就绪（模型已加载 / 配置有效）。
  bool get isReady;

  /// 当前引擎对应的配置档案 id（用于判断是否需要重载）。
  String? get profileId;

  /// 流式对话。返回逐段文本流。
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 1024,
  });

  /// 释放资源（卸载本地模型 / 关闭客户端）。
  Future<void> dispose();
}

/// 引擎异常（对上层统一错误类型）。
class InferenceException implements Exception {
  const InferenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause == null ? 'InferenceException: $message' : '$message ($cause)';
}
