/// 语音输入服务：封装 speech_to_text 包，提供统一的语音识别接口。
///
/// 依赖倒置：上层（Provider / UI）通过此 Service 隔离 speech_to_text 平台细节。
library;

import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音识别会话状态。
enum VoiceInputStatus {
  /// 初始化中
  initializing,

  /// 就绪（可发起识别）
  idle,

  /// 正在聆听
  listening,

  /// 识别完成，携带文本结果
  done,

  /// 错误（权限被拒 / 不支持 / 超时）
  error,

  /// 设备不支持语音识别
  notAvailable,
}

class VoiceInputResult {
  const VoiceInputResult({required this.text, required this.isFinal});

  /// STT 识别的原始文本（可能为空字符串）。
  final String text;

  /// 是否为最终识别结果（`true` 时可触发解析）。
  final bool isFinal;
}

/// 回调类型：每次 STT 返回识别词时触发。
typedef VoiceResultCallback = void Function(VoiceInputResult result);

/// 语音输入服务（单例：通过 Riverpod Provider 管理生命周期）。
class VoiceInputService {
  VoiceInputService();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _available = false;

  /// 是否支持语音识别（初始化后可查询）。
  bool get isAvailable => _available;

  /// 是否正在聆听。
  bool get isListening => _speech.isListening;

  /// 初始化：申请权限、检测设备能力。
  ///
  /// 返回 `true` 表示设备支持且权限已授予。
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _available = await _speech.initialize(
      onError: (_) {}, // 错误由 listen 回调携带
      finalTimeout: const Duration(seconds: 15),
    );
    _initialized = true;
    return _available;
  }

  /// 开始聆听。
  ///
  /// [onResult] 每次收到中间或最终识别结果时回调。
  /// [localeId] 识别语言，默认为设备系统语言；传入 'zh_CN' 强制中文。
  Future<void> startListening({
    required VoiceResultCallback onResult,
    String? localeId,
  }) async {
    if (!_available) return;
    if (_speech.isListening) await _speech.stop();

    await _speech.listen(
      localeId: localeId,
      onResult: (r) => onResult(
        VoiceInputResult(
          text: r.recognizedWords,
          isFinal: r.finalResult,
        ),
      ),
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
    );
  }

  /// 停止聆听（正常完成）。
  Future<void> stopListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  /// 取消聆听（丢弃结果）。
  Future<void> cancelListening() async {
    if (_speech.isListening) await _speech.cancel();
  }

  /// 释放资源。
  void dispose() {
    _speech.cancel();
  }
}
