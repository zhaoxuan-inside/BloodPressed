/// 离线语音识别服务：sherpa-onnx 流式 zipformer（中英双语，int8）。
///
/// 兜底无系统识别服务（无 GMS ROM）的设备：本地加载模型 + 本地推理，
/// 全程离线。音频链路：record 包 16kHz PCM16 单声道麦克风流 →
/// Float32 → OnlineStream → 流式解码。
///
/// 回调契约与 SpeechToTextInputService 对齐（见 VoiceInputService）：
/// * 中间文本：`onResult(isFinal: false)`，识别文本变化时更新；
/// * 最终文本：仅 `stopListening()` 触发——端点检测切分段落后累积文本，
///   不单独派发 final，保证上层每会话至多一个最终结果。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:blood_pressed/features/records/data/voice_input_service.dart';
import 'package:blood_pressed/features/records/data/voice_model_manager.dart';
import 'package:blood_pressed/features/records/data/offline_voice_config.dart';

/// 离线识别采样率（模型训练采样率，固定 16kHz）。
const int kOfflineSampleRate = 16000;

/// PCM16LE 字节流 → [-1, 1] Float32（sherpa 输入格式）。
Float32List pcm16ToFloat32(Uint8List bytes) {
  final n = bytes.length ~/ 2;
  final out = Float32List(n);
  final bd = ByteData.sublistView(bytes);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

class SherpaOfflineInputService implements VoiceInputService {
  /// [requestMicPermission]/[micStatus]/[openSettings] 可注入，供测试替换。
  SherpaOfflineInputService(
    this._modelStore, {
    Future<PermissionStatus> Function()? requestMicPermission,
    Future<PermissionStatus> Function()? micStatus,
    Future<void> Function()? openSettings,
  }) : _requestMicPermission =
           requestMicPermission ?? Permission.microphone.request,
       _micStatus = micStatus ?? _defaultMicStatus,
       _openSettings = openSettings ?? _defaultOpenSettings;

  final VoiceModelStore _modelStore;
  final Future<PermissionStatus> Function() _requestMicPermission;
  final Future<PermissionStatus> Function() _micStatus;
  final Future<void> Function() _openSettings;

  /// 扩展 getter 不支持 tear-off，用静态方法包装。
  static Future<PermissionStatus> _defaultMicStatus() =>
      Permission.microphone.status;

  static Future<void> _defaultOpenSettings() async {
    await openAppSettings();
  }

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSub;

  VoiceResultCallback? _onResult;
  VoiceErrorCallback? _onError;
  VoiceStatusCallback? _onStatus;

  String _lastEmitted = '';

  bool _available = false;
  bool _disposed = false;

  /// 已完成分段的累积文本（端点检测切分段落后逐段累加）。
  final List<String> _segments = [];

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _micSub != null;

  /// 原生绑定只初始化一次（幂等保护）。
  static bool _bindingsReady = false;

  @override
  Future<bool> initialize() async {
    if (_disposed) return false;
    if (_available) return true;
    try {
      // The production store copies bundled assets, without HTTP or consent UI.
      if (!await _modelStore.isDownloaded()) await _modelStore.download();
      if (!await _modelStore.isDownloaded()) {
        throw StateError('Bundled voice model could not be prepared');
      }
      if (!_bindingsReady) {
        // recognizer 工厂要求绑定已初始化（否则抛
        // "Please initialize sherpa-onnx first"）
        sherpa.initBindings();
        _bindingsReady = true;
      }
      final dir = await _modelStore.modelDir();
      if (_disposed) return false;
      final recognizer = sherpa.OnlineRecognizer(offlineVoiceConfig(dir));
      _recognizer?.free();
      _recognizer = recognizer;
      _available = true;
    } catch (error) {
      _available = false;
      throw VoiceInitializationException(error.toString());
    }
    return _available;
  }

  @override
  Future<PermissionStatus> micStatus() => _micStatus();

  @override
  Future<PermissionStatus> requestMicPermission() => _requestMicPermission();

  @override
  Future<void> openMicSettings() => _openSettings();

  @override
  Future<void> startListening({
    required VoiceResultCallback onResult,
    VoiceErrorCallback? onError,
    VoiceStatusCallback? onStatus,
    String? localeId,
  }) async {
    if (!_available || _recognizer == null) {
      onError?.call(VoiceInputError.notAvailable);
      return;
    }
    if (isListening) return;

    final perm = await _requestMicPermission();
    if (!perm.isGranted) {
      onError?.call(VoiceInputError.permissionDenied);
      return;
    }

    _onResult = onResult;
    _onError = onError;
    _onStatus = onStatus;
    _segments.clear();
    _lastEmitted = '';
    _stream = _recognizer!.createStream();

    final recorder = AudioRecorder();
    _recorder = recorder;
    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: kOfflineSampleRate,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceRecognition,
          ),
        ),
      );
      _micSub = stream.listen(
        _onAudioChunk,
        onError: (Object e) => _fail(VoiceInputError.unknown),
        cancelOnError: true,
      );
    } catch (_) {
      await _teardownRecorder();
      _stream?.free();
      _stream = null;
      onError?.call(VoiceInputError.unknown);
    }
  }

  /// 处理一帧麦克风 PCM 数据：喂入识别器并推进解码。
  void _onAudioChunk(Uint8List chunk) {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return;
    if (chunk.isEmpty) return;
    try {
      stream.acceptWaveform(
        samples: pcm16ToFloat32(chunk),
        sampleRate: kOfflineSampleRate,
      );
      _decodeCurrent(stream);
      if (recognizer.isEndpoint(stream)) {
        // 分段落定：累积文本后重置解码器，继续聆听下一段
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty) _segments.add(text);
        recognizer.reset(stream);
        _lastEmitted = '';
        _emitPartial();
      }
    } catch (_) {
      _fail(VoiceInputError.unknown);
    }
  }

  void _decodeCurrent(sherpa.OnlineStream stream) {
    final recognizer = _recognizer!;
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    _emitPartial();
  }

  String _joinedText() => _segments.join(' ');

  /// 派发中间结果（文本变化才触发，避免回调风暴）。
  void _emitPartial() {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return;
    final live = recognizer.getResult(stream).text.trim();
    final text = (_joinedText() + (live.isEmpty ? '' : ' $live')).trim();
    if (text == _lastEmitted) return;
    _lastEmitted = text;
    _onResult?.call(VoiceInputResult(text: text, isFinal: false));
  }

  @override
  Future<void> stopListening() async {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer != null && stream != null && _micSub != null) {
      // 冲刷残余解码并累积最后一个分段
      try {
        stream.acceptWaveform(
          samples: Float32List(kOfflineSampleRate),
          sampleRate: kOfflineSampleRate,
        );
        stream.inputFinished();
        _decodeCurrent(stream);
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty) _segments.add(text);
      } catch (_) {}
    }
    await _teardownRecorder();
    _stream?.free();
    _stream = null;
    final text = _joinedText();
    _segments.clear();
    if (text.isNotEmpty) {
      _onResult?.call(VoiceInputResult(text: text, isFinal: true));
    } else {
      // 会话结束但无内容：与系统 STT 的 no_match 同层处理
      _onError?.call(VoiceInputError.noMatch);
    }
    _onStatus?.call('done');
  }

  @override
  Future<void> cancelListening() async {
    await _teardownRecorder();
    _stream?.free();
    _stream = null;
    _segments.clear();
    _onStatus?.call('done');
  }

  Future<void> _teardownRecorder() async {
    final recorder = _recorder;
    _recorder = null;
    final sub = _micSub;
    _micSub = null;
    await sub?.cancel();
    if (recorder != null) {
      try {
        if (await recorder.isRecording()) await recorder.stop();
        await recorder.dispose();
      } catch (_) {}
    }
  }

  void _fail(String code) {
    _teardownRecorder();
    _stream?.free();
    _stream = null;
    _segments.clear();
    _onError?.call(code);
    _onStatus?.call('done');
  }

  @override
  void dispose() {
    _disposed = true;
    _teardownRecorder();
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
    _available = false;
  }
}
