/// 语音录入状态管理：Riverpod StateNotifier。
///
/// 协调 VoiceInputService（STT）与 BpVoiceParser（语义解析），
/// 向 UI 暴露单一不可变状态对象。
///
/// 可靠性约定：会话无论以何种方式结束（最终结果 / 错误 / 静默超时），
/// 状态都必须在有限时间内离开 listening——最终结果驱动 done，
/// 错误与无结果结束驱动 error/idle，看门狗兜底插件层不回调的情况。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/features/records/data/voice_input_service.dart';
import 'package:blood_pressed/features/records/domain/bp_voice_parser.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class VoiceInputState {
  const VoiceInputState({
    this.status = VoiceInputStatus.initializing,
    this.partialText = '',
    this.result,
    this.errorMessage,
    this.errorCode,
  });

  final VoiceInputStatus status;

  /// STT 实时中间识别文本（显示在聆听气泡中）。
  final String partialText;

  /// 最终解析结果（status == done 时非 null）。
  final VoiceParseResult? result;

  /// 错误描述（status == error 时非 null）。
  final String? errorMessage;

  /// 平台层原始错误码（status == error 时非 null，用于错误报告与排查）。
  final String? errorCode;

  bool get isListening => status == VoiceInputStatus.listening;
  bool get isAvailable =>
      status == VoiceInputStatus.idle ||
      status == VoiceInputStatus.listening ||
      status == VoiceInputStatus.done;

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    String? partialText,
    VoiceParseResult? result,
    String? errorMessage,
    String? errorCode,
  }) =>
      VoiceInputState(
        status: status ?? this.status,
        partialText: partialText ?? this.partialText,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        errorCode: errorCode ?? this.errorCode,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier(this._service) : super(const VoiceInputState()) {
    _init();
  }

  final VoiceInputService _service;

  /// 看门狗：插件层超时（listenFor/pauseFor）在部分设备上不生效，
  /// 会话可能静默挂起，由本地计时器保证状态最终离开 listening。
  static const _watchdogTimeout = Duration(seconds: 18);
  Timer? _watchdog;

  Future<void> _init() async {
    bool available;
    try {
      available = await _service.initialize();
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    state = VoiceInputState(
      status: available
          ? VoiceInputStatus.idle
          : VoiceInputStatus.notAvailable,
    );
  }

  /// 开始语音识别。
  Future<void> startListening() async {
    if (state.status == VoiceInputStatus.notAvailable) return;
    if (_service.isListening) return;

    state = const VoiceInputState(status: VoiceInputStatus.listening);
    _startWatchdog();

    await _service.startListening(
      onResult: _onResult,
      onError: _onError,
      onStatus: _onStatus,
    );
  }

  void _onResult(VoiceInputResult r) {
    if (!mounted) return;
    if (!r.isFinal) {
      // 中间结果：更新 partialText，保持 listening 状态
      state = state.copyWith(
        status: VoiceInputStatus.listening,
        partialText: r.text,
      );
      return;
    }
    // 最终结果：解析
    _cancelWatchdog();
    state = VoiceInputState(
      status: VoiceInputStatus.done,
      result: BpVoiceParser.parse(r.text),
      partialText: r.text,
    );
  }

  void _onError(String code) {
    if (!mounted) return;
    _cancelWatchdog();
    // cancelOnError 下错误伴随会话取消，无结果可等，必须显式复位。
    // 保留 partialText 供错误报告排查。
    if (state.status != VoiceInputStatus.listening) return;
    state = state.copyWith(
      status: VoiceInputStatus.error,
      errorMessage: _messageFor(code),
      errorCode: code,
    );
  }

  void _onStatus(String status) {
    if (!mounted) return;
    // done / notListening：会话已结束。若最终结果已到（done 状态）则不干预；
    // 仍卡在 listening 说明会话静默结束且无最终结果——用 partial 降级解析。
    if (status != 'done' && status != 'notListening') return;
    if (state.status != VoiceInputStatus.listening) return;
    _cancelWatchdog();
    final partial = state.partialText;
    final parsed = partial.isEmpty
        ? const VoiceParseResult()
        : BpVoiceParser.parse(partial);
    state = parsed.hasAny
        ? VoiceInputState(
            status: VoiceInputStatus.done, result: parsed, partialText: partial)
        : state.copyWith(
            status: VoiceInputStatus.error,
            errorMessage: _messageFor(VoiceInputError.noSpeech),
            errorCode: VoiceInputError.noSpeech,
          );
  }

  /// 手动停止聆听（用户点击停止按钮）。
  Future<void> stopListening() async {
    await _service.stopListening();
    if (!mounted) return;
    // 正常停止应随后送达最终结果；若仍 listening，兜底复位
    if (state.status == VoiceInputStatus.listening) {
      state = state.copyWith(status: VoiceInputStatus.idle);
    }
  }

  /// 取消聆听，重置到 idle。
  Future<void> cancel() async {
    _cancelWatchdog();
    await _service.cancelListening();
    if (!mounted) return;
    state = const VoiceInputState(status: VoiceInputStatus.idle);
  }

  /// 消费 result（UI 读取后清空，防止重复填充）。
  void consumeResult() {
    if (!mounted) return;
    state = VoiceInputState(status: VoiceInputStatus.idle);
  }

  void _startWatchdog() {
    _cancelWatchdog();
    _watchdog = Timer(_watchdogTimeout, () {
      if (!mounted || state.status != VoiceInputStatus.listening) return;
      _service.stopListening();
      final partial = state.partialText;
      final parsed = partial.isEmpty
          ? const VoiceParseResult()
          : BpVoiceParser.parse(partial);
      state = parsed.hasAny
          ? VoiceInputState(
              status: VoiceInputStatus.done,
              result: parsed,
              partialText: partial)
          : state.copyWith(
              status: VoiceInputStatus.error,
              errorMessage: _messageFor(VoiceInputError.watchdogTimeout),
              errorCode: VoiceInputError.watchdogTimeout,
            );
    });
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  String _messageFor(String code) {
    switch (code) {
      case VoiceInputError.permissionDenied:
        return '需要麦克风权限，请在系统设置中开启后重试';
      case VoiceInputError.notAvailable:
        return '当前设备不支持语音识别';
      case VoiceInputError.noMatch:
        return '没有听到声音，请点击麦克风重试';
      case VoiceInputError.noSpeech:
        return '未听到内容，请靠近设备重试';
      case VoiceInputError.watchdogTimeout:
        return '没有听到声音，请点击麦克风重试';
      default:
        return '语音识别出错，请重试';
    }
  }

  @override
  void dispose() {
    _cancelWatchdog();
    _service.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// 平台实现注入点：测试中 override 为 Fake。
final voiceInputServiceImplProvider =
    Provider<VoiceInputService>((ref) => SpeechToTextInputService());

/// 每个 RecordEditPage 实例持有独立的语音识别会话（autoDispose）。
final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(ref.watch(voiceInputServiceImplProvider)),
);
