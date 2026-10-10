/// 语音录入状态管理：Riverpod StateNotifier。
///
/// 协调 VoiceInputService（STT）与 BpVoiceParser（语义解析），
/// 向 UI 暴露单一不可变状态对象。
library;

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
  });

  final VoiceInputStatus status;

  /// STT 实时中间识别文本（显示在聆听气泡中）。
  final String partialText;

  /// 最终解析结果（status == done 时非 null）。
  final VoiceParseResult? result;

  /// 错误描述（status == error 时非 null）。
  final String? errorMessage;

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
  }) =>
      VoiceInputState(
        status: status ?? this.status,
        partialText: partialText ?? this.partialText,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier(this._service) : super(const VoiceInputState()) {
    _init();
  }

  final VoiceInputService _service;

  Future<void> _init() async {
    final available = await _service.initialize();
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

    await _service.startListening(
      onResult: _onResult,
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
    final parsed = BpVoiceParser.parse(r.text);
    state = VoiceInputState(
      status: VoiceInputStatus.done,
      result: parsed,
      partialText: r.text,
    );
  }

  /// 手动停止聆听（用户点击停止按钮）。
  Future<void> stopListening() async {
    await _service.stopListening();
    if (!mounted) return;
    // 若无最终结果回调，则切回 idle
    if (state.status == VoiceInputStatus.listening) {
      state = state.copyWith(status: VoiceInputStatus.idle);
    }
  }

  /// 取消聆听，重置到 idle。
  Future<void> cancel() async {
    await _service.cancelListening();
    if (!mounted) return;
    state = const VoiceInputState(status: VoiceInputStatus.idle);
  }

  /// 消费 result（UI 读取后清空，防止重复填充）。
  void consumeResult() {
    if (!mounted) return;
    state = VoiceInputState(
      status: VoiceInputStatus.idle,
      result: null,
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// 每个 RecordEditPage 实例持有独立的语音识别会话（autoDispose）。
final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(VoiceInputService()),
);
