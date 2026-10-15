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
import 'package:permission_handler/permission_handler.dart';

import 'package:blood_pressed/features/records/data/offline_voice_service.dart';
import 'package:blood_pressed/features/records/data/voice_input_service.dart';
import 'package:blood_pressed/features/records/data/voice_model_manager.dart';
import 'package:blood_pressed/features/records/data/bundled_voice_model_store.dart';
import 'package:blood_pressed/features/records/domain/bp_voice_parser.dart';

/// 强制走离线引擎（调试/模拟器验证用，release 默认 false）。
/// 构建时注入：--dart-define=VOICE_FORCE_OFFLINE=true
const bool kVoiceForceOffline = bool.fromEnvironment('VOICE_FORCE_OFFLINE');

// ── State ─────────────────────────────────────────────────────────────────────

class VoiceInputState {
  const VoiceInputState({
    this.status = VoiceInputStatus.initializing,
    this.partialText = '',
    this.result,
    this.errorMessage,
    this.errorCode,
    this.downloadPercent = 0,
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

  /// 离线模型下载进度（0~100，仅 downloading 态有意义）。
  final int downloadPercent;

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
    int? downloadPercent,
  }) => VoiceInputState(
    status: status ?? this.status,
    partialText: partialText ?? this.partialText,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
    errorCode: errorCode ?? this.errorCode,
    downloadPercent: downloadPercent ?? this.downloadPercent,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  /// [_systemService] 为平台系统识别（speech_to_text），
  /// [_offlineService] 为本地模型引擎兜底（sherpa-onnx）。
  VoiceInputNotifier(
    this._systemService,
    this._offlineService,
    this._modelStore,
  ) : _service = _systemService,
      super(const VoiceInputState()) {
    _init();
  }

  VoiceInputService _service;
  final VoiceInputService _systemService;
  final VoiceInputService _offlineService;
  final VoiceModelStore _modelStore;

  /// 看门狗：插件层超时（listenFor/pauseFor）在部分设备上不生效，
  /// 会话可能静默挂起，由本地计时器保证状态最终离开 listening。
  static const _watchdogTimeout = Duration(seconds: 18);
  Timer? _watchdog;

  StreamSubscription<double>? _downloadSub;

  /// 初始化：系统识别优先，不可用（权限已授予仍失败）时回退离线引擎；
  /// 离线模型未下载则进入 modelMissing 引导态。
  ///
  /// [allowSystem] 为 false 时跳过系统识别（下载完成/复查等重入场景，
  /// 避免对已知不可用的系统识别重复初始化）。
  Future<void> _init({bool allowSystem = true}) async {
    var status = VoiceInputStatus.notAvailable;
    var available = false;
    var micGranted = true;
    var downloadPercent = 0;
    if (allowSystem && !kVoiceForceOffline) {
      _switchTo(_systemService);
      try {
        available = await _systemService.initialize();
      } catch (_) {
        available = false;
      }
    }
    if (!available) {
      // 初始化失败时区分原因：权限未授予 → 可引导授权后恢复；
      // 权限已授予仍失败 → 回退离线引擎。查询失败按不支持兜底。
      try {
        final mic = await _service.micStatus();
        micGranted = mic.isGranted;
      } catch (_) {
        micGranted = true;
      }
      if (micGranted) {
        _switchTo(_offlineService);
        try {
          available = await _offlineService.initialize();
        } on VoiceInitializationException catch (error) {
          if (!mounted) return;
          state = VoiceInputState(
            status: VoiceInputStatus.error,
            errorCode: VoiceInputError.initializationFailed,
            errorMessage: '离线语音初始化失败，请点击麦克风重试。\n${error.details}',
          );
          return;
        } catch (_) {
          available = false;
        }
        if (available) {
          status = VoiceInputStatus.idle;
        } else if (await _safeModelDownloaded()) {
          // 模型已下载仍初始化失败：引擎异常，按不支持兜底
          status = VoiceInputStatus.notAvailable;
        } else if (_modelStore.isDownloading) {
          // 下载在途（页面重进）：恢复进度显示
          status = VoiceInputStatus.downloading;
          downloadPercent = (_modelStore.progress * 100).round();
          _listenDownloadProgress();
        } else {
          status = VoiceInputStatus.modelMissing;
        }
      } else {
        status = VoiceInputStatus.permissionBlocked;
      }
    } else {
      status = VoiceInputStatus.idle;
    }
    if (!mounted) return;
    state = VoiceInputState(status: status, downloadPercent: downloadPercent);
  }

  Future<bool> _safeModelDownloaded() async {
    try {
      return await _modelStore.isDownloaded();
    } catch (_) {
      return false;
    }
  }

  void _switchTo(VoiceInputService service) {
    if (identical(_service, service)) return;
    _service = service;
  }

  /// 下载离线语音模型：modelMissing 态点击触发。
  ///
  /// 进度实时映射到状态（下载在 app 级 store 中进行，页面关闭后继续；
  /// 重新进入页面时恢复进度显示），完成后切换离线引擎并初始化。
  Future<void> startModelDownload() async {
    if (state.status != VoiceInputStatus.modelMissing &&
        state.status != VoiceInputStatus.downloading) {
      return;
    }
    state = VoiceInputState(
      status: VoiceInputStatus.downloading,
      downloadPercent: (_modelStore.progress * 100).round(),
    );
    _listenDownloadProgress();
    try {
      await _modelStore.download();
    } catch (_) {
      if (!mounted) return;
      _unlistenDownloadProgress();
      state = state.copyWith(
        status: VoiceInputStatus.error,
        errorMessage: '离线语音模型下载失败，请检查网络后重试',
        errorCode: VoiceInputError.modelDownloadFailed,
      );
      return;
    }
    if (!mounted) return;
    _unlistenDownloadProgress();
    state = const VoiceInputState(status: VoiceInputStatus.initializing);
    await _init(allowSystem: false);
  }

  void _listenDownloadProgress() {
    _downloadSub ??= _modelStore.progressStream.listen((p) {
      if (!mounted) return;
      if (state.status != VoiceInputStatus.downloading) return;
      state = state.copyWith(downloadPercent: (p * 100).round());
    });
  }

  void _unlistenDownloadProgress() {
    _downloadSub?.cancel();
    _downloadSub = null;
  }

  /// 引导授权：permissionBlocked 态下点击按钮触发。
  ///
  /// 授权成功 → 重新初始化；仍未授予 → 跳系统设置。
  /// 注意不能只处理 permanentlyDenied：系统可能因历史拒绝自动静默拒绝
  /// （不弹窗且 permission_handler 无法识别为永久拒绝），此时设置页是
  /// 唯一的授权途径。
  Future<void> requestMicAccess() async {
    if (state.status != VoiceInputStatus.permissionBlocked) return;
    final perm = await _service.requestMicPermission();
    if (!mounted) return;
    if (perm.isGranted) {
      state = const VoiceInputState(status: VoiceInputStatus.initializing);
      await _init();
      return;
    }
    await _service.openMicSettings();
  }

  /// 从系统设置返回后复查：用户在设置中授权后自动恢复可用。
  Future<void> recheckAfterSettings() async {
    if (state.status != VoiceInputStatus.permissionBlocked) return;
    state = const VoiceInputState(status: VoiceInputStatus.initializing);
    await _init();
  }

  /// 开始语音识别。
  Future<void> startListening() async {
    if (!_service.isAvailable ||
        state.errorCode == VoiceInputError.initializationFailed ||
        state.status == VoiceInputStatus.initializing) {
      if (state.status == VoiceInputStatus.initializing) return;
      state = const VoiceInputState(status: VoiceInputStatus.initializing);
      await _init();
      if (!mounted || state.status != VoiceInputStatus.idle) return;
    }
    if (state.status == VoiceInputStatus.notAvailable ||
        state.status == VoiceInputStatus.permissionBlocked ||
        state.status == VoiceInputStatus.modelMissing ||
        state.status == VoiceInputStatus.downloading) {
      return;
    }
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
            status: VoiceInputStatus.done,
            result: parsed,
            partialText: partial,
          )
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
    if (state.errorCode == VoiceInputError.initializationFailed) return;
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
              partialText: partial,
            )
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
    _unlistenDownloadProgress();
    _systemService.dispose();
    if (!identical(_systemService, _offlineService)) _offlineService.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// 平台实现注入点：测试中 override 为 Fake。
final voiceInputServiceImplProvider = Provider.autoDispose<VoiceInputService>(
  (ref) => SpeechToTextInputService(),
);

/// 离线引擎实现注入点：测试中 override 为 Fake。
final offlineVoiceServiceProvider = Provider.autoDispose<VoiceInputService>(
  (ref) => SherpaOfflineInputService(ref.watch(voiceModelStoreProvider)),
);

/// 模型存储（app 级存活：下载不随录入页关闭中断）。
final voiceModelStoreProvider = Provider<VoiceModelStore>(
  (ref) => BundledVoiceModelStore(),
);

/// 每个 RecordEditPage 实例持有独立的语音识别会话（autoDispose）。
final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
      (ref) => VoiceInputNotifier(
        ref.watch(voiceInputServiceImplProvider),
        ref.watch(offlineVoiceServiceProvider),
        ref.watch(voiceModelStoreProvider),
      ),
    );
