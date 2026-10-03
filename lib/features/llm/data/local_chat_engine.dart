import 'dart:io';

import 'package:llamadart/llamadart.dart';

import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';

/// 本地引擎：llama.cpp GGUF 推理（llamadart）。
///
/// 一次只加载一个模型；切换档案时先卸载。
class LocalChatEngine implements InferenceEngine {
  LocalChatEngine();

  LlamaEngine? _engine;
  String? _loadedPath;
  int _loadedContext = 0;

  @override
  bool get isReady => _engine?.isReady ?? false;

  @override
  String? get profileId => _loadedPath;

  /// 加载（或重新加载）GGUF 模型。
  Future<void> load(LlmProfile profile) async {
    if (profile.kind != LlmKind.local || profile.modelPath.isEmpty) {
      throw const InferenceException('本地模型配置无效');
    }
    final file = File(profile.modelPath);
    if (!file.existsSync()) {
      throw InferenceException('模型文件不存在：${profile.modelPath}');
    }
    if (isReady && _loadedPath == profile.modelPath) return;

    await unload();

    final engine = LlamaEngine(LlamaBackend());
    _engine = engine;
    try {
      await engine.loadModel(
        profile.modelPath,
        modelParams: ModelParams(
          contextSize: profile.contextSize,
          numberOfThreads: profile.threads > 0 ? profile.threads : 0,
        ),
      );
      _loadedPath = profile.modelPath;
      _loadedContext = profile.contextSize;
    } catch (e) {
      await engine.dispose();
      _engine = null;
      _loadedPath = null;
      throw InferenceException('模型加载失败，可能是内存不足或文件损坏', e);
    }
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async* {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw const InferenceException('本地模型尚未加载');
    }
    final llamaMessages = messages
        .map((m) => LlamaChatMessage.fromText(
              role: LlamaChatRole.values
                  .firstWhere((r) => r.name == m.role.name),
              text: m.content,
            ))
        .toList();
    try {
      await for (final chunk in engine.create(
        llamaMessages,
        params: GenerationParams(
          temp: temperature,
          maxTokens: maxTokens,
        ),
        enableThinking: false,
      )) {
        final choices = chunk.choices;
        if (choices.isEmpty) continue;
        final content = choices.first.delta.content;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      }
    } catch (e) {
      throw InferenceException('本地推理出错', e);
    }
  }

  Future<void> unload() async {
    final engine = _engine;
    if (engine != null) {
      if (engine.isReady) {
        try {
          await engine.unloadModel();
        } catch (_) {}
      }
      await engine.dispose();
    }
    _engine = null;
    _loadedPath = null;
    _loadedContext = 0;
  }

  int get loadedContext => _loadedContext;

  @override
  Future<void> dispose() => unload();
}
