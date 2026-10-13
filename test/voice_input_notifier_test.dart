/// 语音录入状态机测试：用 Fake service 驱动 VoiceInputNotifier，
/// 覆盖错误兜底、会话静默结束自恢复、看门狗与 partial 降级解析。
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:blood_pressed/features/records/data/voice_input_service.dart';
import 'package:blood_pressed/features/records/data/voice_model_manager.dart';
import 'package:blood_pressed/features/records/presentation/controllers/voice_input_provider.dart';

class FakeVoiceInputService implements VoiceInputService {
  FakeVoiceInputService({
    this.available = true,
    this.initThrows = false,
    this.micGranted = true,
    this.availableGate,
  });

  bool available;
  final bool initThrows;
  final bool micGranted;

  /// initialize() 的额外门控（模拟真实引擎对模型已下载的依赖）。
  final bool Function()? availableGate;

  bool listening = false;
  int stopCalls = 0;
  int requestPermissionCalls = 0;
  int openSettingsCalls = 0;

  /// requestMicPermission 的返回值（默认由 [micGranted] 推导）。
  PermissionStatus? requestResult;

  VoiceResultCallback? resultSink;
  VoiceErrorCallback? errorSink;
  VoiceStatusCallback? statusSink;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize() async {
    if (initThrows) throw StateError('init boom');
    if (availableGate != null && !availableGate!()) return false;
    return available;
  }

  @override
  Future<PermissionStatus> micStatus() async =>
      micGranted ? PermissionStatus.granted : PermissionStatus.denied;

  @override
  Future<PermissionStatus> requestMicPermission() async {
    requestPermissionCalls++;
    return requestResult ??
        (micGranted ? PermissionStatus.granted : PermissionStatus.denied);
  }

  @override
  Future<void> openMicSettings() async {
    openSettingsCalls++;
  }

  @override
  Future<void> startListening({
    required VoiceResultCallback onResult,
    VoiceErrorCallback? onError,
    VoiceStatusCallback? onStatus,
    String? localeId,
  }) async {
    resultSink = onResult;
    errorSink = onError;
    statusSink = onStatus;
    listening = true;
  }

  @override
  Future<void> stopListening() async {
    stopCalls++;
    listening = false;
  }

  @override
  Future<void> cancelListening() async {
    listening = false;
  }

  @override
  void dispose() {}
}

VoiceInputResult _final(String text) =>
    VoiceInputResult(text: text, isFinal: true);

VoiceInputResult _partial(String text) =>
    VoiceInputResult(text: text, isFinal: false);

/// 模型存储 Fake：可配置已下载/下载失败/进度发射。
class FakeVoiceModelStore implements VoiceModelStore {
  FakeVoiceModelStore({
    this.downloaded = false,
    this.downloadThrows = false,
    bool downloading = false,
    this.progressOnDownload,
  }) : isDownloading = downloading;

  bool downloaded;
  bool downloadThrows;

  /// download() 完成前先发射的进度值（模拟进度回调）。
  double? progressOnDownload;

  @override
  bool isDownloading;

  @override
  double progress = 0;

  int downloadCalls = 0;

  Completer<void>? _gate;

  /// 测试用：挂起 download() 直到 [releaseDownload]（模拟网络传输中）。
  void holdDownload() => _gate = Completer<void>();

  void releaseDownload() {
    _gate?.complete();
    _gate = null;
  }

  final _progressController = StreamController<double>.broadcast();

  @override
  Future<bool> isDownloaded() async => downloaded;

  @override
  Future<void> download() async {
    downloadCalls++;
    if (downloadThrows) throw Exception('download boom');
    final p = progressOnDownload;
    if (p != null) {
      progress = p;
      _progressController.add(p);
    }
    downloaded = true;
    final gate = _gate;
    if (gate != null) await gate.future;
  }

  /// 测试手动发射进度（驱动 downloading 态状态更新）。
  void emitProgress(double p) => _progressController.add(p);

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Future<String> modelDir() async => '/fake/model/dir';
}

