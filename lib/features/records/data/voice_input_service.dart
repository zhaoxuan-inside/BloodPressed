/// 语音输入服务：封装 speech_to_text 包，提供统一的语音识别接口。
///
/// 依赖倒置：上层（Provider / UI）通过抽象接口隔离 speech_to_text 平台细节，
/// 测试用 Fake 实现注入（见 voice_input_notifier_test）。
library;

import 'package:permission_handler/permission_handler.dart';
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

/// 平台错误码（透传给上层用于提示与恢复）。
typedef VoiceErrorCallback = void Function(String code);

/// 平台会话状态回调：'listening' / 'done' / 'notListening' 等。
typedef VoiceStatusCallback = void Function(String status);

class VoiceInputResult {
  const VoiceInputResult({required this.text, required this.isFinal});

  /// STT 识别的原始文本（可能为空字符串）。
  final String text;

  /// 是否为最终识别结果（`true` 时可触发解析）。
  final bool isFinal;
}

/// 回调类型：每次 STT 返回识别词时触发。
typedef VoiceResultCallback = void Function(VoiceInputResult result);

/// 语音识别错误码（与平台无关的稳定契约）。
abstract final class VoiceInputError {
  /// 未获得麦克风运行时权限。
  static const permissionDenied = 'permission_denied';

  /// 设备不支持或识别服务不可用。
  static const notAvailable = 'not_available';

  /// 识别失败 / 未能匹配到语音（含超时无语音）。
  static const noMatch = 'no_match';

  /// 其他未知错误。
  static const unknown = 'unknown';
}

/// 语音输入服务接口（测试 seam）。
abstract interface class VoiceInputService {
  /// 是否支持语音识别（初始化后可查询）。
  bool get isAvailable;

  /// 是否正在聆听。
  bool get isListening;

  /// 初始化：申请权限、检测设备能力。
  ///
  /// 返回 `true` 表示设备支持且权限已授予。
  Future<bool> initialize();

  /// 开始聆听。
  ///
  /// [onResult] 每次收到中间或最终识别结果时回调；
  /// [onError] 识别失败 / 权限被拒时回调（错误码见 [VoiceInputError]）；
  /// [onStatus] 会话状态变化时回调（会话结束必达，上层据此兜底恢复）。
  Future<void> startListening({
    required VoiceResultCallback onResult,
    VoiceErrorCallback? onError,
    VoiceStatusCallback? onStatus,
    String? localeId,
  });

  /// 停止聆听（正常完成，预期随后有最终结果）。
  Future<void> stopListening();

  /// 取消聆听（丢弃结果）。
  Future<void> cancelListening();

  /// 释放资源。
  void dispose();
}

/// 基于 speech_to_text 的平台实现。
class SpeechToTextInputService implements VoiceInputService {
  /// [requestMicPermission] 供测试注入，默认走 permission_handler。
  SpeechToTextInputService({
    Future<PermissionStatus> Function()? requestMicPermission,
  }) : _requestMicPermission =
            requestMicPermission ?? Permission.microphone.request;

  final Future<PermissionStatus> Function() _requestMicPermission;

  final stt.SpeechToText _speech = stt.SpeechToText();

  // speech_to_text 的 onStatus 挂在 initialize 上，而会话是 startListening
  // 发起的：用 sink 中转，把会话状态转给当次调用的上层回调。
  VoiceStatusCallback? _statusSink;

  bool _initialized = false;
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    if (_initialized) return _available;
    try {
      _available = await _speech.initialize(
        onStatus: (s) => _statusSink?.call(s),
        finalTimeout: const Duration(seconds: 15),
      );
    } catch (_) {
      _available = false;
    }
    _initialized = true;
    return _available;
  }

  @override
  Future<void> startListening({
    required VoiceResultCallback onResult,
    VoiceErrorCallback? onError,
    VoiceStatusCallback? onStatus,
    String? localeId,
  }) async {
    if (!_available) {
      onError?.call(VoiceInputError.notAvailable);
      return;
    }

    // 麦克风运行时权限：未授予时部分 ROM 的识别服务会静默失败，
    // 必须在 listen 之前确保已授权。
    final perm = await _requestMicPermission();
    if (!perm.isGranted) {
      onError?.call(VoiceInputError.permissionDenied);
      return;
    }

    if (_speech.isListening) await _speech.stop();

    _statusSink = onStatus;
    try {
      await _speech.listen(
        onResult: (r) => onResult(
          VoiceInputResult(text: r.recognizedWords, isFinal: r.finalResult),
        ),
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      onError?.call(VoiceInputError.unknown);
      return;
    }
    // listen 立即返回后插件才异步进入 listening；状态经 _statusSink 转发。
  }

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  @override
  Future<void> cancelListening() async {
    if (_speech.isListening) await _speech.cancel();
  }

  @override
  void dispose() {
    _speech.cancel();
  }
}