/// 组装被测 notifier：默认离线引擎不可用 + 模型已下载，
/// 使「系统初始化失败」的老语义保持 notAvailable。
VoiceInputNotifier _mkNotifier(
  FakeVoiceInputService system, {
  FakeVoiceInputService? offline,
  FakeVoiceModelStore? store,
}) =>
    VoiceInputNotifier(
      system,
      offline ?? FakeVoiceInputService(available: false),
      store ?? FakeVoiceModelStore(downloaded: true),
    );

void main() {
  group('VoiceInputNotifier', () {
    test('初始化成功 → idle', () {
      fakeAsync((async) {
        final notifier = _mkNotifier(FakeVoiceInputService());
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('初始化失败/抛异常 → notAvailable（权限已授予时）', () {
      fakeAsync((async) {
        final n1 = _mkNotifier(FakeVoiceInputService(available: false));
        async.flushMicrotasks();
        expect(n1.state.status, VoiceInputStatus.notAvailable);
        n1.dispose();

        final n2 = _mkNotifier(FakeVoiceInputService(initThrows: true));
        async.flushMicrotasks();
        expect(n2.state.status, VoiceInputStatus.notAvailable);
        n2.dispose();
      });
    });

    test('初始化失败且权限未授予 → permissionBlocked（可引导授权）', () {
      fakeAsync((async) {
        final notifier = _mkNotifier(
            FakeVoiceInputService(available: false, micGranted: false));
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.permissionBlocked);
        notifier.dispose();
      });
    });

    test('requestMicAccess 授权成功 → 重新初始化恢复 idle', () {
      fakeAsync((async) {
        final svc =
            FakeVoiceInputService(available: false, micGranted: false);
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.permissionBlocked);

        // 用户在系统弹框中授权，且重新初始化成功
        svc.requestResult = PermissionStatus.granted;
        svc.available = true;
        notifier.requestMicAccess();
        async.flushMicrotasks();

        expect(svc.requestPermissionCalls, 1);
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('requestMicAccess 永久拒绝 → 跳转系统设置并维持引导态', () {
      fakeAsync((async) {
        final svc =
            FakeVoiceInputService(available: false, micGranted: false);
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        svc.requestResult = PermissionStatus.permanentlyDenied;
        notifier.requestMicAccess();
        async.flushMicrotasks();

        expect(svc.openSettingsCalls, 1);
        expect(notifier.state.status, VoiceInputStatus.permissionBlocked);
        notifier.dispose();
      });
    });

    test('requestMicAccess 申请后仍未授予 → 跳转系统设置并维持引导态', () {
      fakeAsync((async) {
        final svc =
            FakeVoiceInputService(available: false, micGranted: false);
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        // 系统因历史拒绝自动静默拒绝（不弹窗），返回 denied
        svc.requestResult = PermissionStatus.denied;
        notifier.requestMicAccess();
        async.flushMicrotasks();

        expect(svc.requestPermissionCalls, 1);
        expect(svc.openSettingsCalls, 1);
        expect(notifier.state.status, VoiceInputStatus.permissionBlocked);
        notifier.dispose();
      });
    });

    test('recheckAfterSettings 用户授权后 → 重新初始化恢复 idle', () {
      fakeAsync((async) {
        final svc =
            FakeVoiceInputService(available: false, micGranted: false);
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.permissionBlocked);

        // 用户在系统设置中授予麦克风权限，返回应用触发复查
        svc.available = true;
        notifier.recheckAfterSettings();
        async.flushMicrotasks();

        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('非 permissionBlocked 态下 recheckAfterSettings 不动作', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(
          svc,
          FakeVoiceInputService(available: false),
          FakeVoiceModelStore(downloaded: true),
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);

        notifier.recheckAfterSettings();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('系统不可用 + 权限授予 + 模型已下载 → 回退离线引擎 idle', () {
      fakeAsync((async) {
        final notifier = VoiceInputNotifier(
          FakeVoiceInputService(available: false),
          FakeVoiceInputService(available: true),
          FakeVoiceModelStore(downloaded: true),
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('系统不可用 + 权限授予 + 模型缺失 → modelMissing', () {
      fakeAsync((async) {
        final notifier = VoiceInputNotifier(
          FakeVoiceInputService(available: false),
          FakeVoiceInputService(available: false),
          FakeVoiceModelStore(downloaded: false),
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.modelMissing);
        notifier.dispose();
      });
    });

    test('modelMissing 态 startModelDownload → 完成 → 离线初始化 idle', () {
      fakeAsync((async) {
        final store = FakeVoiceModelStore(downloaded: false);
        final notifier = VoiceInputNotifier(
          FakeVoiceInputService(available: false),
          FakeVoiceInputService(
            available: true,
            availableGate: () => store.downloaded,
          ),
          store,
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.modelMissing);

        notifier.startModelDownload();
        async.flushMicrotasks();
        expect(store.downloadCalls, 1);
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('下载中进度实时映射到 downloadPercent', () {
      fakeAsync((async) {
        final store = FakeVoiceModelStore(
          downloaded: false,
          progressOnDownload: 0.5,
        )..holdDownload();
        final notifier = VoiceInputNotifier(
          FakeVoiceInputService(available: false),
          FakeVoiceInputService(
            available: true,
            availableGate: () => store.downloaded,
          ),
          store,
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.modelMissing);

        notifier.startModelDownload();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.downloading);
        expect(notifier.state.downloadPercent, 50);

        store.releaseDownload();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('下载失败 → error + model_download_failed', () {
      fakeAsync((async) {
        final notifier = VoiceInputNotifier(
          FakeVoiceInputService(available: false),
          FakeVoiceInputService(available: false),
          FakeVoiceModelStore(downloaded: false, downloadThrows: true),
        );
        async.flushMicrotasks();

        notifier.startModelDownload();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.modelDownloadFailed);
        expect(notifier.state.errorMessage, isNotNull);
        notifier.dispose();
      });
    });

    test('modelMissing/downloading 态下 startListening 不动作', () {
      fakeAsync((async) {
        final system = FakeVoiceInputService(available: false);
        final notifier = VoiceInputNotifier(
          system,
          FakeVoiceInputService(available: false),
          FakeVoiceModelStore(downloaded: false),
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.modelMissing);

        notifier.startListening();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.modelMissing);
        notifier.dispose();
      });
    });

    test('下载在途时重进页面 → downloading 并恢复进度', () {
      fakeAsync((async) {
        final store = FakeVoiceModelStore(downloaded: false);
        store.isDownloading = true;
        store.progress = 0.42;
        final notifier = VoiceInputNotifier(
          FakeVoiceInputService(available: false),
          FakeVoiceInputService(available: false),
          store,
        );
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.downloading);
        expect(notifier.state.downloadPercent, 42);
        notifier.dispose();
      });
    });

    test('非 permissionBlocked 态下 requestMicAccess 不动作', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);

        notifier.requestMicAccess();
        async.flushMicrotasks();
        expect(svc.requestPermissionCalls, 0);
        notifier.dispose();
      });
    });

    test('最终结果 → done 并解析回填，consumeResult 复位', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.listening);

        svc.resultSink!(_final('收缩压120舒张压80脉搏72'));
        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 120);
        expect(notifier.state.result?.diastolic, 80);
        expect(notifier.state.result?.pulse, 72);

        notifier.consumeResult();
        expect(notifier.state.status, VoiceInputStatus.idle);
        expect(notifier.state.result, isNull);
        notifier.dispose();
      });
    });

    test('会话静默结束（status done）但只有 partial → 降级解析', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.resultSink!(_partial('血压128低压85'));
        svc.statusSink!('done');

        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 128);
        expect(notifier.state.result?.diastolic, 85);
        notifier.dispose();
      });
    });

    test('会话静默结束且无内容 → error（no_speech）+ 消息（不再卡聆听）', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.statusSink!('done');

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.noSpeech);
        expect(notifier.state.errorMessage, isNotNull);
        notifier.dispose();
      });
    });

    test('错误回调 → error 状态 + 消息 + 错误码，consumeResult 复位', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.errorSink!(VoiceInputError.permissionDenied);

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.permissionDenied);
        expect(notifier.state.errorMessage, contains('麦克风'));

        notifier.consumeResult();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('错误回调保留已收到的 partial 文本（供错误报告排查）', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.resultSink!(_partial('血压一百三'));
        svc.errorSink!(VoiceInputError.unknown);

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.partialText, '血压一百三');
        expect(notifier.state.errorCode, VoiceInputError.unknown);
        notifier.dispose();
      });
    });

    test('非聆听状态下的错误回调被忽略', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        notifier.cancel();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);

        svc.errorSink!(VoiceInputError.unknown);
        expect(notifier.state.status, VoiceInputStatus.idle);
        expect(notifier.state.errorMessage, isNull);
        notifier.dispose();
      });
    });

    test('看门狗：无任何回调 18s 后强制离开 listening（无内容 → error）', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 19));

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.watchdogTimeout);
        expect(notifier.state.errorMessage, isNotNull);
        expect(svc.stopCalls, 1);
        notifier.dispose();
      });
    });

    test('看门狗：已有 partial 内容 → 降级解析为 done', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.resultSink!(_partial('高压135低压90'));
        async.elapse(const Duration(seconds: 19));

        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 135);
        expect(notifier.state.result?.diastolic, 90);
        notifier.dispose();
      });
    });

    test('手动停止后收到最终结果仍正常解析', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        notifier.stopListening();
        async.flushMicrotasks();
        // stopListening 兜底复位（尚无结果）
        expect(notifier.state.status, VoiceInputStatus.idle);

        // 引擎随后送达最终结果
        svc.resultSink!(_final('收缩压118舒张压76脉搏70'));
        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 118);
        notifier.dispose();
      });
    });

    test('取消 → 复位 idle，看门狗撤销', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = _mkNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        notifier.cancel();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);

        async.elapse(const Duration(seconds: 19));
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });
  });

  group('SpeechToTextInputService', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    Future<void> mockSttChannel(Future<Object?>? Function(String) handler) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugin.csdcorp.com/speech_to_text'),
        (call) async => handler(call.method),
      );
    }

    test('initialize 平台异常 → 不可用，listen 前 not_available', () async {
      final svc = SpeechToTextInputService(
        requestMicPermission: () async => PermissionStatus.granted,
      );
      final ok = await svc.initialize();
      expect(ok, isFalse);

      String? code;
      await svc.startListening(onResult: (_) {}, onError: (c) => code = c);
      expect(code, VoiceInputError.notAvailable);
    });

    test('无麦克风权限 → permission_denied 且不进入聆听', () async {
      await mockSttChannel((method) async {
        if (method == 'has_permission') return true;
        if (method == 'initialize') return true;
        if (method == 'listen') return true;
        return null;
      });
      final svc = SpeechToTextInputService(
        requestMicPermission: () async => PermissionStatus.denied,
      );
      expect(await svc.initialize(), isTrue);

      String? code;
      VoiceInputResult? anyResult;
      await svc.startListening(
        onResult: (r) => anyResult = r,
        onError: (c) => code = c,
      );
      expect(code, VoiceInputError.permissionDenied);
      expect(anyResult, isNull);
      expect(svc.isListening, isFalse);
    });

    test('权限授予 → 发起 listen（插件 listen 已被调用且无错误）', () async {
      var listenCalled = false;
      await mockSttChannel((method) async {
        if (method == 'has_permission') return true;
        if (method == 'initialize') return true;
        if (method == 'listen') {
          listenCalled = true;
          return true;
        }
        return null;
      });
      final svc = SpeechToTextInputService(
        requestMicPermission: () async => PermissionStatus.granted,
      );
      expect(await svc.initialize(), isTrue);

      String? error;
      await svc.startListening(onResult: (_) {}, onError: (c) => error = c);
      expect(error, isNull);
      expect(listenCalled, isTrue);
    });
  });
}
